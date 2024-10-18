# Parallel Computing Toolbox plugin for MATLAB Parallel Server with Grid Engine

[![View Parallel Computing Toolbox Plugin for Grid Engine on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/127389-parallel-computing-toolbox-plugin-for-grid-engine)

Parallel Computing Toolbox&trade; provides the `Generic` cluster type for submitting MATLAB&reg; jobs to a cluster running a third-party scheduler.
The `Generic` cluster type uses a set of plugin scripts to define how your machine communicates with your scheduler.
You can customize the plugin scripts to configure how MATLAB interacts with the scheduler to best suit your cluster setup and support custom submission options.

This repository contains MATLAB code files and shell scripts that you can use to submit jobs from a MATLAB or Simulink session running on Windows&reg;, Linux&reg;, or macOS operating systems to a Grid Engine&reg; scheduler running on Linux.

## Products Required

- [MATLAB](https://www.mathworks.com/products/matlab.html) and [Parallel Computing Toolbox](https://www.mathworks.com/products/parallel-computing.html), R2017a or newer, installed on your computer.
Refer to the documentation for [how to install MATLAB and toolboxes](https://www.mathworks.com/help/install/index.html) on your computer.
- [MATLAB Parallel Server&trade;](https://www.mathworks.com/products/matlab-parallel-server.html) installed on the cluster.
Refer to the documentation for [how to install MATLAB Parallel Server](https://www.mathworks.com/help/matlab-parallel-server/integrate-matlab-with-third-party-schedulers.html) on your cluster.
The cluster administrator normally does this step.
- Grid Engine running on the cluster.

## Setup Instructions

### Download or Clone this Repository

To download a zip archive of this repository, at the top of this repository page, select **Code > Download ZIP**.
Alternatively, to clone this repository to your computer with Git software installed, enter this command at your system's command line:
```
git clone https://github.com/mathworks/matlab-parallel-gridengine-plugin
```
You can execute a system command from the MATLAB command prompt by adding `!` before the command.

### Scheduler Configuration

To run communicating (MPI) jobs, a Grid Engine parallel environment (PE) is required.
Two example template files are provided.
The "matlabPe.template" file is compatible with the Hydra process manager and should be used in most cases for R2019a onwards.
The "matlabSmpdPe.template" is compatible with the SMPD process manager and can be used if problems arise using the Hydra process manager or for R2018b and earlier.

Both templates must be customized to match the number of slots available.
The "matlabSmpdPe.template" file must be customized to match where the "startmatlabpe.sh" and "stopmatlabpe.sh" scripts are installed on your cluster.

The following stages are needed to create the parallel environment, and then make the parallel environment runnable on a particular queue.
You should perform these steps on the headnode of your cluster.
If you wish to support both Hydra and SMPD process managers, carry out these stages for both the "matlabPe.template" and "matlabSmpdPe.template" files.

1. Modify the contents of the template to use your desired number of slots.
If you are using the "matlabSmpdPe.template" file, then also modify the contents to use the correct location of the startmatlabpe.sh and stopmatlabpe.sh files.
You can also change other values or add additional values to the templates to suit your cluster.
For more information, refer to the sge_pe documentation provided with your cluster.

2. Add the "matlab" parallel environment, using the shell command:
```
$ qconf -Ap matlabPe.template
```

3. Make the "matlab" PE runnable on all queues:
```
$ qconf -mq all.q
```
This will bring up a text editor for you to make changes: search for the line "pe_list", and add "matlab".

4. Ensure you can submit a trivial job to the PE:
```
$ echo "hostname" | qsub -pe matlab 1
```

Check that the job runs correctly using "qstat", and check that the output file contains the name of the host that ran the job.
The default filename for the output file is "~/STDIN.o###", where "###" is the Grid Engine job number.

### Cluster Discovery

Since version R2023a, MATLAB can discover clusters running third-party schedulers such as Grid Engine.
As a cluster admin, you can create a configuration file that describes how to configure the Parallel Computing Toolbox on the user's machine to submit MATLAB jobs to the cluster.
The cluster configuration file is a plain text file with the extension `.conf` containing key-value pairs that describe the cluster configuration information.
The MATLAB client will use the cluster configuration file to create a cluster profile for the user who discovers the cluster.
Therefore, users will not need to follow the instructions in the sections below.
You can find an example of a cluster configuration file in [discover/example.conf](discover/example.conf).
For full details on how to make a cluster running a third-party scheduler discoverable, see the documentation for [Configure for Third-Party Scheduler Cluster Discovery](https://www.mathworks.com/help/matlab-parallel-server/configure-for-cluster-discovery.html).

### Create a Cluster Profile in MATLAB

Create a cluster profile by using either the Cluster Profile Manager or the MATLAB Command Window.

To open the Cluster Profile Manager, on the **Home** tab, in the **Environment** section, select **Parallel > Create and Manage Clusters**.
In the Cluster Profile Manager, select **Add Cluster Profile > Generic** from the menu to create a new `Generic` cluster profile.

Alternatively, create a new `Generic` cluster object by entering this command in the MATLAB Command Window:
```matlab
c = parallel.cluster.Generic;
```

### Configure Cluster Properties

This table lists the properties that you must specify to configure the `Generic` cluster profile.
For a full list of cluster properties, see the documentation for [`parallel.Cluster`](https://www.mathworks.com/help/parallel-computing/parallel.cluster.html).

**Property**            | **Description**
------------------------|----------------
`JobStorageLocation`    | Folder in which your machine stores job data.
`NumWorkers`            | Number of workers your license allows.
`ClusterMatlabRoot`     | Full path to the MATLAB install folder on the cluster.
`OperatingSystem`       | Cluster operating system.
`HasSharedFilesystem`   | Indication of whether you have a shared file system. Set this property to `true` if a disk location is accessible to your machine and the workers on the cluster. Set this property to `false` if you do not have a shared file system.
`PluginScriptsLocation` | Full path to the plugin script folder that contains this README. If using R2019a or earlier, this property is called IntegrationScriptsLocation.

In the Cluster Profile Manager, set each property value.
Alternatively, at the command line, set properties using dot notation:
```matlab
c.JobStorageLocation = 'C:\MatlabJobs';
```

At the command line, you can also set properties when you create the `Generic` cluster object by using name-value arguments:
```matlab
c = parallel.cluster.Generic( ...
    'JobStorageLocation', 'C:\MatlabJobs', ...
    'NumWorkers', 20, ...
    'ClusterMatlabRoot', '/usr/local/MATLAB/R2022a', ...
    'OperatingSystem', 'unix', ...
    'HasSharedFilesystem', true, ...
    'PluginScriptsLocation', 'C:\MatlabGrid EnginePlugin\shared');
```

To submit from a Windows machine to a Linux cluster, specify `JobStorageLocation` as a structure with the fields `windows` and `unix`.
The fields are the Windows and Unix paths corresponding to the folder in which your machine stores job data.
For example, if the folder `\\organization\matlabjobs\jobstorage` on Windows corresponds to `/organization/matlabjobs/jobstorage` on the Unix cluster:
```matlab
struct('windows', '\\organization\matlabjobs\jobstorage', 'unix', '/organization/matlabjobs/jobstorage')
```
If you have your `M:` drive mapped to `\\organization\matlabjobs`, set `JobStorageLocation` to:
```matlab
struct('windows', 'M:\jobstorage', 'unix', '/organization/matlabjobs/jobstorage')
```

You can use `AdditionalProperties` to modify the behaviour of the `Generic` cluster without editing the plugin scripts.
For a full list of the `AdditionalProperties` supported by the plugin scripts in this repository, see [Customize Behavior of Sample Plugin Scripts](https://www.mathworks.com/help/matlab-parallel-server/customize-behavior-of-sample-plugin-scripts.html).
By modifying the plugins, you can add support for your own custom `AdditionalProperties`.

#### Connect to a Remote Cluster

To manage work on the cluster, MATLAB calls the Grid Engine command line utilities.
For example, the `qsub` command to submit work and `qstat` to query the state of submitted jobs.
If your MATLAB session is running on a machine with the scheduler utilities available, the plugin scripts can call the utilities on the command line.
Scheduler utilities are typically available if your MATLAB session is running on the Grid Engine cluster to which you want to submit.

If MATLAB cannot directly access the scheduler utilities on the command line, the plugin scripts create an SSH session to the cluster and run scheduler commands over that connection.
To configure your cluster to submit scheduler commands via SSH, set the `ClusterHost` field of `AdditionalProperties` to the name of the cluster node to which MATLAB connects via SSH.
As MATLAB will run scheduler utilities such as `sbatch` and `squeue`, select the cluster head node or login node.

In the Cluster Profile Manager, add new `AdditionalProperties` by clicking **Add** under the table corresponding to `AdditionalProperties`.
In the Command Window, use dot notation to add new fields.
For example, if MATLAB should connect to `'gridengine01.organization.com'` to submit jobs, set:
```matlab
c.AdditionalProperties.ClusterHost = 'gridengine01.organization.com';
```

Use this option to connect to a remote cluster to submit jobs from a MATLAB session on a Windows computer to a Linux Grid Engine cluster on the same network.
Your Windows machine creates an SSH session to the cluster head node to access the Grid Engine utilities and uses a shared network folder to store job data files.

If your MATLAB session is running on a compute node of the cluster to which you want to submit work, you can use this option to create an SSH session back to the cluster head node and submit more jobs.

#### Run Jobs on a Remote Cluster Without a Shared File System

MATLAB uses files on disk to send tasks to the Parallel Server workers and fetch their results.
This is most effective when the disk location is accessible to your machine and the workers on the cluster.
Your computer can communicate with the workers by reading and writing to this shared file system.

If you do not have a shared file system, MATLAB uses SSH to submit commands to the scheduler and SFTP (SSH File Transfer Protocol) to copy job and task files between your computer and the cluster.
To configure your cluster to move files between the client and the cluster with SFTP, set the `RemoteJobStorageLocation` field of `AdditionalProperties` to a folder on the cluster that the workers can access.

Transferring large data files (for example, hundreds of MB) over the SFTP connection can add a noticeable overhead to job submission and fetching results.
For optimal performance, use a shared file system if one is available.
The workers require access to a shared file system, even if your computer cannot access it.

### Save New Profile

In the Cluster Profile Manager, click **Done**.
Alternatively, in the Command Window, enter the command:
```matlab
saveAsProfile(c, 'myGridEngineCluster');
```
Your cluster profile is now ready to use.

### Validate Cluster Profile

Cluster validation submits one job of each type to test whether the cluster profile is configured correctly.
In the Cluster Profile Manager, click **Validate**.
If you make a change to a cluster profile, run cluster validation to ensure your changes have introduced no errors.
You do not need to validate the profile each time you use it or each time you start MATLAB.

## Examples

Create a cluster object using your profile:
```matlab
c = parcluster("myGridEngineCluster")
```

### Submit Work for Batch Processing

The `batch` command runs a MATLAB script or function on a worker on the cluster.
For more information about batch processing, see the documentation for [`batch`](https://www.mathworks.com/help/parallel-computing/batch.html).

```matlab
% Create a job and submit it to the cluster.
job = batch( ...
    c, ... % Cluster object created using parcluster
    @sqrt, ... % Function or script to run
    1, ... % Number of output arguments
    {[64 100]}); % Input arguments

% Your MATLAB session is now available to do other work, such
% as create and submit more jobs to the cluster. You can also
% shut down your MATLAB session and come back later. The work
% continues running on the cluster. After you recreate the
% cluster object using parcluster, you can view existing jobs
% using the Jobs property of the cluster object.

% Wait for the job to complete. If the job is already complete,
% the wait function will return immediately.
wait(job);

% Retrieve the output arguments for each task. For this example,
% the output is a 1x1 cell array containing the vector [8 10].
results = fetchOutputs(job)
```

### Open Parallel Pool

A parallel pool (parpool) is a group of MATLAB workers on which you can interactively run work.
When you run the `parpool` command, MATLAB submits a special job to the cluster to start the workers.
Once the workers start, your MATLAB session connects to them.
Depending on the network configuration at your organization, including whether it is permissible to connect to a program running on a compute node, parpools may not be functional.
For more information about parpools, see the documentation for [`parpool`](https://www.mathworks.com/help/parallel-computing/parpool.html).

```matlab
% Open a parallel pool on the cluster. This command returns a
% pool object once the pool is opened.
pool = parpool(c);

% List the hosts on which the workers are running. For a small pool,
% all the workers are typically on the same machine. For a large
% pool, the workers are usually spread over multiple nodes.
future = parfevalOnAll(pool, @getenv, 1, 'HOST')
wait(future);
fetchOutputs(future)

% Output the numbers 1 to 10 in a parallel for loop. Unlike a
% regular for loop, the software does not execute iterations
% of the loop in order.
parfor idx = 1:10
    disp(idx)
end

% Use the pool to calculate the first 500 magic squares.
parfor idx = 1:500
    magicSquare{idx} = magic(idx);
end
```

## License

The license is available in the [license.txt](license.txt) file in this repository.

## Community Support

[MATLAB Central](https://www.mathworks.com/matlabcentral)

## Technical Support

If you require assistance or have a request for additional features or capabilities, please contact [MathWorks Technical Support](https://www.mathworks.com/support/contact_us.html).

Copyright 2022-2023 The MathWorks, Inc.
