#!/usr/bin/env bash
# Mirror the latest Tasshack/dreame-vacuum release into this fork.
#
# Merges the upstream release tag, keeps frontend.py (the paid Dreame Vacuum
# Card's obfuscated licence client) out, checks the integration still treats
# that module as optional, then tags <tag>-nocard1 and publishes a release
# carrying the flat dreame_vacuum.zip that hacs.json promises.
#
#   UPSTREAM_TAG=v2.0.3  merge this tag instead of upstream's latest release
#   RELEASE=0            push the merge and tag, skip the GitHub release
set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-Tasshack/dreame-vacuum}"
COMPONENT=custom_components/dreame_vacuum
STRIPPED="${COMPONENT}/frontend.py"

fail() { echo "::error::$*" >&2; exit 1; }

tag="${UPSTREAM_TAG:-$(gh api "repos/${UPSTREAM_REPO}/releases/latest" --jq .tag_name)}"
[[ -n "$tag" ]] || fail "could not resolve the latest ${UPSTREAM_REPO} release"
ours="${tag}-nocard1"

if git ls-remote --exit-code --tags origin "refs/tags/${ours}" >/dev/null; then
  echo "${ours} already released — nothing to do"
  exit 0
fi

git remote get-url upstream >/dev/null 2>&1 \
  || git remote add upstream "https://github.com/${UPSTREAM_REPO}.git"
git fetch --quiet --no-tags upstream "refs/tags/${tag}:refs/tags/${tag}"

echo "Merging ${UPSTREAM_REPO}@${tag}"
if ! git merge --no-ff --no-edit -m "Merge upstream ${tag}" "$tag"; then
  # The one conflict this fork expects: upstream edited the file it deletes.
  git rm --quiet --ignore-unmatch "$STRIPPED"
  unresolved="$(git diff --name-only --diff-filter=U)"
  [[ -z "$unresolved" ]] || fail "merging ${tag} conflicts beyond ${STRIPPED}: ${unresolved//$'\n'/, }"
  git commit --quiet --no-edit
fi

# Upstream may reintroduce the module under a merge that did not conflict.
if [[ -e "$STRIPPED" ]]; then
  git rm --quiet "$STRIPPED"
  git commit --quiet -m "Strip the paid Dreame Vacuum Card client from ${tag}"
fi

# Stripping is only safe while upstream imports the module optionally.
grep -q 'import_module(f"{__package__}.frontend")' "${COMPONENT}/__init__.py" \
  && grep -q 'except ModuleNotFoundError' "${COMPONENT}/__init__.py" \
  || fail "${COMPONENT}/__init__.py no longer imports frontend optionally"
if hard="$(grep -rnE 'from \.frontend import|import [A-Za-z_.]*\.frontend( |$)' "$COMPONENT" --include='*.py')"; then
  fail "a module imports frontend unconditionally: ${hard}"
fi
grep -q "\"version\": \"${tag}\"" "${COMPONENT}/manifest.json" \
  || fail "manifest.json version does not match ${tag}"
python3 -m compileall -q "$COMPONENT" >/dev/null || fail "${COMPONENT} does not compile"
find "$COMPONENT" -name __pycache__ -type d -prune -exec rm -rf {} +

if ! git push --quiet origin HEAD:master; then
  fail "push rejected — if ${tag} changes .github/workflows, GITHUB_TOKEN may not push it; merge this release by hand"
fi
git tag -a "$ours" -m "${UPSTREAM_REPO} ${tag} without the paid Dreame Vacuum Card"
git push --quiet origin "refs/tags/${ours}"
echo "Tagged ${ours}"

[[ "${RELEASE:-1}" == 1 ]] || exit 0

zip_dir="$(mktemp -d)"
( cd "$COMPONENT" && zip -qrX "${zip_dir}/dreame_vacuum.zip" . -x '*__pycache__*' )
gh release create "$ours" "${zip_dir}/dreame_vacuum.zip" --latest \
  --title "$ours" \
  --notes "[${UPSTREAM_REPO} ${tag}](https://github.com/${UPSTREAM_REPO}/releases/tag/${tag}) without \`frontend.py\`, the paid Dreame Vacuum Card's licence client. See [FORK.md](FORK.md)."
echo "Released ${ours}"
