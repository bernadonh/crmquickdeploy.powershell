param 
(
	##Default to current folder if not specified. Should not end with '\'.
	[string] $FolderToWatch
)

Function GetPathToWatch()
{
    If ([string]::IsNullOrEmpty($FolderToWatch))
    {
        return $pwd
    }
    Else
    {
        return $FolderToWatch
    }
}

Function GetConfigurationAndAssertValid([string] $configurationFileName, [string] $userConfigurationFileName)
{
    If (![IO.File]::Exists($configurationFileName))
    {
        throw "The configuration file '$configurationFileName' was not found."
    }
    
    Try
    {
        $config = Get-Content -Raw -Path $configurationFileName | ConvertFrom-Json
    }
    Catch
    {
        WriteError "An error has occurred while reading the configuration file '$configurationFileName'. Please check that this file is valid."
        throw $_
    }

    ##Merge with user config file if exists
    If ([IO.File]::Exists($userConfigurationFileName))
    {
        Try
        {
            $userConfig = Get-Content -Raw -Path $userConfigurationFileName | ConvertFrom-Json
            
            If (-not [string]::IsNullOrEmpty($userConfig.CRMConnectionString))
            {
                $config.CRMConnectionString = $userConfig.CRMConnectionString
            }
            If (-not [string]::IsNullOrEmpty($userConfig.IsPortalv7))
            {
                $config.IsPortalv7 = $userConfig.IsPortalv7
            }
            If (-not [string]::IsNullOrEmpty($userConfig.PortalWebsiteName))
            {
                $config.PortalWebsiteName = $userConfig.PortalWebsiteName
            }
            If (-not [string]::IsNullOrEmpty($userConfig.UseFolderAsWebPageLanguage))
            {
                $config.UseFolderAsWebPageLanguage = $userConfig.UseFolderAsWebPageLanguage
            }
        }
        Catch
        {
            WriteError "An error has occurred while reading the user configuration file '$userConfigurationFileName'. Please check that this file is valid."
            throw $_
        }
    }    
    
    If ([string]::IsNullOrEmpty($config.CRMConnectionString))
    {
        throw "'CRMConnectionString' property must be specified in configuration file."
    }
    If ([string]::IsNullOrEmpty($config.IsPortalv7) -or ($config.IsPortalv7 -ne "true" -and $config.IsPortalv7 -ne "false"))
    {
        throw "'IsPortalv7' property must be specified and must be 'true' or 'false'."
    }
    If ([string]::IsNullOrEmpty($config.PortalWebsiteName))
    {
        throw "'PortalWebsiteName' property must be specified."
    }
    If ([string]::IsNullOrEmpty($config.UseFolderAsWebPageLanguage) -or ($config.UseFolderAsWebPageLanguage -ne "true" -and $config.UseFolderAsWebPageLanguage -ne "false"))
    {
        throw "'UseFolderAsWebPageLanguage' property must be specified and must be 'true' or 'false'."
    }
    
    $config.IsPortalv7 = [Convert]::ToBoolean($config.IsPortalv7)

    return $config
}

Function InitialiseCrmManager([string] $connectionString)
{
    ##Enable TLS 1.2 if it is not enabled: https://www.codevanguard.com/crm-service-client-powershell/.
    If (-not [Net.ServicePointManager]::SecurityProtocol.HasFlag([Net.SecurityProtocolType]::Tls12))
    {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12;
    }

    WriteInfo "Initialising connection to '$connectionString'"
    
    $initialisationCallback = {
        param($cancelledByUser, $crmManager)
        
        $Script:_initialisationCancelledByUser = $cancelledByUser        
        $Script:_crmManager = $crmManager
    }

    [BNH.CRMQuickDeploy.Core.Managers.CRMManager]::BeginInitialise($connectionString, $initialisationCallback)
}

Function GetWebsiteAndAssertFound([string] $websiteName)
{
    WriteInfo "Retrieving the website '$websiteName' from CRM"

    $websiteQuery = [BNH.CRMQuickDeploy.Core.Managers.CRMManager]::GetQueryForPortalWebsite($websiteName)
    $websites = [BNH.CRMQuickDeploy.Core.Managers.CRMManager]::QueryCRM($websiteQuery)

    If ($websites.Entities.Count -eq 0)
    {
        throw "The website '$websiteName' was not found in CRM."
    }

    return $websites.Entities[0]
}

