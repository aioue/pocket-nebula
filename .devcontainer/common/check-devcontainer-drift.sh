#!/bin/bash
# Report drift in the one layer that cannot synchronise itself: devcontainer.json.
#
# The base image (layer A) and the vendored scripts (layer B) both propagate on
# their own - a rebuild picks up the image, and sync-common.sh refreshes the
# scripts before the build. devcontainer.json is the exception: the tool has
# already parsed it before any hook of ours can run, so it can only be checked
# and reported on, never auto-merged.
#
# This WARNS ONLY. It never exits non-zero, because failing postStartCommand on
# every container start is far more annoying than the drift it is reporting.
#
# What it flags - only things that genuinely go stale:
#   1. Values duplicated verbatim from the base image (extensions, settings,
#      mounts). These are dead weight: identical today, silently divergent the
#      moment the image changes.
#   2. containerEnv keys that collide with the image's. These use last-value-wins
#      semantics, so a local value silently overrides the shared one.
#   3. The vendored common/ directory being out of step with common.ref.
#
# What it deliberately does NOT flag: a local `mounts` entry or lifecycle command
# that merely coexists with the image's. Per the spec, mounts are collected as a
# list and lifecycle commands are all collected in sequence - they concatenate
# rather than override, so a project adding its own history volume or an extra
# postStartCommand is correct usage, not drift.
set -e

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVCONTAINER_DIR="$(dirname "$COMMON_DIR")"
CONFIG="${DEVCONTAINER_DIR}/devcontainer.json"
REF_FILE="${DEVCONTAINER_DIR}/common.ref"
STAMP_FILE="${COMMON_DIR}/.synced-ref"

# --- vendored copy vs pinned ref -------------------------------------------
if [[ -f "$REF_FILE" && -f "$STAMP_FILE" ]]; then
    WANT="$(grep -vE '^\s*(#|$)' "$REF_FILE" | head -1 | tr -d '[:space:]')"
    HAVE="$(tr -d '[:space:]' < "$STAMP_FILE")"
    if [[ -n "$WANT" && "$WANT" != "$HAVE" ]]; then
        echo "⚠️  devcontainer drift: common/ is at '${HAVE}' but common.ref pins '${WANT}'."
        echo "   The sync could not reach the upstream repo. Rebuild with network access to update."
    fi
fi

[[ -f "$CONFIG" ]] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

python3 - "$CONFIG" <<'PY' || true
import json, re, sys

# devcontainer.json is JSONC: strip // and /* */ comments and trailing commas.
# Naive but adequate - it only has to survive our own hand-written files.
raw = open(sys.argv[1]).read()
raw = re.sub(r'/\*.*?\*/', '', raw, flags=re.S)
raw = re.sub(r'(?<!:)//[^\n]*', '', raw)
raw = re.sub(r',(\s*[}\]])', r'\1', raw)
try:
    cfg = json.loads(raw)
except json.JSONDecodeError as e:
    print(f"⚠️  devcontainer drift: could not parse devcontainer.json ({e}); skipping check.")
    raise SystemExit(0)

# What the base image's devcontainer.metadata supplies. Kept in step with
# .devcontainer-shared/image/Dockerfile in pocket-nebula.
IMAGE_EXTENSIONS = {
    "redhat.ansible", "charliermarsh.ruff", "timonwong.shellcheck",
    "docker.docker", "DavidAnson.vscode-markdownlint",
}
IMAGE_CONTAINER_ENV = {
    "BASH_ENV", "ANSIBLE_FORCE_COLOR", "PY_COLORS", "FORCE_COLOR", "CLICOLOR_FORCE",
}
IMAGE_MOUNT_TARGETS = {
    "/home/vscode/.ssh", "/home/vscode/.one", "/home/vscode/.ansible-vault",
}
IMAGE_SETTING_KEYS = {
    "terminal.integrated.defaultProfile.linux", "files.watcherExclude",
    "ansible.python.interpreterPath", "ansible.validation.lint.enabled",
    "ansible.validation.lint.path", "python.languageServer",
    "python.useEnvironmentsExtension", "python.defaultInterpreterPath",
    "ruff.enable", "ruff.lint.enable", "ruff.format.enable", "ruff.fixAll",
    "ruff.organizeImports", "ruff.showSyntaxErrors", "ruff.path",
    "markdownlint.run", "files.associations", "[python]",
}

notes = []
vscode = cfg.get("customizations", {}).get("vscode", {})

dupes = IMAGE_EXTENSIONS & set(vscode.get("extensions", []) or [])
if dupes:
    notes.append("extensions duplicated from the base image: " + ", ".join(sorted(dupes)))

dupe_settings = IMAGE_SETTING_KEYS & set(vscode.get("settings", {}) or {})
if dupe_settings:
    notes.append("settings duplicated from the base image: " + ", ".join(sorted(dupe_settings)))

# containerEnv is last-value-wins, so a collision silently overrides the image.
collisions = IMAGE_CONTAINER_ENV & set(cfg.get("containerEnv", {}) or {})
if collisions:
    notes.append("containerEnv overrides the base image (last value wins): "
                 + ", ".join(sorted(collisions)))

# Mounts concatenate, so only an exact re-declaration of a shared target is drift.
for mount in cfg.get("mounts", []) or []:
    spec = mount if isinstance(mount, str) else ",".join(
        f"{k}={v}" for k, v in mount.items())
    for part in spec.split(","):
        if part.startswith("target=") and part[len("target="):] in IMAGE_MOUNT_TARGETS:
            notes.append(f"mount re-declares a base image target: {part[len('target='):]}")

if notes:
    print("⚠️  devcontainer drift notes (warnings only, nothing is broken):")
    for n in notes:
        print(f"   • {n}")
    print("   These duplicate what the base image already provides, so they will")
    print("   silently stop tracking it. Remove them unless the override is deliberate.")
PY
