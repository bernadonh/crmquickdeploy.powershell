Function GetImmediateParentFolderName([string] $itemRelativePath)
{
    $directory = [IO.Path]::GetDirectoryName($itemRelativePath)
    return [IO.Path]::GetFileName($directory)
}

Function GetItemContent([string] $itemRelativePath)
{
    $contentBytes = Get-Content "$Script:_pathToWatch\$itemRelativePath" -Encoding Byte -ReadCount 0

    #Detect and remove BOM
    If ($contentBytes.Length -gt 2)
    {
        If ($contentBytes[0] -eq 239 -and $contentBytes[1] -eq 187 -and $contentBytes[2] -eq 191)
        {
            $contentBytes = $contentBytes[3..($contentBytes.Length - 1)]
        }
    }

    return [Text.Encoding]::UTF8.GetString($contentBytes)
}

Function GetItemContentAsBase64([string] $itemRelativePath)
{
    $contentBytes = Get-Content "$Script:_pathToWatch\$itemRelativePath" -Encoding Byte -ReadCount 0
    return [Convert]::ToBase64String($contentBytes)
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