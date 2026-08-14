#!/bin/bash
# WORKAROUND: Cursor installs stale universal OpenVSX builds of the Python extensions.
# Platform-specific VSIXes from the Microsoft Marketplace are required for PET and for API
# compatibility between ms-python.python and ms-python.vscode-python-envs. Ansible 26.x
# depends on both extensions, so we cannot uninstall python-envs.
#
# Upstream tracking (open unless noted):
#   - EclipseFdn/publish-extensions#1002 (open) - universal OpenVSX builds lack PET;
#     platform-specific builds needed for ms-python.python and ms-python.vscode-python-envs
#     https://github.com/EclipseFdn/publish-extensions/issues/1002
#   - Cursor forum (open) - remote/devcontainer installs universal ms-python.python
#     https://forum.cursor.com/t/bug-remote-ssh-linux-installs-universal-ms-python-python-without-pet-binary/166594
#   - Cursor forum (open, duplicate report)
#     https://forum.cursor.com/t/remote-ssh-linux-cursor-installs-universal-ms-python-python-missing-pet-binary-python-environments-broken/166601
#   - microsoft/vscode-python#25820 (closed, info-needed) - MS: "We don't push to Open VSX"
#     https://github.com/microsoft/vscode-python/issues/25820
#   - eclipse/openvsx#1662 (closed) - redirected to publish-extensions#1002
#     https://github.com/eclipse/openvsx/issues/1662
#   - VSCodium/vscodium#2752 (open) - same PET-missing symptom on OpenVSX consumers
#     https://github.com/VSCodium/vscodium/issues/2752
#
# Remove this script when Cursor installs matching platform builds on attach, or OpenVSX
# ships PET-enabled platform packages. Observed failure modes without the fix:
#   1. universal build missing python-env-tools/bin/pet
#   2. ms-python.python 2025.x API mismatch with newer ms-python.vscode-python-envs
#   3. extensions.json pointing at removed universal dirs after manual repair
set -euo pipefail

CURSOR_CLI="$(command -v cursor || true)"
if [[ -z "$CURSOR_CLI" ]]; then
    exit 0
fi

EXT_DIR="${HOME}/.cursor-server/extensions"
if [[ ! -d "$EXT_DIR" ]]; then
    exit 0
fi

ARCH="$(uname -m)"
case "$ARCH" in
    aarch64) TARGET_PLATFORM="linux-arm64" ;;
    x86_64) TARGET_PLATFORM="linux-x64" ;;
    *)
        echo "⚠️  Unsupported architecture for Python extension fix: $ARCH"
        exit 0
        ;;
esac

marketplace_vsix_url() {
    local extension_id="$1"
    python3 - "$extension_id" "$TARGET_PLATFORM" <<'PY'
import json
import sys
import urllib.request

extension_id, target = sys.argv[1:3]
payload = json.dumps(
    {
        "filters": [{"criteria": [{"filterType": 7, "value": extension_id}]}],
        "flags": 954,
    }
).encode()
req = urllib.request.Request(
    "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery",
    data=payload,
    headers={
        "Content-Type": "application/json",
        "Accept": "application/json;api-version=7.1-preview.1",
    },
    method="POST",
)
with urllib.request.urlopen(req, timeout=60) as resp:
    data = json.load(resp)

for version in data["results"][0]["extensions"][0]["versions"]:
    if version.get("targetPlatform") != target:
        continue
    for file_info in version.get("files", []):
        if file_info.get("assetType") == "Microsoft.VisualStudio.Services.VSIXPackage":
            print(file_info["source"])
            raise SystemExit(0)

raise SystemExit(f"No {target} VSIX found for {extension_id}")
PY
}

install_platform_extension() {
    local extension_id="$1"
    local label="$2"
    local url
    url="$(marketplace_vsix_url "$extension_id")"
    local vsix_path="/tmp/${extension_id//./-}-${TARGET_PLATFORM}.vsix"
    echo "🐍 Installing platform-specific ${label} (${TARGET_PLATFORM})..."
    curl -fsSL "$url" -o "$vsix_path"
    "$CURSOR_CLI" --install-extension "$vsix_path" --force >/dev/null
}

needs_python_fix() {
  local python_ext envs_ext
  mapfile -t python_ext < <(find "$EXT_DIR" -maxdepth 1 -type d -name 'ms-python.python-*' 2>/dev/null || true)
  mapfile -t envs_ext < <(find "$EXT_DIR" -maxdepth 1 -type d -name 'ms-python.vscode-python-envs-*' 2>/dev/null || true)

  # Stale universal copies or old python builds that predate the envs API split.
  if find "$EXT_DIR" -maxdepth 1 -type d \( \
      -name 'ms-python.python-*-universal' -o \
      -name 'ms-python.vscode-python-envs-*-universal' -o \
      -name 'ms-python.python-2025.*' \
    \) 2>/dev/null | grep -q .; then
    return 0
  fi

  local has_python=0 has_envs=0
  for ext in "${python_ext[@]}"; do
    if [[ -x "${ext}/python-env-tools/bin/pet" ]]; then
      has_python=1
    fi
  done
  for ext in "${envs_ext[@]}"; do
    if [[ -x "${ext}/python-env-tools/bin/pet" ]]; then
      has_envs=1
    fi
  done

  if [[ "$has_python" -eq 0 || "$has_envs" -eq 0 ]]; then
    return 0
  fi

  # extensions.json can point at a removed universal build while the platform dir exists.
  python3 - "$EXT_DIR" <<'PY'
import json
import sys
from pathlib import Path

ext_dir = Path(sys.argv[1])
registry = ext_dir / "extensions.json"
if not registry.exists():
    raise SystemExit(1)

entries = json.loads(registry.read_text())
for entry in entries:
    ext_id = entry.get("identifier", {}).get("id")
    if ext_id not in {"ms-python.python", "ms-python.vscode-python-envs"}:
        continue
    rel = entry.get("relativeLocation")
    if not rel or not (ext_dir / rel).exists():
        raise SystemExit(0)
    if ext_id == "ms-python.python" and entry.get("version", "").startswith("2025."):
        raise SystemExit(0)

raise SystemExit(1)
PY
}

if ! needs_python_fix; then
    exit 0
fi

install_platform_extension "ms-python.python" "ms-python.python"
install_platform_extension "ms-python.vscode-python-envs" "ms-python.vscode-python-envs"

find "$EXT_DIR" -maxdepth 1 -type d \( \
    -name 'ms-python.python-*-universal' -o \
    -name 'ms-python.vscode-python-envs-*-universal' -o \
    -name 'ms-python.python-2025.*' \
  \) 2>/dev/null | while read -r stale_ext; do
    echo "🐍 Removing stale Python extension: $(basename "$stale_ext")"
    rm -rf "$stale_ext"
done

echo "✅ Python extensions fixed for ${TARGET_PLATFORM}"
