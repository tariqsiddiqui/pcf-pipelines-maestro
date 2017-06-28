![PCF Pipelines Maestro](https://github.com/pivotalservices/pcf-pipelines-maestro/raw/master/common/images/maestro_combined_icon.png)

## Customize the source of Pivotal product releases

========

The source of Pivotal product releases can be updated in all *pcf-pipelines* with the *pivotal-releases-source* customization option in Maestro.

By default, Pivotal releases are retrieved straight from the Pivotal Network repository (PivNet), but in some cases, customer networks do not have access to the internet or PivNet access is not white-listed in firewall rules. For those cases, retrieving the Pivotal releases from another files repository, such as an S3 bucket, becomes necessary.

---
### How it is done

The **Pivotal releases source** customization is global, which means that all upgrade pipelines across all foundations teams in Concourse will be updated to retrieve Pivotal releases files from the same specified repository.

To change it:

1. edit the main configuration file `./common/credentials.yml`  

1. In *SECTION B*, set parameter `pivotal-releases-source` to one of the following accepted values:  

   - `pivnet` : default, all Pivotal releases are retrieved from the network.pivotal.io using the account setup with the *pivnet_token* parameter in *SECTION A* of the same config file.  

   - `s3` - *pcf-pipelines* downloaded Pivotal releases from a S3-compatible repository (e,g, AWS S3, Minio). S3 account parameters in *SECTION C* of the same config file are required to be provided. For this option, a *Pivnet-to-S3-bucket* pipeline is automatically created to populate the S3 repository with the required Pivotal releases files. For more details, see the [S3 customization option page](./S3-Pivotal-Releases.md).   

1. Save all updated files, commit changes to the Maestro git repository and re-run the Maestro pipeline to update all pipelines.  

---
### [Back to main README](../README.md)
