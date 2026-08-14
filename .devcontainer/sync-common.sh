#!/usr/bin/env bash
# Refresh the vendored shared devcontainer layer from pocket-nebula.
#
# This is the ONLY file copy-pasted between repos; it changes almost never.
# Everything else it manages lives in .devcontainer/common/, which is committed
# (vendored) so a fresh clone with no network still builds.
#
# It runs as `initializeCommand`, which the dev containers spec defines as
# running ON THE HOST during initialization - crucially, BEFORE the image is
# built. That ordering is the whole point: a shared-layer change is fetched and
# in place before the build and postCreateCommand of the SAME create cycle, so
# you never rebuild, notice drift, and have to rebuild again.
#
# It cannot refresh devcontainer.json itself, which the tool has already parsed
# by the time this runs. Shared devcontainer.json content is handled instead by
# the base image's devcontainer.metadata label; whatever is left is checked by
# common/check-devcontainer-drift.sh, which only warns.
#
# Runs on macOS with the system bash 3.2, so no mapfile / associative arrays.
set -euo pipefail

UPSTREAM_REPO="${POCKET_NEBULA_REPO:-https://github.com/aioue/pocket-nebula.git}"
UPSTREAM_SUBDIR=".devcontainer-shared/common"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="${SCRIPT_DIR}/common"
REF_FILE="${SCRIPT_DIR}/common.ref"
STAMP_FILE="${COMMON_DIR}/.synced-ref"

log()  { echo "🔄 [sync-common] $*"; }
warn() { echo "⚠️  [sync-common] $*" >&2; }

# ---------------------------------------------------------------------------
# devcontainer.env bootstrap
# ---------------------------------------------------------------------------
# runArgs uses --env-file=.devcontainer/devcontainer.env, and docker fails hard
# if that file is absent. Generating it here - on the host, before the build -
# is the only lifecycle point early enough to fix that. Without this, a fresh
# clone of a repo whose .gitignore excludes the env file cannot start at all.
if [[ -f "${SCRIPT_DIR}/devcontainer.env.example" && ! -f "${SCRIPT_DIR}/devcontainer.env" ]]; then
    cp "${SCRIPT_DIR}/devcontainer.env.example" "${SCRIPT_DIR}/devcontainer.env"
    log "created devcontainer.env from devcontainer.env.example"
fi

# ---------------------------------------------------------------------------
# Resolve pinned ref
# ---------------------------------------------------------------------------
if [[ ! -f "$REF_FILE" ]]; then
    warn "no ${REF_FILE}; using the vendored copy as-is."
    exit 0
fi

# Strip comments and blank lines so common.ref can be self-documenting
REF="$(grep -vE '^\s*(#|$)' "$REF_FILE" | head -1 | tr -d '[:space:]')"
if [[ -z "$REF" ]]; then
    warn "${REF_FILE} contains no ref; using the vendored copy as-is."
    exit 0
fi

# ---------------------------------------------------------------------------
# Skip when already current
# ---------------------------------------------------------------------------
# Only skip for refs that cannot move - a tag or a full SHA. Branch refs are
# always re-fetched, since their tip changes underneath us.
is_immutable_ref() {
    case "$1" in
        v[0-9]*)                      return 0 ;;  # version tag, e.g. v1.2.3
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) return 0 ;;  # SHA-ish
        *)                            return 1 ;;
    esac
}

if [[ -f "$STAMP_FILE" ]] && [[ "$(cat "$STAMP_FILE" 2>/dev/null)" == "$REF" ]] && is_immutable_ref "$REF"; then
    log "already at ${REF}, nothing to do."
    exit 0
fi

# ---------------------------------------------------------------------------
# Fetch
# ---------------------------------------------------------------------------
# Network-optional by design: any failure here falls back to the vendored copy
# with a warning, so offline and VPN-down rebuilds still work.
if ! command -v git >/dev/null 2>&1; then
    warn "git not found on the host; using the vendored copy as-is."
    exit 0
fi