Function GetPublishedPublishingStateAndAssertFound()
{
    WriteInfo "Retrieving the publishing state 'Published' from CRM"

    $publishingStateQuery = [BNH.CRMQuickDeploy.Core.Managers.CRMManager]::GetQueryForPublishingState("Published", $Script:_targetWebsite.Id)
    $states = [BNH.CRMQuickDeploy.Core.Managers.CRMManager]::QueryCRM($publishingStateQuery)

    If ($states.Entities.Count -eq 0)
    {
        throw "The publishing state 'Published' was not found in CRM."
    }

    return $states.Entities[0]
}

Function TryGetConfiguredWebsite()
{
    $websiteQuery = [BNH.CRMQuickDeploy.Core.Managers.CRMManager]::GetQueryForPortalWebsite($Script:_config.PortalWebsiteName)
    $websites = [BNH.CRMQuickDeploy.Core.Managers.CRMManager]::QueryCRM($websiteQuery)

    If ($websites.Entities.Count -eq 0)
    {
        return $null
    }
    Else
    {
        return $websites.Entities[0]
    }
}

Function HandleChangedEvent([EventArgs] $eventArgs)
{
    $itemLastEventTime = $Script:_itemLastEventTimeMap[$eventArgs.SourceArgs.Name]
    
    ##Ignore duplicate events, which maybe fired by the watcher.
    If ($itemLastEventTime -ne $null)
    {
        If ($eventArgs.TimeGenerated.Ticks - $itemLastEventTime -lt 1000000)
        {
            return
        }
    }
    
    $Script:_itemLastEventTimeMap[$eventArgs.SourceArgs.Name] = $eventArgs.TimeGenerated.Ticks

    If (IsWebTemplateItem $eventArgs.SourceArgs.Name)
    {
        DeployWebTemplate $eventArgs.SourceArgs.Name
    }
    ElseIf (IsWebFileDeploymentSettingsFile $eventArgs.SourceArgs.Name)
    {
        MarkWebFileDeploymentSettingsFileForRefresh
    }
    ElseIf (IsWebFileItem $eventArgs.SourceArgs.Name)
    {
        DeployWebFile $eventArgs.SourceArgs.Name
    }
    ElseIf (IsLinkItem $eventArgs.SourceArgs.Name)
    {
        WriteInfo "Changes to link item '$($eventArgs.SourceArgs.Name)' detected. The target record in CRM for this link item will not be updated until a deployment is triggered for the referenced source item." "Cyan"
    }
    ElseIf (IsWebPageItem $eventArgs.SourceArgs.Name)
    {
        DeployWebPageAndReferencingLinkItems $eventArgs.SourceArgs.Name
    }
    ElseIf (IsEntityFormItem $eventArgs.SourceArgs.Name)
    {
        DeployEntityFormAndReferencingLinkItems $eventArgs.SourceArgs.Name
    }
    ElseIf (IsEntityListItem $eventArgs.SourceArgs.Name)
    {
        DeployEntityList $eventArgs.SourceArgs.Name
    }
    ElseIf (IsWebFormItem $eventArgs.SourceArgs.Name)
    {
        DeployWebFormAndReferencingLinkItems $eventArgs.SourceArgs.Name
    }
    ElseIf (IsContentSnippetItem $eventArgs.SourceArgs.Name)
    {
        DeployContentSnippet $eventArgs.SourceArgs.Name
    }
}

##itemRelativePath: Path of item relative to $Script:_pathToWatch.
Function IsFile([string] $itemRelativePath)
{
    $itemAbsolutePath = "$Script:_pathToWatch\$itemRelativePath"
    $item = Get-Item $itemAbsolutePath

    If ($item.PSIsContainer -eq $true)
    {
        return $false
    }
    Else
    {
        return $true
    }
} 

