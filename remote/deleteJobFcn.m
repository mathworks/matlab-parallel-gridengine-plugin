function deleteJobFcn(cluster, job)
%DELETEJOBFCN Deletes a job on Grid Engine
%
% Set your cluster's PluginScriptsLocation to the parent folder of this
% function to run it when you delete a job.

% Copyright 2017-2022 The MathWorks, Inc.

cancelJobFcn(cluster, job);

% If this function returns before Grid Engine has actually finished
% processing the job, the job may be left in an 'Eqw' state and appear in
% the output of qstat until it is deleted with qdel. To try to prevent this
% from happening, wait a maximum of 20 seconds for the job to not exist
% according to qstat before returning.
% CONFIGURATION OF THIS TIME MAY BE REQUIRED.
maxTimeToWait = seconds(20);
jobCancelTime = datetime('now', 'TimeZone', 'local');

% Store the current filename for the errors, warnings and dctSchedulerMessages
currFilename = mfilename;

% Get the information about the actual cluster used
data = cluster.getJobClusterData(job);
if isempty(data)
    % This indicates that the job has not been submitted, so just return
    dctSchedulerMessage(1, '%s: Job cluster data was empty for job with ID %d.', currFilename, job.ID);
    return
end
schedulerIDs = getSimplifiedSchedulerIDsForJob(job);
schedulerIDsString = strjoin(schedulerIDs, ',');
commandToRun = sprintf('qstat -j %s', schedulerIDsString);

while (datetime('now', 'TimeZone', 'local') - jobCancelTime) < maxTimeToWait
    dctSchedulerMessage(4, '%s: Checking job does not exist on scheduler using command:\n\t%s.', currFilename, commandToRun);
    try
        % Execute the command on the remote host.
        [cmdFailed, ~] = remoteConnection.runCommand(commandToRun);
    catch err %#ok<NASGU>
        cmdFailed = true;
    end
    
    % qstat returns a non-zero error code if the jobs do not exist. This is
    % desired behaviour.
    if cmdFailed
        dctSchedulerMessage(4, '%s: qstat failed. Assuming job does not exist on scheduler.', currFilename);
        return
    end
    pause(1);
end
dctSchedulerMessage(4, '%s: Job still exists on scheduler despite waiting %s.', currFilename, char(maxTimeToWait));

end
