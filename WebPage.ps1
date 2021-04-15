Function DeployWebPageAndReferencingLinkItems([string] $itemRelativePath)
{
    Try
    {
        WriteInfo "Deploying '$itemRelativePath'" "DarkGray"

        $itemContent = DeployWebPage $itemRelativePath $false

        $referencingLinkItems = GetReferencingCustomLinkItems $itemRelativePath

        Foreach ($linkItem in $referencingLinkItems)
        {
            $linkItemRelativePath = GetItemRelativePathFromFullPath $linkItem.FullName

            WriteInfo "Deploying '$linkItemRelativePath'" "DarkGray"
            DeployWebPage $linkItemRelativePath $true $itemContent
        }
    }
    Catch
    {
        WriteError "An error has occurred while deploying the web page '$itemRelativePath': $_`n`n$($_.ScriptStackTrace)"
    }
}

Function DeployWebPage([string] $itemRelativePath, [bool] $useProvidedItemContent, [string] $itemContent)
{
    $webPageName = GetWebPageNameFromItemRelativePath $itemRelativePath
    
    $webPageNamesToQuery = New-Object System.Collections.Generic.List[string]
    $webPageNamesToQuery.Add($webPageName)

    $languageNamesToQuery = New-Object System.Collections.Generic.List[string]
    
    If ($Script:_config.UseFolderAsWebPageLanguage)
    {
        $immediateParentFolderName = GetImmediateParentFolderName $itemRelativePath
        If ($immediateParentFolderName -eq $Script:_webPageFolderName)
        {
            WriteError "Could not determine the target language for the item '$itemRelativePath'. When the 'UseFolderAsWebPageLanguage' setting is enabled, the target language for an item is determined by its parent folder. This item will not be deployed."
            return $null
        }
        Else
        {
            $languageNamesToQuery.Add($immediateParentFolderName)
        }
    }

    $webPageQuery = [BNH.BNH_CRM_Debugging.Managers.CRMManager]::GetQueryForWebPages($webPageNamesToQuery, $languageNamesToQuery, $Script:_config.PortalWebsiteName)
    $matchingWebPages = [BNH.BNH_CRM_Debugging.Managers.CRMManager]::QueryCRM($webPageQuery)

    If ($matchingWebPages.Entities.Count -eq 0)
    {
        $targetLanguageMessagePart = ""

        If ($Script:_config.UseFolderAsWebPageLanguage)
        {
            $targetLanguageMessagePart = "with target language '$languageNamesToQuery' "
        }

        WriteError "Could not locate the web page '$webPageName' $($targetLanguageMessagePart)under the website '$($Script:_config.PortalWebsiteName)'. The file '$itemRelativePath will not be deployed."
        return
    }

    $updatePerformed = $false
    $contentDeployed = UpdateWebPage $itemRelativePath $matchingWebPages.Entities[0] $useProvidedItemContent $itemContent ([ref] $updatePerformed)

    If ($updatePerformed)
    {
        If ($languageNamesToQuery.Count -eq 0)
        {
            WriteInfo "Updated web page '$webPageName'"
        }
        Else
        {
            WriteInfo "Updated web page '$webPageName' ('$languageNamesToQuery')"
        }
    }

    return $contentDeployed
}

##$itemContentToDeploy: If this is null, then content will be read from $itemRelativePath. This is typically passed when 
##this function is invoked to deploy a custom link item.
Function UpdateWebPage([string] $itemRelativePath, [Microsoft.Xrm.Sdk.Entity] $webPageRecordToUpdate, [bool] $useProvidedItemContent, [string] $itemContent, [ref][bool] $updatePerformed)
{
    $fileName = [IO.Path]::GetFileName($itemRelativePath)
    $itemExtension = [BNH.BNH_CRM_Debugging.Managers.FileNameInfoProvider]::ResolveFileExtension($fileName)

    If ($useProvidedItemContent)
    {
        $contentToDeploy = $itemContent
    }
    Else
    {
        $contentToDeploy = GetItemContent $itemRelativePath
    }

    $updateEntity = New-Object Microsoft.Xrm.Sdk.Entity -ArgumentList $webPageRecordToUpdate.LogicalName, $webPageRecordToUpdate.Id

    If ($itemExtension -eq ".js")
    {
        $updateEntity["adx_customjavascript"] = $contentToDeploy
        $requiresUpdate = $true
    }
    ElseIf ($itemExtension -eq ".css")
    {
        $updateEntity["adx_customcss"] = $contentToDeploy
        $requiresUpdate = $true
    }
    ElseIf ($itemExtension -eq ".htm" -or $itemExtension -eq ".html")
    {
        $updateEntity["adx_copy"] = $contentToDeploy
        $requiresUpdate = $true
    }
    Else
    {
        WriteWarning "The file '$itemRelativePath' is of an unknown extension and will not be deployed."
    }

    If ($requiresUpdate)
    {
        $Script:_crmManager.UpdateRecord($updateEntity) | Out-Null
        $updatePerformed.Value = $true
    }
    return $contentToDeploy
}

Function GetWebPageNameFromItemRelativePath([string] $itemRelativePath)
{
    $fileName = [IO.Path]::GetFileName($itemRelativePath)
    return [BNH.BNH_CRM_Debugging.Managers.FileNameInfoProvider]::ResolveFileNameWithoutExtension($fileName)
}