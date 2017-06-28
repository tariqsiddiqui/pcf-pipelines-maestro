![PCF Pipelines Maestro](https://github.com/pivotalservices/pcf-pipelines-maestro/raw/master/common/images/maestro_combined_icon.png)

## Customizing pipelines to retrieve Pivotal releases from an S3 repository

Maestro provides a customization option to adapt *pcf-pipelines* to retrieve Pivotal releases from an S3-compatible repository (e.g. [AWS S3](https://aws.amazon.com/s3/), [Minio](https://www.minio.io/)).

When that customization rule is applied, all upgrade pipelines will monitor and retrieve Pivotal product release files from the configured S3-compatible repository. Also, a pipeline will be created in the "main" Concourse team to automatically download releases from Pivotal Network and then upload them to the S3 repository.

---
### Customized upgrade pipelines

Once the `S3` customization is applied, all upgrade pipelines across all foundations will be adapted to use the [`S3` resource](https://github.com/concourse/s3-resource) (replacing the default [PivNet resource](https://github.com/pivotal-cf/pivnet-resource)). The S3 resource in each pipeline will monitor and download the corresponding Pivotal product's releases from the S3 repository.


![s3-upgrade-tile-pipeline](https://github.com/pivotalservices/pcf-pipelines-maestro/raw/master/common/images/s3-upgrade-tile-pipeline.png)


The S3 resource will expect a specific structure of folders and release file names in the repository, for example:

```
<s3-bucket-name>/ops-manager/ops-manager_v1.10.1.ova
                             ops-manager_v1.10.2.ova
                             ops-manager_v1.10.1_AWS.yml
                             ops-manager_v1.10.2_AWS.yml
                /elastic-runtime/elastic-runtime_v1.10.1.pivotal
                /elastic-runtime/elastic-runtime_v1.10.2.pivotal
                /mysql/mysql_v1.8.3.pivotal
                ...
```

In order to automatically populate the S3 repository with the appropriate folder and file structure, a **PivNet-to-S3-bucket** pipeline is automatically created in the "main" Concourse team. It is recommended to use such pipeline to upload the Pivotal releases to S3.

---
### The PivNet-to-S3-bucket pipeline

Maestro will scan configuration files to determine all PCF modules in use (e.g. ops-manager, tiles) and the infrastructure-as-a-service (IaaS) instances that foundations are deployed to in order to create a custom `PivNet-to-S3-bucket` pipeline that will download/upload only the release files in use by your upgrade pipelines.


![pivnet-to-s3-bucket-pipeline](https://github.com/pivotalservices/pcf-pipelines-maestro/raw/master/common/images/pivnet-to-s3-bucket-pipeline.png)


When a new tile upgrade pipeline is added to Maestro configuration files, or when a new foundation in a new IaaS is added to Maestro, then the `PivNet-to-S3-bucket` pipeline is updated accordingly, so the releases files for the new tile and the Ops-Manager for the added IaaS are appropriately handled by the pipeline.

---
## How to enable the S3 pipeline customization

The **S3** customization is a global option, which means that all upgrade pipelines across all foundations teams in Concourse will be updated to retrieve Pivotal releases from the S3 repository.

To enable it:

1. edit the main configuration file `./common/credentials.yml`  

1. In `SECTION B`, set parameter `pivotal-releases-source` to `s3`.  

1. In `SECTION C`, update the following required parameters for the [S3 resource](https://github.com/concourse/s3-resource):  

   - `s3-bucket` - the ID of the S3 bucket to upload Pivotal releases to  
   - `s3-access-key-id` - access key of the S3 bucket  
   - `s3-secret-access-key` - secret access key of the S3 bucket  
   - `s3-region-name` - S3 bucket region name. Comment this line if not applicable   
   - `s3-endpoint` - Custom endpoint for S3 compatible provider (e.g. Minio). Comment this line if not applicable  
   - `s3-disable-ssl` - For S3 compatible provider without SSL, disable SSL for the endpoint. Comment this line if not applicable  
   - `s3-use-v2-signing` - Use signature v2 signing, S3 compatible providers that do not support v4. Comment this line if not applicable  
   - `template-foundation-config-file` - the ID of the foundation (under /foundations folder) to be used to generate the `PivNet-To-S3-bucket` pipeline components. e.g. NYC-DEV. This should be the ID of a "test" or "sandbox" foundation, which typically contains a complete list of tiles used by all foundations and a list of tiles version numbers with wildcards ( e.g. 1.10.* )  

1. Save all updated files, commit changes to the Maestro git repository and re-run the Maestro pipeline to update all pipelines.  

---
## How S3 customization is done under-the-hood

Customization steps implemented in function [processPivotalReleasesSourcePatch](../operations/scripts/pivotalReleasesSourcePatch.sh) in order of execution:

- Apply patch file [`use-product-releases-from-s3-opsmgr.yml`](../operations/opsfiles/use-product-releases-from-s3-opsmgr.yml) to all *upgrade-ops-manager* pipelines from `pcf-pipelines` project in the container. *Note: patch is applied only to local files in the pipeline container where Maestro is run.*  

- Apply patch file [`./operations/opsfiles/use-product-releases-from-s3-tiles.yml`](../operations/opsfiles/./operations/opsfiles/use-product-releases-from-s3-tiles.yml) to *upgrade-tile* pipelines from `pcf-pipelines` project in the container. *Note: patch is applied only to local files in the pipeline container where Maestro is run.*  

- Create PivNet-to-S3-bucket pipeline in the main team

  - The following template/patch files are used to create the pipeline:  
  *[pivnet-to-s3-bucket](../pipelines/utils/pivnet-to-s3-bucket.yml)*  
  *[pivnet-to-s3-bucket-opsmgr-entry.yml](../operations/opsfiles/pivnet-to-s3-bucket-opsmgr-entry.yml)*  
  *[pivnet-to-s3-bucket-tile-entry.yml](../operations/opsfiles/pivnet-to-s3-bucket-opsmgr-entry.yml)*  

  - iterates through the specified foundations file (from parameter *template-foundation-config-file* in main configuration file) to determine which tiles are required to have download/upload jobs in the pipeline, then create pipeline jobs for each one of them.  

  - iterates through all foundations files in Maestro to determine the list of IaaS'es in use. Then create the ops-manager release files download/upload job only for the IaaS'es in that list (by removing the corresponding blocks from the template file for the IaaS'es not in use).   


---
### [Back to Pivotal Releases customization option page](./Pivotal-releases-source-customization.md)
