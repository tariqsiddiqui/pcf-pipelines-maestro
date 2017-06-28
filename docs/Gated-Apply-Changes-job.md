![PCF Pipelines Maestro](https://github.com/pivotalservices/pcf-pipelines-maestro/raw/master/common/images/maestro_combined_icon.png)

## Customize upgrade pipelines to have a separate Apply Changes job

Maestro can customize *pcf-pipelines* upgrade pipelines to have a *gated* and separate job for the Apply Changes step, which triggers the corresponding action in the targeted Ops Manager.

---
### Why do it?

In non-Test PCF environments (e.g. Production), operators usually require to have more control over when to *Apply Changes* of tiles or ops-manager upgrades instead of having the upgrade pipelines automatically run that step right after a new version of a tile is uploaded and staged in Ops Manager.

Another reason for this customization is the fact that it allows for multiple tiles upgrade to be prepared (uploaded and then staged to Ops Manager), as well as field updates to the staged tiles configuration in the Ops Manager UI, before a one-time Apply Changes task is executed.    


![Gated Apply Changes job](https://github.com/pivotalservices/pcf-pipelines-maestro/raw/master/common/images/maestro_gatedApplyChanges.png)


---
### How to enable it

The **gated Apply Changes job** customization is foundation-specific, which means that only upgrade pipelines of the configured foundation team in Concourse will be updated.

To enable it for each targeted foundation:

1. edit the corresponding foundation configuration file (e.g. `./foundations/NYC-DEV.yml`)  

1. In *SECTION 2*, set parameter `gated-Apply-Changes-Job` to `true`    

1. Save all updated files, commit changes to the Maestro git repository and re-run the Maestro pipeline to update all pipelines.  


---
### [Back to main README](../README.md)
