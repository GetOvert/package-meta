#!/bin/sh

if [ "$#" -ne 2 ]
then
  cat <<END >/dev/stderr
Usage: changed_since_commit.sh <repo> <commit>

<repo>: Path to Git repository
<commit>: Git commit after which to look for changed casks;
          everything newer will be included
END
fi

repo="$1"
from_commit="$2"

cd "$repo"

git log --reverse --pretty='%H' "$from_commit..$(git symbolic-ref HEAD)" | tail -n +1 | while read -r commit
do
  git diff-tree --no-commit-id --name-only -r "$commit" | while read -r file_changed
  do
    case "$file_changed" in
    Casks/*.rb)
      echo "$(basename $file_changed .rb)"
    esac
  done
done
