#!/bin/sh

if [ "$#" -ne 2 ]
then
  cat <<END >/dev/stderr
Usage: from_commit.sh <repo> <commit>

<repo>: Path to Git repository
<commit>: Git commit after which to begin indexing;
          everything newer will be included
END
fi

repo="$1"
from_commit="$2"

cd "$repo"

git log --reverse --pretty='%H' "$from_commit..HEAD" | tail -n +1 | while read -r commit
do
  authored_time="$(git log -n 1 --pretty='%at' "$commit")"

  git diff-tree --no-commit-id --name-only -r "$commit" | while read -r file_changed
  do
    case "$file_changed" in
    bucket/*.json)
      echo -e "$(basename $file_changed .json)\t$authored_time"
      ;;
    esac
  done
done
