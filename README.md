# crmquickdeploy.powershell
The Powershell version of CRMQuickDeploy (https://bernado-nguyen-hoan.com/2014/12/22/bnh-crm-debugging/). Watches for changes to local files and deploy to Dynamics/PowerApps Portal.

This script only works with Dynamics/PowerApps Portal artefacts, including JS, HTML, CSS and Liquid for web pages, web templates, entity forms, entity lists, web forms and web files.

You specify a folder to watch when launching the script. The structure for this folder should be as described at https://bernado-nguyen-hoan.com/2017/08/17/source-control-adxstudiocrm-portal-js-css-and-liquid-with-crmquickdeploy/, and is summarised below.

Connection string to CRM is defined in a file, namely **crmquickdeploy.powershell.config**, which should also be located at the folder being watched by the script. This file is described in more details below.

# Configuration file 
The script requires a configuration file, namely **crmquickdeploy.powershell.config** to be located at the folder being watched. The content of this file should be as followed:

```
{
   "CRMConnectionString":"url=https://yourInstance.crm6.dynamics.com;AuthType=OAuth;AppId=51f81489-12ee-4a9e-aaae-a2591f45987d;RedirectUri=app://58145B91-0C36-4500-8554-080854F2AC97",
   "IsPortalv7":"false",
   "PortalWebsiteName":"Custom Portal",
   "UseFolderAsWebPageLanguage": "true"
}
```

`CRMConnectionString`: Connection string used to connect to CRM. Refer to this post for examples of supported connection strings: https://bernado-nguyen-hoan.com/2021/02/26/crmquickdeploy-now-supports-clientid-secret-and-mfa/.

`IsPortalv7`: 

`PortalWebsiteName`:

`UseFolderAsWebPageLanguage`:

# User configuration file
You can optionally create a user-specific configuration file, namely **crmquickdeploy.powershell.user.config**. This file has the same schema as the configuration file above, and any value specified in this file will override the corresponding value in the main configuration file.

A use case for this file is where your dev team has a dedicated sandbox CRM instance for each developer. You can have the main configuration file points to the main dev/integration CRM instance and check this into source-control. Each developer can then create their own user configuration file to override the CRM connection string, and exclude this user configuration file from source-control.
