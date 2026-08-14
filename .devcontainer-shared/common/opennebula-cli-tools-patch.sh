#!/bin/bash
# Compatibility stubs for the opennebula-cli gem installed standalone (without the
# full OpenNebula server packages). The CLI scripts require files that normally
# ship with the server package into /usr/lib/one/ruby/. When only the gem is
# installed those files are absent and the CLI fails with LoadError.
#
# Fix: drop no-op stubs into Ruby's vendor_ruby load path. When the gem binstub
# invokes the CLI, RubyGems has already activated the correct gem and set up load
# paths, so the stubs only need to exist to satisfy the require.
#
# Both gaps are fixed upstream, but at DIFFERENT versions:
#
#   load_opennebula_paths  missing until 7.2.1 - OpenNebula/one#7608 added the
#                          file to the gem's lib/. (Note: often mis-recorded as
#                          7.4.0; verified against the published gems, it is 7.2.1.)
#
#   HostSyncManager        required at the top level of one_helper/onehost_helper.rb
#                          until 7.4.0, so its absence broke EVERY onehost
#                          subcommand, not just `onehost sync`. 7.4.0 moved the
#                          require inside sync() behind a `rescue LoadError` that
#                          returns "'onehost sync' is only available on the
#                          frontend." No stub is needed from that version on.
#
# Each stub is therefore applied from its own probe rather than a version
# comparison. That means they self-retire on new enough gems and cannot drift
# out of date the way a hardcoded version check would.
#
# ---------------------------------------------------------------------------
# WHEN CAN THIS FILE BE DELETED?
# ---------------------------------------------------------------------------
# Both stubs are dead weight once the OLDEST opennebula-cli gem any project can
# install is >= 7.4.0. In practice that is governed by what
# detect-opennebula-version.sh derives from the live server, plus the
# OPENNEBULA_CLI_VERSION_FALLBACK / _OVERRIDE values in each site.env.
#
# Concretely, delete this script and its call in setup.sh when BOTH hold:
#   * every site.env fallback/override resolves to >= 7.4.0, and
#   * the servers are new enough that `detect-opennebula-version.sh cli-spec`
#     can never yield a spec that resolves below 7.4.0.
#
# Status at last check (2026-08-14): servers on 7.0.2, which yields "~> 7.0".
# Ruby resolves that to the newest 7.x - currently 7.4.0 - so the stubs are
# already no-ops in practice. They are retained only because a pinned OVERRIDE,
# or a future server that resolves lower, could still land on an older gem.
# Individual stubs may be removed sooner; see the per-stub notes below.
set -e

VENDOR_RUBY="/usr/lib/ruby/vendor_ruby"

# ---------------------------------------------------------------------------
# Stub 1: load_opennebula_paths  (needed below gem 7.2.1)
# ---------------------------------------------------------------------------
# REMOVE THIS BLOCK once no project can install a gem older than 7.2.1.
# Probed by attempting the require, which is exactly what the CLI binstubs do,
# so it is an accurate test of the real failure.
if ruby -e "gem 'opennebula-cli'; require 'load_opennebula_paths'" >/dev/null 2>&1; then
    echo "  ✓ load_opennebula_paths provided by the gem, stub not needed"
else
    echo "  🔧 Installing load_opennebula_paths stub (gem predates 7.2.1)..."
    sudo mkdir -p "$VENDOR_RUBY"
    sudo tee "${VENDOR_RUBY}/load_opennebula_paths.rb" > /dev/null << 'EOF'
# Stub for OpenNebula CLI standalone RubyGem installs.
# RubyGems already configures load paths when the CLI is invoked via the gem
# binstub, so this file exists only to satisfy the require emitted by CLI
# scripts that expect a full server installation.
EOF
    echo "  ✓ Stub written to ${VENDOR_RUBY}/load_opennebula_paths.rb"
fi

# ---------------------------------------------------------------------------
# Stub 2: HostSyncManager  (needed below gem 7.4.0)
# ---------------------------------------------------------------------------
# REMOVE THIS BLOCK once no project can install a gem older than 7.4.0.
#
# Probed STATICALLY, by looking at where the require sits in the installed gem's
# onehost_helper.rb. A top-level `require 'HostSyncManager'` (column 0) breaks
# every onehost subcommand when the module is absent; from 7.4.0 the require is
# indented inside sync() behind a rescue LoadError and needs no stub.
#
# Do NOT probe this by requiring one_helper/onehost_helper directly: that fails
# on 7.4.0 too, for unrelated reasons (the helper is not loadable standalone),
# so it reports a false positive and the stub would never retire. Verified
# against gems 7.2.1 and 7.4.0.
GEM_DIR="$(ruby -e "gem 'opennebula-cli'; print Gem.loaded_specs['opennebula-cli'].gem_dir" 2>/dev/null || true)"
ONEHOST_HELPER="${GEM_DIR}/lib/one_helper/onehost_helper.rb"

if [[ -z "$GEM_DIR" || ! -f "$ONEHOST_HELPER" ]]; then
    echo "  ⚠️  Could not locate onehost_helper.rb; skipping HostSyncManager check."
elif ! grep -qE "^require 'HostSyncManager'" "$ONEHOST_HELPER"; then
    echo "  ✓ HostSyncManager require is lazy (gem >= 7.4.0), stub not needed"
else
    echo "  🔧 Installing HostSyncManager stub (gem predates 7.4.0)..."
    sudo mkdir -p "$VENDOR_RUBY"
    sudo tee "${VENDOR_RUBY}/HostSyncManager.rb" > /dev/null << 'EOF'
# Stub for OpenNebula CLI standalone RubyGem installs.
# HostSyncManager is only meaningful on the frontend (`onehost sync`), where it
# ships with the server packages. This no-op class satisfies the top-level
# require so the other onehost subcommands work; `onehost sync` itself will not
# function against a CLI-only install, which is expected.
class HostSyncManager
  def initialize(*args); end
end
EOF
    echo "  ✓ Stub written to ${VENDOR_RUBY}/HostSyncManager.rb"

    # Confirm the stub is actually resolvable on the load path, so a mistake here
    # surfaces now rather than the first time someone runs onehost.
    if ! ruby -e "require 'HostSyncManager'" >/dev/null 2>&1; then
        echo "  ⚠️  HostSyncManager stub written but still not loadable."
        echo "     Check that ${VENDOR_RUBY} is on Ruby's load path:"
        echo "       ruby -e 'puts \$LOAD_PATH'"
    fi
fi
