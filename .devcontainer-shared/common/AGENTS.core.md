<!-- managed-by: pocket-nebula shared devcontainer layer -->
<!-- Generated file. Edit AGENTS.core.md upstream, or .devcontainer/AGENTS.site.md here. -->

# Agent Rules

Rules for AI assistants working in this codebase.

The section below is shared across every project using the pocket-nebula
devcontainer layer. Anything project-specific lives after the site marker at the
bottom, and detail lives in `.cursor/rules/*.mdc`.

## Rule maintenance

When the user corrects a mistake, generate a rule that prevents that *class* of
mistake, not just the instance. Present it as "Here's a rule to prevent this:"
and ask whether to add it. Suggest rules proactively when you notice repeated
issues or pitfalls - don't wait to be asked.

Decide where a new rule belongs: a rule that would help every project goes
upstream to `AGENTS.core.md` in pocket-nebula; a rule specific to this project
goes in `.devcontainer/AGENTS.site.md` or the relevant `.mdc`.

## Permissions

**Do freely:** read files, list directories, lint, syntax-check, dry-run
(`--check`).

**Ask first:** `git push`, force operations, branch deletion; installing or
removing packages; deleting files or directories; running playbooks against live
hosts (non-`--check`); terminating or destroying VMs.

**Never:** `--force` unless explicitly instructed.

When unsure whether an operation is destructive, assume it is and ask.

## Do it yourself first

Before asking anyone to check or run something, check or run it yourself if you
have access. Present findings as confirmed facts, not questions. Exception:
never read secret *values* to satisfy this - see Security.

## Planning and research

For work involving design choices:

1. Search for best practice, standards, or commonly tested approaches before
   proposing an implementation
2. Present findings with trade-offs. Where several good options exist, ask the
   user to choose rather than picking silently
3. Prefer established patterns unless there is a concrete reason to deviate

## Shell and CLI

Prioritise safety for destructive operations; read-only commands run normally.

- Before using unfamiliar CLI or API options, check `--help` or the official
  docs, then run a minimal test. This prevents wrong command names, missing
  required parameters and incorrect argument order
- Avoid pagers: `--no-pager`, `--batch`, or pipe to `cat`
- Use `-y`/`--yes` for routine non-destructive operations only
- Wrap network or long-running commands in `timeout 60s`; if one is terminated,
  check whether it was waiting for input
- Escape backticks, quotes and other shell-special characters
- Watch async operations for resource conflicts (package managers, services,
  file locks)

## Git

- Use [Conventional Commits](https://www.conventionalcommits.org/) titles
  (`feat:`, `fix:`, `chore:`, `ci:`, `docs:`, `refactor:`) with the motivation in
  the body. The commit-msg hook enforces the title format
- Don't assume you can commit again just because you were told to once
- Commit work in progress before complex git operations (rebase, merge,
  cherry-pick) to avoid losing changes
- Before complex git operations, check `git status` for a mid-rebase/merge state;
  read back destination files after moves to confirm content; use `git reflog` if
  content looks lost
- Before force-push, amend, squash or rebase on a PR branch, verify it still
  shares history with the base (`git merge-base HEAD upstream/main` succeeds).
  Orphan or disconnected history can close the PR and block reopening

## Code changes

- Only modify what was requested. No unrequested "optimisations" to unrelated
  code - mention opportunities, don't implement them
- Before applying ideas from a "working" foreign template or config, ask what to
  bring over. Don't apply everything
- Existing comments: understand why they exist and enhance them with context
  rather than removing them. Preserve original comments and echo messages when
  modifying scripts, and verify afterwards that they survived
- New comments: explain in plain language what a parameter does and why a value
  was chosen ("600s keeps connections alive for 10 minutes"). Skip redundant
  prefixes like "Performance:" - fold the purpose into the sentence
- Capture the motivation for a decision at the point the decision is made; it is
  reused in PR descriptions

## Dependencies

Check what is already installed before adding to a requirements file
(`uv pip list`, `ansible-galaxy collection list`). Only add genuinely missing
ones. The devcontainer installs Python tooling with `uv`, not pip or pipx.

## Unsafe fallbacks and workarounds

Never implement an unsafe fallback that could corrupt data. When you hit a bug:
research whether it is known, implement a workaround that preserves integrity,
and plan its removal. Avoid direct database manipulation when APIs fail,
bypassing validation, or assuming risky operations "usually work". Data integrity
beats convenience.

**Workaround markers.** When working around an upstream bug, put a
`WORKAROUND(url)` marker on the first comment line of the block, where `url` is
the upstream issue or PR that would make it unnecessary. Use the file's comment
syntax (`#`, `//`, `--`). With no trackable issue, use a commit URL or CVE link.

Every workaround needs a stated removal condition - the version or event after
which it is dead code - so it can be retired rather than accumulating. Prefer a
capability probe over a version comparison where possible, so the workaround
retires itself.

Run `scripts/check-workarounds.sh` to see which upstream items are still open.

## Security

Never commit passwords, credentials or sensitive data. Verify staged files before
committing and use `.gitignore` proactively.

**Never read secret values.** Do not run `ansible-vault view`/`decrypt`,
`kubectl get secret -o yaml`/`-o jsonpath`, or `cat`/`head`/`grep` on a vault
file or key material. Output leaks into chat and logs. Checking whether a secret
*exists* (`kubectl get secret -n <ns>`, `ls`) is fine; reading its contents is
not. This overrides "Do it yourself first".

To edit encrypted content, use `ansible-vault encrypt_string`, or
`pilfer open` + edit + `pilfer close`. Encryption is enforced by
`.githooks/vault-guard.sh`.

If a terminal capture or tool result already contains a secret: do not echo,
quote or reuse it; say that it is now in local logs; ask before rotating.

## Documentation

Create documentation for operational procedures (runbooks, deployment guides),
non-obvious architectural decisions, or when asked. One-time investigations
belong in comments or commit messages, not new documents.

## Writing style

Be clear and sequential. Avoid hype words - "enterprise grade", "comprehensive",
"robust", "powerful" - unless genuinely warranted. Say "logging", not
"comprehensive logging".

**No em-dashes or en-dashes** (`—` U+2014, `–` U+2013) anywhere: chat replies,
commits, issues, PRs, docs, tickets or code comments. Use a normal hyphen (`-`),
a spaced hyphen (` - `), or rephrase.

## Devcontainer

This project's `.devcontainer/` is a thin layer over the shared one in
[pocket-nebula](https://github.com/aioue/pocket-nebula).

- `.devcontainer/common/` is **vendored and regenerated**. Never edit it - changes
  are overwritten on the next container create. Edit the file upstream instead
- Project-specific devcontainer settings belong in `.devcontainer/devcontainer.json`,
  `.devcontainer/site.env`, or a hook in `.devcontainer/site/`
- The shared scripts refresh from `initializeCommand`, which runs on the host
  before the image build, so a shared change lands in the same rebuild
