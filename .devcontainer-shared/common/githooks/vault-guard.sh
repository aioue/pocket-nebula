# vault-guard.sh - deterministic Ansible vault / pilfer checks for pre-commit.
# Canonical copy: pocket-nebula .devcontainer-shared/common/githooks/vault-guard.sh
# Vendored into each consumer at .devcontainer/common/githooks/ - do not edit here.
# Pilfer session guard adapted from https://github.com/aioue/pilfer#pre-commit-hook-suggested
#
# Shellcheck: vault-guard is sourced by pre-commit (not executed directly).

vault_guard_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

# Whole-file vault targets and encrypted key material paths.
vault_guard_is_vault_path() {
    local path="$1"
    local base base_lc
    base=$(basename "$path")
    base_lc=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')

    [[ "$base_lc" == "vault.yml" || "$base_lc" == "vault.yaml" ]] && return 0
    [[ "$base_lc" == *.vault.yml || "$base_lc" == *.vault.yaml ]] && return 0
    [[ "$base_lc" == *.vault ]] && return 0
    [[ "$path" == keys/* || "$path" == */keys/* ]] && return 0
    return 1
}

vault_guard_first_line() {
    local file="$1"
    head -n 1 "$file" 2>/dev/null | tr -d '\r'
}

vault_guard_is_encrypted_header() {
    local first_line="$1"
    [[ "$first_line" =~ ^\$ANSIBLE_VAULT ]]
}

# Prune nested clones and bulky trees from pilfer marker walks (avoids false positives
# from vendored external repos and speeds up find).
vault_guard_find_prune_expr() {
    printf '%s' \
        \( -path '*/.git' -o -path '*/.git/*' \
           -o -path '*/external-repos' -o -path '*/external-repos/*' \
           -o -path '*/node_modules' -o -path '*/node_modules/*' \
           -o -path '*/tmp' -o -path '*/tmp/*' \
           -o -path '*/.venv' -o -path '*/.venv/*' \
           -o -path '*/venv' -o -path '*/venv/*' \) -prune -o
}

# Refuse commits while pilfer has a session open (plaintext on disk + backups).
vault_guard_check_pilfer_session() {
    local repo_root="$1"
    local blocked=0
    local prune_expr hit
    prune_expr=$(vault_guard_find_prune_expr)

    if [[ -e "$repo_root/vaultedFileList.json" || -d "$repo_root/.vault" ]]; then
        echo "ERROR: pilfer session appears open (vaultedFileList.json or .vault/ present)."
        echo "  Run: pilfer close"
        echo "  Ref: https://github.com/aioue/pilfer#pre-commit-hook-suggested"
        return 1
    fi

    # One tree walk for subdir sessions and *.pilfer-open sidecars (prune bulky trees).
    # shellcheck disable=SC2086
    hit=$(find "$repo_root" $prune_expr \
        \( -name 'vaultedFileList.json' -o -type d -name '.vault' -o -name '*.pilfer-open' \) \
        -print -quit 2>/dev/null || true)
    if [[ -n "$hit" ]]; then
        if [[ "$hit" == *".pilfer-open" ]]; then
            echo "ERROR: pilfer session appears open (*.pilfer-open sidecar present)."
        else
            echo "ERROR: pilfer session appears open (vaultedFileList.json or .vault/ under repo)."
        fi
        echo "  Run: pilfer close"
        echo "  Ref: https://github.com/aioue/pilfer#pre-commit-hook-suggested"
        blocked=1
    fi

    return "$blocked"
}

# Every tracked vault file on disk must still be ciphertext (catches decrypt-and-forget
# even when vault.yml is not part of this commit).
vault_guard_check_tracked_vault_files() {
    local repo_root="$1"
    local blocked=0
    local file first_line

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        vault_guard_is_vault_path "$file" || continue
        if [[ ! -f "$repo_root/$file" ]]; then
            echo "ERROR: tracked vault file $file is missing from the working tree."
            echo "  Restore or re-encrypt before committing (decrypted copies moved aside are not OK)."
            blocked=1
            continue
        fi

        first_line=$(vault_guard_first_line "$repo_root/$file")
        if ! vault_guard_is_encrypted_header "$first_line"; then
            echo "ERROR: $file must be ansible-vault encrypted (missing \$ANSIBLE_VAULT header on disk)."
            echo "  Re-encrypt with: pilfer close   (if pilfer open) or"
            echo "                   ansible-vault encrypt --encrypt-vault-id admin --vault-password-file <pwfile> $file"
            blocked=1
        fi
    done < <(git -C "$repo_root" ls-files -- \
        ':(glob)**/vault.yml' ':(glob)**/vault.yaml' \
        ':(glob)**/*.vault.yml' ':(glob)**/*.vault.yaml' \
        ':(glob)**/*.vault' 'keys/*' ':(glob)**/keys/*' 2>/dev/null || true)

    return "$blocked"
}

# Staged vault blobs must be ciphertext in the index (catches git add of plaintext).
vault_guard_check_staged_vault_files() {
    local repo_root="$1"
    local staged_files="$2"
    local blocked=0
    local file first_line

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        vault_guard_is_vault_path "$file" || continue

        first_line=$(git -C "$repo_root" show ":$file" 2>/dev/null | head -n 1 | tr -d '\r' || true)
        if ! vault_guard_is_encrypted_header "$first_line"; then
            echo "ERROR: staged $file must be ansible-vault encrypted (missing \$ANSIBLE_VAULT header in index)."
            echo "  Encrypt before staging, or run pilfer close if a pilfer session is open."
            blocked=1
        fi
    done <<< "$staged_files"

    return "$blocked"
}

# Inline encrypt_string markers must not be committed (pilfer --include-encrypted-vars).
# Match pilfer suggested hook: refuse if marker is in the index blob, not only in diff hunks.
# Build the marker at runtime: pilfer open scans the whole tree for that literal comment
# and would false-positive if we embedded it in this hook script.
vault_guard_pilfer_inline_marker() {
    printf '%s%s' '# pilfer:' 'vault:'
}

vault_guard_check_staged_pilfer_markers() {
    local repo_root="$1"
    local blocked=0
    local hits marker
    marker=$(vault_guard_pilfer_inline_marker)

    hits=$(git -C "$repo_root" diff --cached --name-only -z -- '*.yml' '*.yaml' 2>/dev/null \
        | xargs -0 -r git -C "$repo_root" grep --cached -l "$marker" -- 2>/dev/null || true)
    if [[ -n "$hits" ]]; then
        echo "ERROR: staged YAML contains pilfer inline vault markers (pilfer inline session still open)."
        echo "  Run: pilfer close"
        blocked=1
    fi

    return "$blocked"
}

vault_guard_check_staged_plaintext_patterns() {
    local repo_root="$1"
    local staged_files="$2"
    local blocked=0
    local file added_lines line content base

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ "$file" == .githooks/* ]] && continue
        [[ "$file" == *.md || "$file" == *.mdc ]] && continue

        added_lines=$(git -C "$repo_root" diff --cached --unified=0 -- "$file" | sed -n '/^+[^+]/p' || true)
        [[ -z "$added_lines" ]] && continue

        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            content="${line:1}"

            if echo "$content" | grep -qE 'ansible_password:[[:space:]]*[^[:space:]]'; then
                if ! echo "$content" | grep -q '!vault'; then
                    echo "ERROR: $file contains plaintext ansible_password assignment."
                    blocked=1
                    break
                fi
            fi

            if echo "$content" | grep -qE 'BEGIN.*PRIVATE KEY'; then
                echo "ERROR: $file contains a private key header."
                blocked=1
                break
            fi

            if echo "$content" | grep -qE 'key[[:space:]]*=[[:space:]]*AQ'; then
                echo "ERROR: $file contains a plaintext Ceph key assignment."
                blocked=1
                break
            fi
        done <<< "$added_lines"

        base=$(basename "$file")
        if [[ "$base" == one_auth* || "$base" == one_url* ]]; then
            content=$(git -C "$repo_root" show ":$file" 2>/dev/null || true)
            if echo "$content" | grep -qE '^[^[:space:]#]+:[^[:space:]]+$'; then
                echo "ERROR: $file looks like a one_auth credential file (user:password)."
                blocked=1
            fi
        fi
    done <<< "$staged_files"

    return "$blocked"
}

# Run all vault/pilfer guards. Sets vault_guard_blocked=1 on failure.
vault_guard_run() {
    local repo_root staged_files
    vault_guard_blocked=0
    repo_root=$(vault_guard_repo_root)
    staged_files=$(git -C "$repo_root" diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)

    vault_guard_check_pilfer_session "$repo_root" || vault_guard_blocked=1
    vault_guard_check_tracked_vault_files "$repo_root" || vault_guard_blocked=1

    if [[ -n "$staged_files" ]]; then
        vault_guard_check_staged_vault_files "$repo_root" "$staged_files" || vault_guard_blocked=1
        vault_guard_check_staged_pilfer_markers "$repo_root" || vault_guard_blocked=1
        vault_guard_check_staged_plaintext_patterns "$repo_root" "$staged_files" || vault_guard_blocked=1
    fi
}
