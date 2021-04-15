Function DeployEntityFormAndReferencingLinkItems([string] $itemRelativePath)
{
    Try
    {
        WriteInfo "Deploying '$itemRelativePath'" "DarkGray"

        $itemContent = DeployEntityForm $itemRelativePath $false

        $referencingLinkItems = GetReferencingCustomLinkItems $itemRelativePath

        Foreach ($linkItem in $referencingLinkItems)
        {
            $linkItemRelativePath = GetItemRelativePathFromFullPath $linkItem.FullName

            WriteInfo "Deploying '$linkItemRelativePath'" "DarkGray"
            DeployEntityForm $linkItemRelativePath $true $itemContent
        }
    }
    Catch
    {
        WriteError "An error has occurred while deploying the entity form '$itemRelativePath': $_`n`n$($_.ScriptStackTrace)"
    }
}

Function DeployEntityForm([string] $itemRelativePath, [bool] $useProvidedItemContent, [string] $itemContent)
{
    $entityFormName = GetEntityFormNameFromItemRelativePath $itemRelativePath
    
    $entityFormNamesToQuery = New-Object System.Collections.Generic.List[string]
    $entityFormNamesToQuery.Add($entityFormName)
    
    If ($Script:_config.IsPortalv7)
    {
        $websiteNameForQuery = $null
    }
    Else
    {
        $websiteNameForQuery = $Script:_config.PortalWebsiteName
    }

    $entityFormQuery = [BNH.CRMQuickDeploy.Core.Managers.CRMManager]::GetQueryForEntityForms($entityFormNamesToQuery, $websiteNameForQuery)
    $matchingEntityForms = [BNH.CRMQuickDeploy.Core.Managers.CRMManager]::QueryCRM($entityFormQuery)

    If ($matchingEntityForms.Entities.Count -eq 0)
    {
        $warningMessage = "Could not locate the entity form '$entityFormName'"
        
        If ($websiteNameForQuery -eq $null)
        {
            $warningMessage = "$warningMessage."
        }
        Else
        {
            $warningMessage = "$warningMessage under the website '$websiteNameForQuery'."
        }

		WriteWarning "$warningMessage The file '$itemRelativePath' will not be deployed."
        return
    }

    $updatePerformed = $false
    $contentDeployed = UpdateEntityForm $itemRelativePath $matchingEntityForms.Entities[0] $useProvidedItemContent $itemContent ([ref] $updatePerformed)

    If ($updatePerformed)
    {
        WriteInfo "Updated entity form '$entityFormName'"
    }
    return $contentDeployed
}

##$itemContentToDeploy: If this is null, then content will be read from $itemRelativePath. This is typically passed when 
##this function is invoked to deploy a custom link item.
Function UpdateEntityForm([string] $itemRelativePath, [Microsoft.Xrm.Sdk.Entity] $entityFormRecordToUpdate, [bool] $useProvidedItemContent, [string] $itemContent, [ref][bool] $updatePerformed)
{
    $fileName = [IO.Path]::GetFileName($itemRelativePath)
    $itemExtension = [BNH.CRMQuickDeploy.Core.Managers.FileNameInfoProvider]::ResolveFileExtension($fileName)

    If ($useProvidedItemContent)
    {
        $contentToDeploy = $itemContent
    }
    Else
    {
        $contentToDeploy = GetItemContent $itemRelativePath
    }

    $updateEntity = New-Object Microsoft.Xrm.Sdk.Entity -ArgumentList $entityFormRecordToUpdate.LogicalName, $entityFormRecordToUpdate.Id

    If ($itemExtension -eq ".js")
    {
        $updateEntity["adx_registerstartupscript"] = $contentToDeploy
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

Function GetEntityFormNameFromItemRelativePath([string] $itemRelativePath)
{
    $fileName = [IO.Path]::GetFileName($itemRelativePath)
    return [BNH.CRMQuickDeploy.Core.Managers.FileNameInfoProvider]::ResolveFileNameWithoutExtension($fileName)
}