TMPDIR_SYNC="$(mktemp -d 2>/dev/null || mktemp -d -t sync-common)"
cleanup() { rm -rf "$TMPDIR_SYNC"; }
trap cleanup EXIT

log "fetching ${UPSTREAM_REPO} @ ${REF}"
if ! git clone --quiet --depth 1 --branch "$REF" "$UPSTREAM_REPO" "${TMPDIR_SYNC}/repo" 2>/dev/null; then
    # --branch only accepts branches and tags, so retry for a raw commit SHA
    if ! ( git init --quiet "${TMPDIR_SYNC}/repo" \
           && git -C "${TMPDIR_SYNC}/repo" remote add origin "$UPSTREAM_REPO" \
           && git -C "${TMPDIR_SYNC}/repo" fetch --quiet --depth 1 origin "$REF" \
           && git -C "${TMPDIR_SYNC}/repo" checkout --quiet FETCH_HEAD ) 2>/dev/null; then
        if [[ -d "$COMMON_DIR" ]]; then
            warn "could not fetch ${REF} (offline, or ref does not exist)."
            warn "continuing with the vendored copy in ${COMMON_DIR}."
            exit 0
        fi
        warn "could not fetch ${REF} and there is no vendored copy to fall back to."
        exit 1
    fi
fi

SRC="${TMPDIR_SYNC}/repo/${UPSTREAM_SUBDIR}"
if [[ ! -d "$SRC" ]]; then
    warn "${UPSTREAM_SUBDIR}/ not found at ${REF}; keeping the vendored copy."
    exit 0
fi

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
# Replace only after a successful fetch, so a partial failure can never leave
# the consumer without a working common/ directory.
STAGING="${TMPDIR_SYNC}/staging"
mkdir -p "$STAGING"
cp -R "${SRC}/." "$STAGING/"
echo "$REF" > "${STAGING}/.synced-ref"
chmod +x "$STAGING"/*.sh 2>/dev/null || true

if [[ -d "$COMMON_DIR" ]] && diff -r -q "$COMMON_DIR" "$STAGING" >/dev/null 2>&1; then
    log "vendored copy already matches ${REF}."
    exit 0
fi

# ---------------------------------------------------------------------------
# Drift detected - show what changed, and ask before applying when we can
# ---------------------------------------------------------------------------
# initializeCommand runs on the HOST, so unlike the in-container lifecycle hooks
# there may be a real terminal attached and a prompt is possible. When there is
# not one (Cursor/VS Code usually runs this detached), applying silently is the
# right default: that is what makes a shared-layer change land in the same
# create cycle instead of needing a second rebuild.
#
# Override with POCKET_NEBULA_SYNC=auto (never ask) or =never (never apply).
if [[ -d "$COMMON_DIR" ]]; then
    log "shared layer has changed:"
    diff -r -q "$COMMON_DIR" "$STAGING" 2>/dev/null \
        | sed -e 's/^/     /' -e "s|${COMMON_DIR}/||g" -e "s|${STAGING}/||g" \
        | head -20
fi

SYNC_MODE="${POCKET_NEBULA_SYNC:-prompt}"

if [[ "$SYNC_MODE" == "never" ]]; then
    log "POCKET_NEBULA_SYNC=never - keeping the current vendored copy."
    exit 0
fi

if [[ "$SYNC_MODE" == "prompt" && -r /dev/tty && -t 0 ]]; then
    printf "   Apply these shared-layer updates? [Y/n] " > /dev/tty
    read -r REPLY < /dev/tty || REPLY=""
    case "$REPLY" in
        [nN]*)
            log "skipped. Re-run a rebuild to be asked again, or set POCKET_NEBULA_SYNC=auto."
            exit 0
            ;;
    esac
fi

rm -rf "${COMMON_DIR}.old"
[[ -d "$COMMON_DIR" ]] && mv "$COMMON_DIR" "${COMMON_DIR}.old"
mv "$STAGING" "$COMMON_DIR"
rm -rf "${COMMON_DIR}.old"

log "updated ${COMMON_DIR} to ${REF}"
log "commit the change to keep the vendored copy in step with common.ref."
