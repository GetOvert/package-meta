Param (
  $AppName,
  $AppExecutableName
)

mkdir "$HOME\extracted-icons"

# https://github.com/GetOvert/windows-file-icon-extractor
$PSScriptRoot\FileIconExtractor.exe `
  256 `
  "$HOME\scoop\apps\$AppName\current\$AppExecutableName" `
  "$HOME\extracted-icons\$AppName.png"

echo "$HOME\extracted-icons\$AppName.png"
