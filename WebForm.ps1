Function DeployWebFormAndReferencingLinkItems([string] $itemRelativePath)
{
    Try
    {
        WriteInfo "Deploying '$itemRelativePath'" "DarkGray"

        $itemContent = DeployWebForm $itemRelativePath $false

        $referencingLinkItems = GetReferencingCustomLinkItems $itemRelativePath

        Foreach ($linkItem in $referencingLinkItems)
        {
            $linkItemRelativePath = GetItemRelativePathFromFullPath $linkItem.FullName

            WriteInfo "Deploying '$linkItemRelativePath'" "DarkGray"
            DeployWebForm $linkItemRelativePath $true $itemContent
        }
    }
    Catch
    {
        WriteError "An error has occurred while deploying the web form '$itemRelativePath': $_`n`n$($_.ScriptStackTrace)"
    }
}

Function DeployWebForm([string] $itemRelativePath, [bool] $useProvidedItemContent, [string] $itemContent)
{
    $webFormName = GetWebFormNameFromItemRelativePath $itemRelativePath
    
    If ($webFormName -eq $Script:_webFormFolderName)
    {
        WriteWarning "The web form item '$itemRelativePath' must be placed in a sub-folder under the '$Script:_webFormFolderName' folder. This sub-folder identifies the target web form name. This item will not be deployed."
        return
    }

    $webFormNamesToQuery = New-Object System.Collections.Generic.List[string]
    $webFormNamesToQuery.Add($webFormName)
    
    If ($Script:_config.IsPortalv7)
    {
        $websiteNameForQuery = $null
    }
    Else
    {
        $websiteNameForQuery = $Script:_config.PortalWebsiteName
    }

    $webFormQuery = [BNH.BNH_CRM_Debugging.Managers.CRMManager]::GetQueryForWebForms($webFormNamesToQuery, $websiteNameForQuery)
    $matchingWebForms = [BNH.BNH_CRM_Debugging.Managers.CRMManager]::QueryCRM($webFormQuery)

    If ($matchingWebForms.Entities.Count -eq 0)
    {
        $warningMessage = "Could not locate the web form '$webFormName'"
        
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
    $updatedWebFormStepName = ""
    $contentDeployed = UpdateWebForm $itemRelativePath $matchingWebForms.Entities[0] $useProvidedItemContent $itemContent ([ref] $updatePerformed) ([ref] $updatedWebFormStepName)

    If ($updatePerformed)
    {
        WriteInfo "Updated web form step '$updatedWebFormStepName' ($webFormName)"
    }
    return $contentDeployed
}

##$itemContentToDeploy: If this is null, then content will be read from $itemRelativePath. This is typically passed when 
##this function is invoked to deploy a custom link item.
Function UpdateWebForm([string] $itemRelativePath, [Microsoft.Xrm.Sdk.Entity] $webFormRecordToUpdate, [bool] $useProvidedItemContent, [string] $itemContent, [ref][bool] $updatePerformed, [ref][bool] $updatedWebFormStepName)
{
    If ($useProvidedItemContent)
    {
        $contentToDeploy = $itemContent
    }
    Else
    {
        $contentToDeploy = GetItemContent $itemRelativePath
    }

    $webFormName = $webFormRecordToUpdate["adx_name"]
    $webFormStepName = GetWebFormStepNameFromItemRelativePath $itemRelativePath

    $webFormStepNamesToQuery = New-Object System.Collections.Generic.List[string]
    $webFormStepNamesToQuery.Add($webFormStepName)

    $webFormStepQuery = [BNH.BNH_CRM_Debugging.Managers.CRMManager]::GetQueryForWebFormSteps($webFormStepNamesToQuery, $webFormName)
    $matchingWebFormSteps = [BNH.BNH_CRM_Debugging.Managers.CRMManager]::QueryCRM($webFormStepQuery)

    If ($matchingWebFormSteps.Entities.Count -eq 0)
    {
        WriteWarning "Could not locate the web form step '$webFormStepName' for the web form '$webFormName'. The item '$itemRelativePath' will not be deployed."
        return $contentToDeploy
    }
    
    $webFormStepRecordToUpdate = $matchingWebFormSteps.Entities[0]

    $fileName = [IO.Path]::GetFileName($itemRelativePath)
    $itemExtension = [BNH.BNH_CRM_Debugging.Managers.FileNameInfoProvider]::ResolveFileExtension($fileName)
    
    $updateEntity = New-Object Microsoft.Xrm.Sdk.Entity -ArgumentList $webFormStepRecordToUpdate.LogicalName, $webFormStepRecordToUpdate.Id

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
        $updatedWebFormStepName.Value = $webFormStepName
    }
    return $contentToDeploy
}

Function GetWebFormNameFromItemRelativePath([string] $itemRelativePath)
{
    return GetImmediateParentFolderName $itemRelativePath
}

Function GetWebFormStepNameFromItemRelativePath([string] $itemRelativePath)
{
    $fileName = [IO.Path]::GetFileName($itemRelativePath)
    return [BNH.BNH_CRM_Debugging.Managers.FileNameInfoProvider]::ResolveFileNameWithoutExtension($fileName)
}