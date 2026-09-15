#!/usr/bin/env bash
# Usage: bash scripts/publish-sample.sh <GitLab SSH URL> <branch>
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <GitLab SSH URL> <branch>" >&2
  exit 2
fi
remote=$1
branch=$2
# SSH uses the developer's configured identity, avoiding tokens in URLs.
case "$remote" in
  git@*:*|ssh://git@*) ;;
  *) echo 'Provide the GitLab SSH clone URL.' >&2; exit 2 ;;
esac
git check-ref-format --branch "$branch" >/dev/null
cd "$(git rev-parse --show-toplevel)"
if [[ -n $(git status --porcelain) ]]; then
  echo 'Commit or move outstanding changes before publishing.' >&2
  exit 1
fi
# Only committed sample-app content becomes the GitLab repository root.
commit=$(git subtree split --prefix=sample-app HEAD)
git push "$remote" "$commit:refs/heads/$branch"
