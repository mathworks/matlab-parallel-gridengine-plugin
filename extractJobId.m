function jobID = extractJobId(cmdOut)
% Extracts the job ID from the qsub command output for Grid Engine

% Copyright 2010-2022 The MathWorks, Inc.

% The output of qsub will be:
% Your job 496 ("<job name>") has been submitted

% Now parse the output of qsub to extract the job number
jobIDCell = regexp(cmdOut, 'job(?:\-array)? ([0-9]+)', 'tokens', 'once');
jobID = jobIDCell{1};
dctSchedulerMessage(0, '%s: Job ID %s was extracted from qsub output %s.', mfilename, jobID, cmdOut);
end
