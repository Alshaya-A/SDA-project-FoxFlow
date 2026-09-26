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
if [[ -n $(git status --porcelain --untracked-files=no) ]]; then
  echo 'Commit or move tracked changes before publishing.' >&2
  exit 1
fi
# Only committed sample-app content becomes the GitLab repository root. Keep
# any GitLab-only commits as ancestors so the push remains fast-forward.
split_commit=$(git subtree split --prefix=sample-app HEAD)
tree=$(git rev-parse "${split_commit}^{tree}")

if git fetch "$remote" "$branch"; then
  remote_head=$(git rev-parse FETCH_HEAD)
  remote_tree=$(git rev-parse "${remote_head}^{tree}")
  if [[ "$tree" == "$remote_tree" ]]; then
    echo 'GitLab already contains the current sample-app files.'
    exit 0
  fi
  commit=$(printf 'Publish sample-app from %s\n' "$(git rev-parse --short HEAD)" | \
    git commit-tree "$tree" -p "$remote_head")
else
  commit="$split_commit"
fi

git push "$remote" "$commit:refs/heads/$branch"
