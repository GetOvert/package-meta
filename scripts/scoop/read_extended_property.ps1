Param (
  $AppName,
  $AppExecutableName,
  $ExtendedPropertyName
)

(New-Object -COMObject Shell.Application).
  NameSpace("$HOME\scoop\apps\$AppName\current").
  ParseName($AppExecutableName).
  ExtendedProperty($ExtendedPropertyName)
