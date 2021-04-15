Function DeployWebTemplate([string] $itemRelativePath)
{
    Try
    {
        WriteInfo "Deploying '$itemRelativePath'" "DarkGray"

        $webTemplateName = GetWebTemplateNameFromItemRelativePath $itemRelativePath
    
        $webTemplateNamesToQuery = New-Object System.Collections.Generic.List[string]
        $webTemplateNamesToQuery.Add($webTemplateName)

        If ($Script:_config.IsPortalv7)
        {
            $websiteNameForQuery = $null
        }
        Else
        {
            $websiteNameForQuery = $Script:_config.PortalWebsiteName
        }

        $webTemplateQuery = [BNH.BNH_CRM_Debugging.Managers.CRMManager]::GetQueryForWebTemplates($webTemplateNamesToQuery, $websiteNameForQuery)
        $matchingWebTemplates = [BNH.BNH_CRM_Debugging.Managers.CRMManager]::QueryCRM($webTemplateQuery)

        If ($matchingWebTemplates.Entities.Count -eq 0)
        {
            CreateWebTemplate $webTemplateName $itemRelativePath
            WriteInfo "Created web template '$webTemplateName'"
        }
        Else
        {
            UpdateWebTemplate $itemRelativePath $matchingWebTemplates.Entities[0]
            WriteInfo "Updated web template '$webTemplateName'"
        }
    }
    Catch
    {
        WriteError "An error has occurred while deploying the web template '$itemRelativePath': $_`n`n$($_.ScriptStackTrace)"
    }
}

Function CreateWebTemplate([string] $webTemplateName, [string] $itemRelativePath)
{
    $templateSource = GetItemContent $itemRelativePath

    If ($Script:_config.IsPortalv7)
    {
        $Script:_crmManager.CreateWebTemplate($webTemplateName, $templateSource, $null)        
    }
    Else
    {
        $Script:_crmManager.CreateWebTemplate($webTemplateName, $templateSource, $Script:_targetWebsite.Id)
    }
}

Function UpdateWebTemplate([string] $itemRelativePath, [Microsoft.Xrm.Sdk.Entity] $webTemplateRecordToUpdate)
{
    $templateSource = GetItemContent $itemRelativePath
    $Script:_crmManager.UpdateWebTemplate($webTemplateRecordToUpdate.Id, $templateSource)
}

Function GetWebTemplateNameFromItemRelativePath([string] $itemRelativePath)
{
    return [IO.Path]::GetFileNameWithoutExtension($itemRelativePath)
}