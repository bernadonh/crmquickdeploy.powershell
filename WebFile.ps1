Function MarkWebFileDeploymentSettingsFileForRefresh()
{
    [BNH.CRMQuickDeploy.Core.Managers.WebFileDeploymentSettingManager]::ClearCache()
    WriteInfo "Invalidated the web file deployment settings cache" "Cyan"
}

Function DeployWebFile([string] $itemRelativePath)
{
    Try
    {
        WriteInfo "Deploying '$itemRelativePath'" "DarkGray"

        $deploymentSettings = [BNH.CRMQuickDeploy.Core.Managers.WebFileDeploymentSettingManager]::GetDeploymentSettingsForFolder("$Script:_pathToWatch\$Script:_webFileFolderName")

        If ($deploymentSettings -eq $null)
        {
            WriteWarning "Could not deploy web file '$itemRelativePath' as the file '$Script:_pathToWatch\$Script:_webFileFolderName\$Script:_webFileDeploymentSettingsFileName' could not be found.`n`nPlease see 'https://bernado-nguyen-hoan.com/2017/08/17/source-control-adxstudiocrm-portal-js-css-and-liquid-with-crmquickdeploy' for how to create this file."
            return
        }
        
        $itemValidationErrorMessage = $null
		$itemDeploymentSettings = $deploymentSettings.GetDeploymentSettingsForFileAndAssertValid($itemRelativePath, [ref] $itemValidationErrorMessage);

        If ($itemDeploymentSettings -eq $null)
        {
            If ([string]::IsNullOrEmpty($itemValidationErrorMessage))
            {
                WriteWarning "Unable to deploy the file '$itemRelativePath' as it is not defined in the deployment settings configuration file."
            }
			Else
			{
			    WriteError "A configuration validation error has occurred for the file '$itemRelativePath': $itemValidationErrorMessage This item will not be deployed."
            }
            return
        }
                
        $parentWebPageNamesToQuery = New-Object System.Collections.Generic.List[string]
        $parentWebPageNamesToQuery.Add($itemDeploymentSettings.ParentPage)

        $parentWebPageQuery = [BNH.CRMQuickDeploy.Core.Managers.CRMManager]::GetQueryForWebPages($parentWebPageNamesToQuery, $Script:_targetWebsite.Id, $Script:_config.IsPortalv7)
        $matchingParentWebPages = [BNH.CRMQuickDeploy.Core.Managers.CRMManager]::QueryCRM($parentWebPageQuery)

        If ($matchingParentWebPages.Entities.Count -eq 0)
        {
            WriteWarning "The specified parent web page '$($itemDeploymentSettings.ParentPage)' for the web file '$itemRelativePath' could not be found under the portal website '$($Script:_targetWebsite.Name)'. This item will not be deployed."
            return
        }

        $itemDeploymentSettings.ParentPageId = $matchingParentWebPages.Entities[0].Id

        $webFileNamesToQuery = New-Object System.Collections.Generic.List[string]
        $webFileNamesToQuery.Add($itemDeploymentSettings.TargetName)

        $webFileQuery = [BNH.CRMQuickDeploy.Core.Managers.CRMManager]::GetQueryForWebFiles($webFileNamesToQuery, $Script:_targetWebsite.Id)
        $matchingWebFiles = [BNH.CRMQuickDeploy.Core.Managers.CRMManager]::QueryCRM($webFileQuery)

        $itemDeploymentSettings.PublishingStateId = $Script:_publishedPublishingState.Id

        $itemFileName = [IO.Path]::GetFileName($itemRelativePath)
        If ([BNH.CRMQuickDeploy.Core.Managers.FileNameInfoProvider]::IsCompilableItem($itemFileName))
        {
            $itemDeploymentSettings.LocalFileName = [BNH.CRMQuickDeploy.Core.Managers.FileNameInfoProvider]::GetCompilableOutputFileName($itemFileName)
        }
        Else
        {
            $itemDeploymentSettings.LocalFileName = $itemFileName
        }
                
        If ($matchingWebFiles.Entities.Count -eq 0)
        {
            CreateWebFile $itemRelativePath $itemDeploymentSettings            
        }
        Else
        {
            UpdateWebFile $itemRelativePath $itemDeploymentSettings $matchingWebFiles.Entities[0]
        }
    }
    Catch
    {
        WriteError "An error has occurred while deploying the web file '$itemRelativePath': $_`n`n$($_.ScriptStackTrace)"
    }
}

Function CreateWebFile([string] $itemRelativePath, [BNH.CRMQuickDeploy.Core.Model.WebFileItemDeploymentSettings] $itemDeploymentSettings)
{
    $webFileSource = GetItemContent $itemRelativePath

    $Script:_crmManager.CreateWebFile($itemDeploymentSettings, $Script:_targetWebsite.Id, $webFileSource)
    WriteInfo "Created web file '$($itemDeploymentSettings.TargetName)'"
}

Function UpdateWebFile([string] $itemRelativePath, [BNH.CRMQuickDeploy.Core.Model.WebFileItemDeploymentSettings] $itemDeploymentSettings, [Microsoft.Xrm.Sdk.Entity] $webFileRecordToUpdate)
{
    $webFileSource = GetItemContent $itemRelativePath

    $Script:_crmManager.UpdateWebFile($webFileRecordToUpdate.Id, $itemDeploymentSettings, $webFileSource)
    WriteInfo "Updated web file '$($itemDeploymentSettings.TargetName)'"
}