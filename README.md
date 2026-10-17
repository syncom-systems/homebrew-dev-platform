<!-- SPDX-License-Identifier: MIT -->
# Homebrew tap for Dev Platform

    brew install syncom-systems/dev-platform/dev-platform
    gh auth login                 # once: release attestations are verified with gh
    cd my-project && dev-platform setup

Installs the public `dev-platform` CLI and verifying launcher (with the `gh` and `python@3.14` it needs).
Supported: macOS on Apple silicon, Linux x86_64. Upgrade with `brew update && brew upgrade dev-platform`;
that changes the CLI only. Each project's committed pins (`dev-platform.toml`,
`dev-platform.release-pins.json`) select its platform release, which `dev-platform setup` installs with that
release's own trusted installer. Dev Platform: https://github.com/syncom-systems/dev-platform
(installation, paths, rollback and verification: `docs/homebrew.md`).

The formula is rendered by the platform's `tools/homebrew_formula.py` from the release's identity record
(`releases/<version>/identity.json`): the release asset's URL, its archive sha256, and a test that the
installed tree has the release's tree digest. Each release updates it through a pull request here, whose
checks also verify the archive with the release's trusted installer. Nothing private is packaged here.
