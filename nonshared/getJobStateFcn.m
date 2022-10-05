function state = getJobStateFcn(cluster, job, state)
%GETJOBSTATEFCN Gets the state of a job from Grid Engine
%
% Set your cluster's PluginScriptsLocation to the parent folder of this
% function to run it when you query the state of a job.

% Copyright 2010-2022 The MathWorks, Inc.

% Store the current filename for the errors, warnings and
% dctSchedulerMessages
currFilename = mfilename;
if ~isa(cluster, 'parallel.Cluster')
    error('parallelexamples:GenericGridEngine:SubmitFcnError', ...
        'The function %s is for use with clusters created using the parcluster command.', currFilename)
end
if cluster.HasSharedFilesystem
    error('parallelexamples:GenericGridEngine:NotNonSharedFileSystem', ...
        'The function %s is for use with nonshared filesystems.', currFilename)
end

% Get the information about the actual cluster used
data = cluster.getJobClusterData(job);
if isempty(data)
    % This indicates that the job has not been submitted, so just return
    dctSchedulerMessage(1, '%s: Job cluster data was empty for job with ID %d.', currFilename, job.ID);
    return
end
try
    hasDoneLastMirror = data.HasDoneLastMirror;
catch err
    ex = MException('parallelexamples:GenericGridEngine:FailedToRetrieveRemoteParameters', ...
        'Failed to retrieve remote parameters from the job cluster data.');
    ex = ex.addCause(err);
    throw(ex);
end
% Shortcut if the job state is already finished or failed
jobInTerminalState = strcmp(state, 'finished') || strcmp(state, 'failed');
% and we have already done the last mirror
if jobInTerminalState && hasDoneLastMirror
    return
end
remoteConnection = getRemoteConnection(cluster);
schedulerIDs = getSimplifiedSchedulerIDsForJob(job);

% We can't use the -j flag to qstat because it will only accept a single job ID
commandToRun = 'qstat';
dctSchedulerMessage(4, '%s: Querying cluster for job state using command:\n\t%s', currFilename, commandToRun);

try
    % We will ignore the status returned from the state command because
    % a non-zero status is returned if the job no longer exists
    % Execute the command on the remote host.
    [~, cmdOut] = remoteConnection.runCommand(commandToRun);
catch err
    ex = MException('parallelexamples:GenericGridEngine:FailedToGetJobState', ...
        'Failed to get job state from cluster.');
    ex = ex.addCause(err);
    throw(ex);
end

clusterState = iExtractJobState(cmdOut, schedulerIDs);
dctSchedulerMessage(6, '%s: State %s was extracted from cluster output.', currFilename, clusterState);

% If we could determine the cluster's state, we'll use that, otherwise
% stick with MATLAB's job state.
if ~strcmp(clusterState, 'unknown')
    state = clusterState;
end

% Decide what to do with mirroring based on the cluster's version of job state and whether or not
% the job is currently being mirrored:
% If job is not being mirrored, and job is not finished, resume the mirror
% If job is not being mirrored, and job is finished, do the last mirror
% If the job is being mirrored, and job is finished, do the last mirror.
% Otherwise (if job is not finished, and we are mirroring), do nothing
isBeingMirrored = remoteConnection.isJobUsingConnection(job.ID);
isJobFinished = strcmp(state, 'finished') || strcmp(state, 'failed');
if ~isBeingMirrored && ~isJobFinished
    % resume the mirror
    dctSchedulerMessage(4, '%s: Resuming mirror for job %d.', currFilename, job.ID);
    try
        remoteConnection.resumeMirrorForJob(job);
    catch err
        warning('parallelexamples:GenericGridEngine:FailedToResumeMirrorForJob', ...
            'Failed to resume mirror for job %d.  Your local job files may not be up-to-date.\nReason: %s', ...
            err.getReport);
    end
elseif isJobFinished
    dctSchedulerMessage(4, '%s: Doing last mirror for job %d.', currFilename, job.ID);
    try
        remoteConnection.doLastMirrorForJob(job);
        % Store the fact that we have done the last mirror so we can shortcut in the future
        data.HasDoneLastMirror = true;
        cluster.setJobClusterData(job, data);
    catch err
        warning('parallelexamples:GenericGridEngine:FailedToDoFinalMirrorForJob', ...
            'Failed to do last mirror for job %d.  Your local job files may not be up-to-date.\nReason: %s', ...
            err.getReport);
    end
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function state = iExtractJobState(qstatOut, requestedJobIDs)
% Function to extract the job state for the requested jobs from the
% output of qstat

% Expected qstat output:
% !qstat
% job-ID     prior   name       user         state submit/start at     queue                          jclass                         slots ja-task-ID
% ------------------------------------------------------------------------------------------------------------------------------------------------
%       4216 0.00000 Job1       jcave        qw    05/04/2020 05:25:26                                                                   1 1-3:1
%       4217 0.00000 Job2       jcave        qw    05/04/2020 05:26:49                                                                   4

% Split lines and remove whitespace padding
splitQstat = strip(splitlines(qstatOut));

% Select only lines beginning with a job ID we care about
jobs = splitQstat(startsWith(splitQstat, requestedJobIDs));

% If none of our jobs appear, they must all be finished
if isempty(jobs)
    state = 'finished';
    return
end

% The job state code is always in the 5th column of qstat output
jobStateCodes = cell(size(jobs));
for ii = 1:numel(jobs)
    jobEntry = split(jobs{ii});
    jobStateCodes{ii} = jobEntry{5};
end

% If any job states are running, the whole job is running
runningJobCodes = {'r', 't', 'Rr', 'Rt'};
if any(cellfun(@(jobCode) any(strcmp(jobCode, runningJobCodes)), jobStateCodes))
    state = 'running';
    return
end

% We know there are no jobs running so if there are some still pending then
% the job must be queued again, even if there are some finished jobs
pendingJobCodes = {'qw', 'hqw', 'hRwq'};
if any(cellfun(@(jobCode) any(strcmp(jobCode, pendingJobCodes)), jobStateCodes))
    state = 'queued';
    return
end

% If any job states start with E, the job has errored
if any(startsWith(jobStateCodes, 'E'))
    state = 'failed';
    return
end

% If we get here then the job is showing in the output to qstat, but we
% haven't been able to determine what state it's in.
state = 'unknown';
end
