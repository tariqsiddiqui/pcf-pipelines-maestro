![PCF Pipelines Maestro](https://github.com/pivotalservices/pcf-pipelines-maestro/raw/master/common/images/maestro_combined_icon.png)

# PCF Pipelines Maestro

Maestro implements a framework to automate the creation of customized [pcf-pipelines](https://github.com/pivotal-cf/pcf-pipelines) for multiple [PCF](https://pivotal.io/platform) deployments and to orchestrate the promotion of PCF components and tiles upgrades across foundations using the concept of **Bill of Materials**.  

The framework consists of a main pipeline that has the ability to generate all desired PCF upgrade pipelines in Concourse (_a pipeline that generates pipelines_).


### How it works

Once the Maestro main pipeline is added to Concourse, its execution is controlled by two configuration files retrieved from a git repository:
- `./common/credentials.yml` - contains common parameters required for git project and [PivNet](https://network.pivotal.io/) access (when applicable).  
- `./foundations/*.yml` - configuration files under the `foundations` folder containing configuration parameters for each individual PCF foundation that pipelines will be created for.

The Maestro main pipeline iterates through the `foundations` folder's config files, then for each foundation file found, it does the following:  
1. creates one specific Concourse team (idempotent)  
2. customizes upgrade pipelines using the [yaml-patch tool](https://github.com/krishicks/yaml-patch) per customization options enabled  
3. generates all selected upgrade pipelines for that foundation's Concourse team  

![PCF Pipelines Maestro chart](https://github.com/pivotalservices/pcf-pipelines-maestro/raw/master/common/images/maestro_chart01.png)


---
### How to setup and run the main Maestro pipeline in Concourse  

_For quick tests in development environments (with no need to fork Maestro repo), refer to the [Configure Maestro in a Test Environment](./docs/Test-Environment-Setup.md) document. For any other environments, please follow the instructions below._

1. Fork the **Maestro** git project  https://github.com/pivotalservices/pcf-pipelines-maestro into your own git repository  

1. Download/clone your own **Maestro** git repository   
  For example:
  `git clone https://github.com/pivotalservices/pcf-pipelines-maestro.git`    
  `cd pcf-pipelines-maestro`  

1. Edit `./common/credentials.yml` and fill out all of its parameters for *SECTION A* following instructions in the file.  

1. Edit `./foundations/NYC-DEV.yml` and fill out all parameters for *SECTION 3*.  
   Leave parameters from sections 1 and 2 as-is for now. We will cover these later.

1. Rename `./foundations/NYC-DEV.yml` to match the region and environment of your PCF foundation.  
   For example, `PHX-TST.yml` for a test environment in your Phoenix region, or `WST-PRD.yml` for a production environment in the West region.  

1. Commit and push the config files changes back to your *Maestro* git project repository.  

1. Create the *Maestro* main pipeline in Concourse    
   `fly -t <your-concourse-alias-for-main-team> sp -p pcf-pipelines-maestro -c ./pipelines/pcf-pipelines-maestro.yml -l ./common/credentials.yml`  

1. In the Concourse UI, un-pause and run the newly created `pcf-pipelines-maestro`.  
    Once un-paused, that pipeline should automatically be execute for the first time, in a minute or so, since it is automatically triggered by changes in your Maestro git repository. Regardless, feel free to execute job `orchestrate-pipelines` manually.  

After the `pcf-pipelines-maestro` pipeline executes, you should see a new team created in Concourse for the environment that you configured under the `foundations` folder.

In that team, there should be a couple of pipelines (for `upgrade-OpsMgr` and `upgrade-ERT-tile`), which are created paused by default and which should be functional once they get un-paused.


---
### Adding more upgrade pipelines for tiles, buildpacks and stemcell

To add more upgrade pipelines to a foundation team in Concourse:  

1. edit the corresponding foundation configuration file (e.g. `./foundations/NYC-DEV.yml`)  

1. uncomment the corresponding line for the tile/buildpack/stemcell in **SECTION 1**  
   For example:  
   - to add the upgrade-MySQL-tile pipeline to the foundation team, uncomment the line containing entry
   `BoM_tile_MySQL_product_version: 1.9.*`
   - to add the upgrade pipeline for the `java_buildpack`, uncomment **both** _candidate_ and _current_ lines for that buildpack: `BoM_bp_java_buildpack_candidate: Java Buildpack 3.13` AND `BoM_bp_java_buildpack_current: Java Buildpack 3.12`  
   (note: Maestro implements an opinionated buildpack upgrade management strategy. More info to be provided on that soon)  

1. Commit and push the file changes to you Maestro git repository  

1. Re-run the `pcf-pipelines-maestro` pipeline to regenerate all upgrade pipelines in Concourse.      

---
### Adding new PCF foundations to Maestro

To onboard a new foundation to Maestro:  

1. Duplicate one existing foundations file from the `foundations` folder, rename it appropriately for the new environment (e.g. `DAL-PRD` for production in Dallas) and update its configuration parameters accordingly.  

1. Commit and push the new file into your Maestro git repository  

1. Re-run the `pcf-pipelines-maestro` pipeline

You should see a new team created in Concourse for the new foundation, along with all pipelines created for it according to its configuration file.    


---
### Customizing and patching individual pipelines

The Maestro framework provides a mechanism to automatically patch and customize jobs, tasks or resources of the out-of-the-box `pcf-pipelines` pipelines.

Maestro uses the [yaml-patch tool](https://github.com/krishicks/yaml-patch) to apply out-of-the-box pipeline modification operations based on identified `pcf-pipelines` usage patterns by customers.   

Customization options are available in two categories: *global* - applied to all pipelines across all foundations, and *Foundation-specific* - applied to pipelines of an individual foundation.

#### Global customization options

- *[pcf-pipelines-source](./docs/Pcf-pipelines-source-customization.md)*: changes the source of the `pcf-pipelines` release (e.g. git, PivNet)  

- *[pivotal-releases-source](./docs/Pivotal-releases-source-customization.md)*: changes where Pivotal release files are retrieved from by the pipelines (e.g. PivNet, S3 repository)  


#### Foundation-specific customization options

- *[gated-Apply-Changes-Job](./docs/Gated-Apply-Changes-job.md)*: creates a separate "Apply Changes" job for upgrade pipelines to allow operators decide when to Apply Changes for one or more upgrades.  

Check the details page of each customization option above for information on how to apply each one of them.

Instructions on how to add a pipeline customization operation to Maestro to be provided soon.


---
### Notes

- **Note 1**: Only **upgrade** pipelines from `pcf-pipelines` are supported at this moment.

- **Note 2**: This is a work-in-progress project started from artifacts created for customers in PCF Platform and Ops dojo engagements.  

---
### To Do's
- Extend list of Tiles and Buildpacks supported out-of-the-box
- Performance enhancements:   
  - avoid downloading yaml-patch tool in every execution (e.g. package it in docker image)
- Extend list of OOTB yaml-patch customization options (e.g. use Artifactory to download PivNet resources from, use of private docker registry, add email or slack notification to pipelines, etc)  
- lots more, stay tuned.
