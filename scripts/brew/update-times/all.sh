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

  for file in "$1"/*.rb
  do
    [ -f "$file" ] || continue

    echo "$2\t$(basename $file .rb)\t$(git log -n 1 --pretty='%at' -- $file)"
  done
}

index . formula
index Formula formula
index Casks cask
