#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Pre-merge gate for Formula/dev-platform.rb, beyond Homebrew's own checksum:
#   1. the formula equals the rendering of the release's identity record by the platform's own renderer
#      (syncom-systems/dev-platform main: releases/<version>/identity.json, tools/homebrew_formula.py);
#   2. the trusted installer, verifier and policy at the release's source revision equal the identity's pins;
#   3. that installer verifies the exact archive Homebrew downloaded (provenance, SBOM, build-environment and
#      continuity attestations; archive, revision and tree digest pins) before the change can merge.
# Usage: ci/verify-formula.sh <installed formula name>   (needs gh with a token, jq, git, python@3.14)
set -euo pipefail
formula_name=${1:?formula name}
formula=Formula/dev-platform.rb
repo=https://github.com/syncom-systems/dev-platform
work="${RUNNER_TEMP:?}/verify-formula"
rm -rf "$work"; mkdir -p "$work/pinned/tools" "$work/assets"
py="$(brew --prefix python@3.14)/bin/python3.14"

v=$(sed -nE 's|^  url "https://github.com/syncom-systems/dev-platform/releases/download/v([^/"]+)/dev-platform-([^/"]+)\.tar\.gz"$|\1 \2|p' "$formula")
read -r tag_v file_v <<< "$v"
if [ -z "${tag_v:-}" ] || [ "$tag_v" != "$file_v" ]; then
  echo "::error::the formula's url is not a dev-platform release asset"; exit 1
fi
v=$tag_v
echo "release v$v"

git init -q "$work/dp"
git -C "$work/dp" fetch -q --depth 1 "$repo" main
git -C "$work/dp" show "FETCH_HEAD:releases/$v/identity.json" > "$work/identity.json"
git -C "$work/dp" show "FETCH_HEAD:tools/homebrew_formula.py" > "$work/homebrew_formula.py"
"$py" -I "$work/homebrew_formula.py" --identity "$work/identity.json" --check "$formula"

pin() { jq -er "$1" "$work/identity.json"; }
rev=$(pin .source_revision)
git -C "$work/dp" fetch -q --depth 1 "$repo" "$rev"
for spec in "tools/verify_release.py:tools/verify_release.py:verify_release.py_sha256" \
            "trust/policy.json:policy.json:trust_policy_sha256" \
            "tools/install_release.py:tools/install_release.py:install_release.py_sha256"; do
  IFS=: read -r path out name <<< "$spec"
  git -C "$work/dp" show "$rev:$path" > "$work/pinned/$out"
  actual=$(shasum -a 256 "$work/pinned/$out" | cut -d' ' -f1)
  if [ "$actual" != "$(pin ".verifier_pins[\"$name\"]")" ]; then
    echo "::error::$path at $rev does not equal the identity's $name"; exit 1
  fi
done

gh release download "v$v" --repo syncom-systems/dev-platform --dir "$work/assets" \
  --pattern "dev-platform-$v.build-environment.json" --pattern "dev-platform-$v.continuity.json"
archive=$(brew --cache --formula "$formula_name")
test -f "$archive"
"$py" -I "$work/pinned/tools/install_release.py" --version "$v" --archive "$archive" \
  --environment "$work/assets/dev-platform-$v.build-environment.json" \
  --continuity "$work/assets/dev-platform-$v.continuity.json" \
  --store "$work/store" --source-revision "$rev" \
  --verifier-sha256 "$(pin '.verifier_pins["verify_release.py_sha256"]')" \
  --policy "$work/pinned/policy.json" --policy-sha256 "$(pin '.verifier_pins["trust_policy_sha256"]')" \
  --archive-sha256 "$(pin .archive_sha256)" --tree-sha256 "$(pin .tree_digest_pin)" --allow-unaccepted
