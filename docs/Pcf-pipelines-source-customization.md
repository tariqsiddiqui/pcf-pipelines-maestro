![PCF Pipelines Maestro](https://github.com/pivotalservices/pcf-pipelines-maestro/raw/master/common/images/maestro_combined_icon.png)

## Customize the source of the *pcf-pipelines* project

Maestro can customize all pipelines to retrieve the `pcf-pipelines` project's files from a location other than the default `git` repository. It also provides an option to determine which `pcf-pipelines` release version to use.

---
### How it is done

The **pcf-pipelines source** customization is global, which means that all upgrade pipelines across all foundations teams in Concourse will be updated to retrieve the `pcf-pipelines` project files from the same specified repository.

To change it:

1. edit the main configuration file `./common/credentials.yml`  

1. In *SECTION B*, set parameter `pcf-pipelines-source` to one of the following accepted values:  

   - `git` : default, the *pcf-pipelines* files are retrieved from the repository defined by property _pcf_pipelines_project_url_ in *SECTION A* of the same config file.  

   - `pivnet` - *pcf-pipelines* release is downloaded from the Pivotal Network repository). Make sure that the account for the provided *pivnet_token* in the same configuration file has been granted access to the *pcf-pipelines* package.   

1. In *SECTION C*, set parameter `pcf-pipelines-release-or-tag` with the desired version of *pcf-pipelines* release to use. For the `git` option only, this parameter can be commented out in order for the *master* branch of *pcf-pipelines* repository to be used.    

1. Save all updated files, commit changes to the Maestro git repository and re-run the Maestro pipeline to update all pipelines.  

---
### [Back to main README](../README.md)
