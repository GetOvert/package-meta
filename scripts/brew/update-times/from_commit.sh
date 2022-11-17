#!/bin/sh

if [ "$#" -ne 1 ]
then
  cat <<END
Usage: from_commit.sh <repo> <commit>

<repo>: Path to Git repository
<commit>: Git commit after which to begin indexing;
          everything newer will be included
END
fi

repo="$1"
from_commit="$2"

cd "$repo"

git log --reverse --pretty='%H' "$from_commit..$(git symbolic-ref HEAD)" | tail -n +1 | while read -r commit
do
  authored_time="$(git log -n 1 --pretty='%at' "$commit")"

  git diff-tree --no-commit-id --name-only -r "$commit" | while read -r file_changed
  do
    case "$file_changed" in
    Casks/*.rb)
      echo "cask\t$(basename $file_changed .rb)\t$authored_time"
      ;;
    *.rb)
      echo "formula\t$(basename $file_changed .rb)\t$authored_time"
    esac
  done
done
