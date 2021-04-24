# crmquickdeploy.powershell
The Powershell version of CRMQuickDeploy (https://bernado-nguyen-hoan.com/2014/12/22/bnh-crm-debugging/). Watches for changes to local files and deploy to Dynamics/PowerApps Portal.

This script only works with Dynamics/PowerApps Portal artefacts, including JS, HTML, CSS and Liquid for Web Pages, Web Templates, Entity Forms, Entity Lists, Web Forms and Web Files.

You specify a folder to watch when launching the script. You must structure this folder and its contents in a certain way so that the script can recognise the types of artefacts and how to map them to records in CRM. This is described in depth at https://bernado-nguyen-hoan.com/2017/08/17/source-control-adxstudiocrm-portal-js-css-and-liquid-with-crmquickdeploy/ and is also summarised below.

Connection string to CRM is defined in a file, namely **crmquickdeploy.powershell.config**, which should also be located at the folder being watched by the script. This file is described in more details below.

# Configuration file 
The script requires a configuration file, namely **crmquickdeploy.powershell.config**, to be located at the folder being watched. The content of this file should be as followed:

```
{
   "CRMConnectionString":"url=https://yourInstance.crm6.dynamics.com;AuthType=OAuth;AppId=51f81489-12ee-4a9e-aaae-a2591f45987d;RedirectUri=app://58145B91-0C36-4500-8554-080854F2AC97",
   "IsPortalv7":"false",
   "PortalWebsiteName":"Custom Portal",
   "UseFolderAsWebPageLanguage": "true"
}
```

`CRMConnectionString`: Connection string used to connect to CRM. Refer to this post for examples of supported connection strings: https://bernado-nguyen-hoan.com/2021/02/26/crmquickdeploy-now-supports-clientid-secret-and-mfa/.

`IsPortalv7`: Specify whether your target portal is version 7. If you are targeting Dynamics/PowerApps Portal on cloud, then specify `false`.

`PortalWebsiteName`: Specify the name of the Website record in CRM that represents your target portal.

`UseFolderAsWebPageLanguage`: Specify whether subfolders under the `PortalWebPages` folder are used to determine the language of target Web Pages. Refer to this post for more details: https://bernado-nguyen-hoan.com/2018/08/08/better-support-for-localised-portal-web-pages-in-new-version-of-crmquickdeploy/. Recommended value is `true`.

# User configuration file
You can optionally create a user-specific configuration file, namely **crmquickdeploy.powershell.user.config**. This file has the same schema as the configuration file above, and any value specified in this file will override the corresponding value in the main configuration file.

A use case for this file is where your dev team has a dedicated sandbox CRM instance for each developer. You can have the main configuration file points to the main dev/integration CRM instance and check this into source-control. Each developer can then create their own user configuration file to override the CRM connection string, and exclude this user configuration file from source-control.

# Running the script
1. Download the code and unzip. The package contains the main script, supporting scripts and supporting assemblies.
2. Create the folder to watch and create the configuration file as described above.
3. Run the script using the following:

```
. .\crmquickdeploy.ps1 -FolderToWatch "[full path to folder to watch]"
```
**IMPORTANT**: You must launch the script using the `.` syntax as above.

# Organising your watch folder
Contents under the folder being watched must be organised in a certain way so that the script can recognise the type of artefacts being deployed and their corresponding target records in CRM. This is described in depth in this post: https://bernado-nguyen-hoan.com/2017/08/17/source-control-adxstudiocrm-portal-js-css-and-liquid-with-crmquickdeploy/, and below is a summary.

1. Files should be placed in subfolders underneath the folder being watched. These subfolders represent the target entity types (e.g. Entity Form, Entity List, Web Page, etc.) in CRM. Name these subfolders as follow:
    1. `PortalWebPages`
    2. `PortalWebTemplates`
    3. `PortalEntityForms`
    4. `PortalEntityLists`
    5. `PortalWebForms`
    6. `PortalWebFiles`
2. Web Forms require additional subfolders underneath the `PortalWebForms` folder. Refer to the post above for more details.
3. With exception of Web Files, the file name of a file identifies the name of the target record in CRM. The file extension identifies the 'part' of that record to update (.js for JavaScript, .css for CSS, .html for Liquid/HTML).
4. Web Files require an additional config file, namely **DeploymentSettings.xml**, to be placed in the `PortalWebFiles` folder.

# Other features
## Link items
Link items, i.e. sharing code between two or more files, are supported. Refer to this post for more details: https://bernado-nguyen-hoan.com/2017/12/12/reduce-code-duplication-between-insert-edit-forms-in-crm-portal-with-crmquickdeploy/.

# Notes
Web Files are uploaded to CRM as attachments to Notes. CRM blocks .js files by default. Don't forget to remove this restriction.
