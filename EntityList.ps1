Function DeployEntityList([string] $itemRelativePath)
{
    Try
    {
        WriteInfo "Deploying '$itemRelativePath'" "DarkGray"

        $entityListName = GetEntityListNameFromItemRelativePath $itemRelativePath
    
        $entityListNamesToQuery = New-Object System.Collections.Generic.List[string]
        $entityListNamesToQuery.Add($entityListName)
    
        If ($Script:_config.IsPortalv7)
        {
            $websiteNameForQuery = $null
        }
        Else
        {
            $websiteNameForQuery = $Script:_config.PortalWebsiteName
        }

        $entityListQuery = [BNH.BNH_CRM_Debugging.Managers.CRMManager]::GetQueryForEntityLists($entityListNamesToQuery, $websiteNameForQuery)
        $matchingEntityLists = [BNH.BNH_CRM_Debugging.Managers.CRMManager]::QueryCRM($entityListQuery)

        If ($matchingEntityLists.Entities.Count -eq 0)
        {
            $warningMessage = "Could not locate the entity list '$entityListName'"
        
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
        UpdateEntityList $itemRelativePath $matchingEntityLists.Entities[0] ([ref] $updatePerformed)

        If ($updatePerformed)
        {
            WriteInfo "Updated entity list '$entityListName'"        
        }
    }
    Catch
    {
        WriteError "An error has occurred while deploying the entity list '$itemRelativePath': $_`n`n$($_.ScriptStackTrace)"
    }
}

Function UpdateEntityList([string] $itemRelativePath, [Microsoft.Xrm.Sdk.Entity] $entityListRecordToUpdate, [ref][bool] $updatePerformed)
{
    $fileName = [IO.Path]::GetFileName($itemRelativePath)
    $itemExtension = [BNH.BNH_CRM_Debugging.Managers.FileNameInfoProvider]::ResolveFileExtension($fileName)
    $contentToDeploy = GetItemContent $itemRelativePath
    
    $updateEntity = New-Object Microsoft.Xrm.Sdk.Entity -ArgumentList $entityListRecordToUpdate.LogicalName, $entityListRecordToUpdate.Id

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
}

Function GetEntityListNameFromItemRelativePath([string] $itemRelativePath)
{
    $fileName = [IO.Path]::GetFileName($itemRelativePath)
    return [BNH.BNH_CRM_Debugging.Managers.FileNameInfoProvider]::ResolveFileNameWithoutExtension($fileName)
}