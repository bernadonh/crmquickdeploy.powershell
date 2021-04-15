Function GetImmediateParentFolderName([string] $itemRelativePath)
{
    $directory = [IO.Path]::GetDirectoryName($itemRelativePath)
    return [IO.Path]::GetFileName($directory)
}

Function GetItemContent([string] $itemRelativePath)
{
    $contentBytes = Get-Content "$Script:_pathToWatch\$itemRelativePath" -Encoding Byte -ReadCount 0
    return [Text.Encoding]::UTF8.GetString($contentBytes)
}

Function GetItemRelativePathFromFullPath([string] $itemFullPath)
{
    return $itemFullPath.Substring($Script:_pathToWatch.Length + 1)
}

Function GetReferencingCustomLinkItems([string] $itemRelativePath)
{
    $referencingLinkItems = @()

    $linkItems = Get-ChildItem -Path $Script:_pathToWatch -File -Recurse -Filter "*.link"
    
    Foreach ($linkItem in $linkItems)
    {
        $linkItemContent = Get-Content $linkItem.FullName
        $linkItemContent = $linkItemContent -replace "\\", "\\"

        $linkItemSettings = ConvertFrom-StringData $linkItemContent

        If ($linkItemSettings.sourceItemPath -eq $itemRelativePath)
        {
            $referencingLinkItems += $linkItem
        }
    }

    return $referencingLinkItems
}