##itemRelativePath: Path of item relative to $Script:_pathToWatch.
Function IsLinkItem([string] $itemRelativePath)
{
    If ($itemRelativePath.StartsWith("$Script:_webPageFolderName\", [StringComparison]::OrdinalIgnoreCase) `
        -or $itemRelativePath.StartsWith("$Script:_entityFormFolderName\", [StringComparison]::OrdinalIgnoreCase) `
        -or $itemRelativePath.StartsWith("$Script:_webFormFolderName\", [StringComparison]::OrdinalIgnoreCase))
    {
        $itemExtension = [IO.Path]::GetExtension($itemRelativePath).ToLower()
        
        If ($itemExtension -eq ".link")
        {
            return $true
        }
    }
    return $false
}

##itemRelativePath: Path of item relative to $Script:_pathToWatch.
Function IsWebFormItem([string] $itemRelativePath)
{
    If ($itemRelativePath.StartsWith("$Script:_webFormFolderName\", [StringComparison]::OrdinalIgnoreCase))
    {
        $itemExtension = [IO.Path]::GetExtension($itemRelativePath).ToLower()
        
        If ($itemExtension -eq ".js")
        {
            return $true
        }
    }
    return $false
}

##itemRelativePath: Path of item relative to $Script:_pathToWatch.
Function IsEntityFormItem([string] $itemRelativePath)
{
    If ($itemRelativePath.StartsWith("$Script:_entityFormFolderName\", [StringComparison]::OrdinalIgnoreCase))
    {
        $itemExtension = [IO.Path]::GetExtension($itemRelativePath).ToLower()
        
        If ($itemExtension -eq ".js")
        {
            return $true
        }
    }
    return $false
}

##itemRelativePath: Path of item relative to $Script:_pathToWatch.
Function IsEntityListItem([string] $itemRelativePath)
{
    If ($itemRelativePath.StartsWith("$Script:_entityListFolderName\", [StringComparison]::OrdinalIgnoreCase))
    {
        $itemExtension = [IO.Path]::GetExtension($itemRelativePath).ToLower()
        
        If ($itemExtension -eq ".js")
        {
            return $true
        }
    }
    return $false
}

##itemRelativePath: Path of item relative to $Script:_pathToWatch.
Function IsWebPageItem([string] $itemRelativePath)
{
    If ($itemRelativePath.StartsWith("$Script:_webPageFolderName\", [StringComparison]::OrdinalIgnoreCase))
    {
        $itemExtension = [IO.Path]::GetExtension($itemRelativePath).ToLower()
        
        If ($itemExtension -eq ".htm" -or $itemExtension -eq ".html" -or $itemExtension -eq ".js" -or $itemExtension -eq ".css")
        {
            return $true
        }
    }
    return $false
}

##itemRelativePath: Path of item relative to $Script:_pathToWatch.
Function IsWebFileItem([string] $itemRelativePath)
{
    If ($itemRelativePath.StartsWith("$Script:_webFileFolderName\", [StringComparison]::OrdinalIgnoreCase))
    {
        return IsFile $itemRelativePath
    }

    return $false
}

##itemRelativePath: Path of item relative to $Script:_pathToWatch.
Function IsWebFileDeploymentSettingsFile([string] $itemRelativePath)
{
    If ($itemRelativePath.Equals("$Script:_webFileFolderName\$Script:_webFileDeploymentSettingsFileName", [StringComparison]::OrdinalIgnoreCase))
    {
        return $true
    }
    return $false
}

##itemRelativePath: Path of item relative to $Script:_pathToWatch.
Function IsWebTemplateItem([string] $itemRelativePath)
{
    If ($itemRelativePath.StartsWith("$Script:_webTemplateFolderName\", [StringComparison]::OrdinalIgnoreCase))
    {
        $itemExtension = [IO.Path]::GetExtension($itemRelativePath).ToLower()
        
        If ($itemExtension -eq ".htm" -or $itemExtension -eq ".html")
        {
            return $true
        }
    }
    return $false   
}

##itemRelativePath: Path of item relative to $Script:_pathToWatch.
Function IsContentSnippetItem([string] $itemRelativePath)
{
    If ($itemRelativePath.StartsWith("$Script:_contentSnippetFolderName\", [StringComparison]::OrdinalIgnoreCase))
    {
        $itemExtension = [IO.Path]::GetExtension($itemRelativePath).ToLower()
        
        If ($itemExtension -eq ".html" -or $itemExtension -eq ".txt")
        {
            return $true
        }
    }
    return $false   
}

Function SetupWatcher([string] $path)
{
    ##https://powershell.one/tricks/filesystem/filesystemwatcher
    $watcher = New-Object IO.FileSystemWatcher -ArgumentList $path, "*"
    $watcher.IncludeSubdirectories = $true
    $watcher.NotifyFilter = [IO.NotifyFilters]::LastWrite

    Try
    {
        $onChangedAction = {
            HandleChangedEvent $event
        }

        $watcherEventHandlers = . {
            Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $onChangedAction 
        }

        WriteInfo "Watching folder '$path'" "green"

        $watcher.EnableRaisingEvents = $true
        
        Do
        {
            Wait-Event -Timeout 1
        } While ($true)
    }
    Finally
    {
        $watcher.EnableRaisingEvents = $false
  
        $watcherEventHandlers | % { Unregister-Event -SourceIdentifier $_.Name }
        $handlers | Remove-Job  
        $watcher.Dispose()
    }
}

Function ConfigureProxySettings()
{
    [Net.WebRequest]::DefaultWebProxy.Credentials = [Net.CredentialCache]::DefaultNetworkCredentials
}

Function LoadAssemblies()
{
    [Reflection.Assembly]::LoadFrom("$PSScriptRoot\Assemblies\Microsoft.Xrm.Tooling.Connector.dll") | Out-Null
    [Reflection.Assembly]::LoadFrom("$PSScriptRoot\Assemblies\Microsoft.Xrm.Sdk.dll") | Out-Null
    [Reflection.Assembly]::LoadFrom("$PSScriptRoot\Assemblies\Microsoft.Crm.Sdk.Proxy.dll") | Out-Null
    [Reflection.Assembly]::LoadFrom("$PSScriptRoot\Assemblies\Microsoft.Xrm.Sdk.Deployment.dll") | Out-Null
    [Reflection.Assembly]::LoadFrom("$PSScriptRoot\Assemblies\Microsoft.IdentityModel.Clients.ActiveDirectory.dll") | Out-Null
    [Reflection.Assembly]::LoadFrom("$PSScriptRoot\Assemblies\BNH.CRMQuickDeploy.Core.dll") | Out-Null
}

Function WriteInfo([string] $message, [string] $foregroundColor = "white")
{
    Write-Host "$([DateTime]::Now.ToShortTimeString()): $message" -ForegroundColor $foregroundColor
}

Function WriteError([string] $message)
{
    Write-Host "$([DateTime]::Now.ToShortTimeString()): $message" -ForegroundColor Red
}

Function WriteWarning([string] $message)
{
    Write-Host "$([DateTime]::Now.ToShortTimeString()): $message" -ForegroundColor Yellow
}

<###
    Not supported:
        + Automatic cache refresh
###>

###Main
$ErrorActionPreference = "Stop"

##Add the include scripts
. $PSScriptRoot\Utils.ps1
. $PSScriptRoot\WebTemplate.ps1
. $PSScriptRoot\WebFile.ps1
. $PSScriptRoot\WebPage.ps1
. $PSScriptRoot\EntityForm.ps1
. $PSScriptRoot\EntityList.ps1
. $PSScriptRoot\WebForm.ps1
. $PSScriptRoot\ContentSnippet.ps1

##Map that tracks the time (in ticks) an event was last handled for an item. This is used to skip duplicate
##events that may be fired by the watcher.
$Script:_itemLastEventTimeMap = @{}

$Script:_webTemplateFolderName = "PortalWebTemplates"
$Script:_webFileFolderName = "PortalWebFiles"
$Script:_webPageFolderName = "PortalWebPages"
$Script:_entityFormFolderName = "PortalEntityForms"
$Script:_entityListFolderName = "PortalEntityLists"
$Script:_webFormFolderName = "PortalWebForms"
$Script:_contentSnippetFolderName = "PortalContentSnippets"

$Script:_webFileDeploymentSettingsFileName = "DeploymentSettings.xml"

$Script:_pathToWatch = GetPathToWatch

$Script:_initialisationCancelledByUser = $null
$Script:_crmManager = $null
$Script:_targetWebsite = $null
$Script:_publishedPublishingState = $null

$Script:_version = "v1.2"

Write-Host "`n---------- CRMQuickDeploy Powershell ($Script:_version)----------"

ConfigureProxySettings
LoadAssemblies
$Script:_config = GetConfigurationAndAssertValid "$Script:_pathToWatch\crmquickdeploy.powershell.config" "$Script:_pathToWatch\crmquickdeploy.powershell.user.config"
InitialiseCrmManager $Script:_config.CRMConnectionString

##Wait until we have result from the initialisation step
Do
{
    Start-Sleep -Milliseconds 500
} While ($Script:_initialisationCancelledByUser -eq $null)

Try
{
    If ($Script:_initialisationCancelledByUser)
    {
        WriteInfo "Cancelled by user"
        exit
        
    }

    $Script:_targetWebsite = GetWebsiteAndAssertFound $Script:_config.PortalWebsiteName
    $Script:_publishedPublishingState = GetPublishedPublishingStateAndAssertFound

    SetupWatcher $Script:_pathToWatch
}
Finally
{
    If ($Script:_crmManager -ne $null)
    {
        $Script:_crmManager.Dispose()
    }

    [BNH.CRMQuickDeploy.Core.Managers.WebFileDeploymentSettingManager]::ClearCache()
}