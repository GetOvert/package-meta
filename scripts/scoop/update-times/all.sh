#!/bin/sh

if [ "$#" -ne 1 ]
then
  cat <<END >/dev/stderr
Usage: all.sh <repo>

<repo>: Path to Git repository
END
fi

repo="$1"

cd "$repo"

function index {
  [ -d "$1" ] || continue

  for file in "$1"/*.json
  do
    [ -f "$file" ] || continue

    echo "$(basename $file .json)\t$(git log -n 1 --pretty='%at' -- $file)"
  done
}

index bucket
