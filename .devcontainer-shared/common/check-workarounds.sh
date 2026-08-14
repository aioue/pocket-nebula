#!/usr/bin/env bash
# Scan the repo for WORKAROUND(url) markers and check upstream issue/PR status.
# Exit 0 if all tracked items are still open; exit 1 if any are closed (review for removal).
# Usage: scripts/check-workarounds.sh [--repo-root PATH]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${1:-}" == "--repo-root" ]]; then
    REPO_ROOT="${2:?--repo-root requires a path}"
    shift 2
fi

if ! command -v rg >/dev/null 2>&1; then
    echo "error: ripgrep (rg) is required" >&2
    exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required" >&2
    exit 2
fi
if ! command -v curl >/dev/null 2>&1; then
    echo "error: curl is required" >&2
    exit 2
fi

# file:url (dedupe URLs, keep first file seen)
declare -A URL_FILE=()
declare -A SEEN_URL=()

# Pattern in a variable: a literal ')' in the rg regex would close the process substitution below
RG_PATTERN='WORKAROUND\(https?://'

while IFS= read -r line; do
    # rg -n format: path:lineNum:content (path may contain colons only on Windows)
    if [[ ! "$line" =~ ^(.+):([0-9]+):(.*)$ ]]; then
        continue
    fi
    file="${BASH_REMATCH[1]}"
    text="${BASH_REMATCH[3]}"
    # Only track markers with a real URL (avoids AGENTS.md docs and this script's regex examples)
    if [[ "$text" =~ WORKAROUND\((https?://[^\)]+)\) ]]; then
        url="${BASH_REMATCH[1]}"
    else
        continue
    fi
    if [[ -z "${SEEN_URL[$url]+x}" ]]; then
        SEEN_URL[$url]=1
        URL_FILE[$url]="$file"
    fi
done < <(rg -n "$RG_PATTERN" "$REPO_ROOT" \
    --hidden \
    --no-ignore-vcs \
    --glob '!.git/**' \
    --glob '!**/node_modules/**' \
    --glob '!.cursor/**' \
    --glob '!scripts/check-workarounds.sh' \
    2>/dev/null || true)

if [[ ${#URL_FILE[@]} -eq 0 ]]; then
    echo "No WORKAROUND(url) markers found under ${REPO_ROOT}"
    exit 0
fi

CLOSED_COUNT=0
UNKNOWN_COUNT=0
OPEN_COUNT=0

github_issue_state() {
    local owner="$1" repo="$2" num="$3"
    local api="https://api.github.com/repos/${owner}/${repo}/issues/${num}"
    local body http_code
    body="$(curl -fsS --connect-timeout 10 --max-time 30 \
        -H 'Accept: application/vnd.github+json' \
        -H 'User-Agent: automation-workaround-check' \
        -w '\n%{http_code}' "$api" 2>/dev/null || printf '\n000')"
    http_code="${body##*$'\n'}"
    body="${body%$'\n'*}"
    if [[ "$http_code" != "200" ]]; then
        echo "unknown|HTTP ${http_code}"
        return
    fi
    jq -r 'if .state == "open" then "open" else "closed" end' <<<"$body" 2>/dev/null || echo "unknown|invalid JSON"
}

github_pr_state() {
    local owner="$1" repo="$2" num="$3"
    local api="https://api.github.com/repos/${owner}/${repo}/pulls/${num}"
    local body http_code merged
    body="$(curl -fsS --connect-timeout 10 --max-time 30 \
        -H 'Accept: application/vnd.github+json' \
        -H 'User-Agent: automation-workaround-check' \
        -w '\n%{http_code}' "$api" 2>/dev/null || printf '\n000')"
    http_code="${body##*$'\n'}"
    body="${body%$'\n'*}"
    if [[ "$http_code" != "200" ]]; then
        echo "unknown|HTTP ${http_code}"
        return
    fi
    merged="$(jq -r '.merged // false' <<<"$body" 2>/dev/null)"
    if [[ "$merged" == "true" ]]; then
        echo "closed|merged"
    else
        jq -r 'if .state == "open" then "open" else "closed" end' <<<"$body" 2>/dev/null || echo "unknown|invalid JSON"
    fi
}

gitlab_issue_state() {
    local host="$1" project="$2" num="$3"
    local enc_project
    enc_project="$(jq -rn --arg p "$project" '$p | @uri')"
    local api="https://${host}/api/v4/projects/${enc_project}/issues/${num}"
    local body http_code
    body="$(curl -fsS --connect-timeout 10 --max-time 30 \
        -H 'User-Agent: automation-workaround-check' \
        -w '\n%{http_code}' "$api" 2>/dev/null || printf '\n000')"
    http_code="${body##*$'\n'}"
    body="${body%$'\n'*}"
    if [[ "$http_code" != "200" ]]; then
        echo "unknown|HTTP ${http_code}"
        return
    fi
    jq -r 'if .state == "opened" then "open" else "closed" end' <<<"$body" 2>/dev/null || echo "unknown|invalid JSON"
}

check_url() {
    local url="$1"
    local state="unknown"
    local detail=""

    if [[ "$url" =~ ^https://github\.com/([^/]+)/([^/]+)/issues/([0-9]+) ]]; then
        local result
        result="$(github_issue_state "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}")"
        state="${result%%|*}"
        detail="${result#*|}"
    elif [[ "$url" =~ ^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
        local result
        result="$(github_pr_state "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}")"
        state="${result%%|*}"
        detail="${result#*|}"
    elif [[ "$url" =~ ^https://github\.com/([^/]+)/([^/]+)/commit/([0-9a-f]+) ]]; then
        # Upstream fix landed when commit exists on default branch; treat presence as "closed" for review
        state="closed"
        detail="kernel commit (verify fix is deployed on your hosts)"
    elif [[ "$url" =~ ^https://gitlab\.([^/]+)/([^/]+/[^/]+)/-/issues/([0-9]+) ]]; then
        local result
        result="$(gitlab_issue_state "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}")"
        state="${result%%|*}"
        detail="${result#*|}"
    else
        state="unknown"
        detail="unsupported URL pattern; check manually"
    fi

    printf '%s|%s' "$state" "$detail"
}

echo "Workaround upstream status (${#URL_FILE[@]} unique URL(s))"
echo "Repo: ${REPO_ROOT}"
echo ""

for url in "${!URL_FILE[@]}"; do
    file="${URL_FILE[$url]}"
    rel="${file#"${REPO_ROOT}/"}"
    IFS='|' read -r state detail <<< "$(check_url "$url")"

    case "$state" in
        open)
            OPEN_COUNT=$((OPEN_COUNT + 1))
            printf '[OPEN]    %s\n          %s\n' "$rel" "$url"
            ;;
        closed)
            CLOSED_COUNT=$((CLOSED_COUNT + 1))
            printf '[CLOSED]  %s\n          %s\n' "$rel" "$url"
            [[ -n "$detail" ]] && printf '          (%s)\n' "$detail"
            printf '          -> Review whether this workaround can be removed.\n'
            ;;
        *)
            UNKNOWN_COUNT=$((UNKNOWN_COUNT + 1))
            printf '[UNKNOWN] %s\n          %s\n' "$rel" "$url"
            [[ -n "$detail" ]] && printf '          (%s)\n' "$detail"
            ;;
    esac
    echo ""
done

echo "Summary: ${OPEN_COUNT} open, ${CLOSED_COUNT} closed (review), ${UNKNOWN_COUNT} unknown"

if [[ "$CLOSED_COUNT" -gt 0 ]]; then
    exit 1
fi
exit 0
