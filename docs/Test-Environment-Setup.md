![PCF Pipelines Maestro](https://github.com/pivotalservices/pcf-pipelines-maestro/raw/master/common/images/maestro_combined_icon.png)

# Configure Maestro in a Test Environment

When you just want to experiment with `pcf-pipelines-maestro` without the need to fork its original git repository (and the need to manage a private repo because of system credentials added to it), it is possible to run its pipelines from a local machine using [`fly execute`](http://concourse.ci/fly-execute.html).

1. Clone both the `pcf-pipelines` and `pcf-pipelines-maestro` git projects in to your local machine:   
  `git clone https://github.com/pivotal-cf/pcf-pipelines.git`    
  `git clone https://github.com/pivotalservices/pcf-pipelines-maestro.git`    

1. Edit `./pcf-pipelines-maestro/common/credentials.yml` and fill out all of its parameters following instructions in the file.  

1. Edit `./pcf-pipelines-maestro/foundations/NYC-DEV.yml` and fill out all parameters for *SECTION 3*.  

1. Rename `./pcf-pipelines-maestro/foundations/NYC-DEV.yml` to match the region and environment of your PCF foundation.  
   For example, `PHX-TST.yml` for a test environment in your Phoenix region, or `WST-PRD.yml` for a production environment in the West region.  

1. Run the Maestro pipeline using `fly execute`:  
   `cd pcf-pipelines-maestro`  
   `fly -t <your-main-team-alias> execute -c ./tasks/maestro/task.yml -i pcf-pipelines-maestro=. -i pcf-pipelines=../pcf-pipelines`  

That should create all foundation teams in Concourse along with all the configured pipelines in them.  
For instructions on how to add new pipelines, new foundation teams and/or customize pipelines, go back to the [main README file](../README.md) and keep reading. In places where instructions say `Push and commit to git repo`, simply edit the corresponding files in your machine and rerun the `fly execute` command as above.

To destroy all pipelines created by `pcf-pipelines-maestro` in a single shot, you can `fly execute` the `teams-demolition` util task bundled with the framework:

`fly -t local execute -c ./tasks/utils/teams-demolition/task.yml -i pcf-pipelines-maestro=.`

---
### [Back to main README](../README.md)
