Function DeployContentSnippet([string] $itemRelativePath)
{
    Try
    {
        WriteInfo "Deploying '$itemRelativePath'" "DarkGray"
                
        $contentSnippetName = GetContentSnippetNameFromItemRelativePath $itemRelativePath
    
        $contentSnippetNamesToQuery = New-Object System.Collections.Generic.List[string]
        $contentSnippetNamesToQuery.Add($contentSnippetName)
        
        $contentSnippetQuery = [BNH.CRMQuickDeploy.Core.Managers.CRMManager]::GetQueryForContentSnippets($contentSnippetNamesToQuery, $Script:_config.PortalWebsiteName)
        $contentSnippetCandidates = [BNH.CRMQuickDeploy.Core.Managers.CRMManager]::QueryCRM($contentSnippetQuery).Entities

        $contentSnippetLanguageName = TryGetLanguageNameForContentSnippetItemByFolder $itemRelativePath
        
        If ($contentSnippetLanguageName -ne $null)
        {
            $contentSnippetLanguageNameMessagePart = " ($contentSnippetLanguageName)"
        }

        $matchingContentSnippets = $contentSnippetCandidates | Where-Object { -not [System.String]::IsNullOrEmpty($_["adx_name"]) -and $_["adx_name"].Equals($contentSnippetName, [System.StringComparison]::OrdinalIgnoreCase) `
            -and (($contentSnippetLanguageName -eq $null -and $_["adx_contentsnippetlanguageid"] -eq $null) -or ($contentSnippetLanguageName -ne $null -and $_["adx_contentsnippetlanguageid"] -ne $null -and $contentSnippetLanguageName.Equals($_["adx_contentsnippetlanguageid"].Name, [System.StringComparison]::OrdinalIgnoreCase))) }

        If ($matchingContentSnippets.Length -eq 0)
        {
            CreateContentSnippet $contentSnippetName $contentSnippetLanguageName $itemRelativePath
            WriteInfo "Created content snippet '$contentSnippetName'$contentSnippetLanguageNameMessagePart"
        }
        Else
        {
            UpdateContentSnippet $itemRelativePath $matchingContentSnippets
            WriteInfo "Updated content snippet '$contentSnippetName'$contentSnippetLanguageNameMessagePart"
        }
    }
    Catch
    {
        WriteError "An error has occurred while deploying the content snippet '$itemRelativePath': $_`n`n$($_.ScriptStackTrace)"
    }
}

Function CreateContentSnippet([string] $contentSnippetName, [string] $contentSnippetLanguageName, [string] $itemRelativePath)
{
    $snippetSource = GetItemContent $itemRelativePath
    $snippetType = [BNH.CRMQuickDeploy.Core.Managers.FileNameInfoProvider]::TryGetContentSnippetType($itemRelativePath)

    $Script:_crmManager.CreateContentSnippet($contentSnippetName, $snippetSource, $snippetType, $contentSnippetLanguageName, $Script:_targetWebsite.Id, $Script:_config.PortalWebsiteName)
}

Function UpdateContentSnippet([string] $itemRelativePath, [Microsoft.Xrm.Sdk.Entity] $contentSnippetRecordToUpdate)
{
    $snippetSource = GetItemContent $itemRelativePath
    $snippetType = [BNH.CRMQuickDeploy.Core.Managers.FileNameInfoProvider]::TryGetContentSnippetType($itemRelativePath)

    $Script:_crmManager.UpdateContentSnippet($contentSnippetRecordToUpdate.Id, $snippetSource, $snippetType)
}

Function GetContentSnippetNameFromItemRelativePath([string] $itemRelativePath)
{
    $fileName = [IO.Path]::GetFileName($itemRelativePath)
    return [BNH.CRMQuickDeploy.Core.Managers.FileNameInfoProvider]::GetContentSnippetName($fileName)
}

Function TryGetLanguageNameForContentSnippetItemByFolder([string] $itemRelativePath) 
{
    $foldersInPath = [System.IO.Path]::GetDirectoryName($itemRelativePath).Split("\")

    If ($foldersInPath.Length -eq 1)
    {
        return $null
    }

    return $foldersInPath[$foldersInPath.Length - 1]
}