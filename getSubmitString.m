function submitString = getSubmitString(jobName, quotedLogFile, quotedCommand, ...
    varsToForward, additionalSubmitArgs, jobArrayString)
%GETSUBMITSTRING Gets the correct qsub command for an Grid Engine cluster

% Copyright 2010-2022 The MathWorks, Inc.

envString = strjoin(varsToForward', ',');

% Submit to Grid Engine using qsub. Note the following:
% "-S /bin/sh" - specifies that we run under /bin/sh
% "-N Job#" - specifies the job name
% "-t ..." specifies a job array string
% "-j yes" joins together output and error streams
% "-o ..." specifies where standard output goes to
% "-v ..." specifies which environment variables to forward

if ~isempty(jobArrayString)
    jobArrayString = ['-t ', jobArrayString];
end

submitString = sprintf( 'qsub -S /bin/sh -N %s %s -j yes -o %s -v %s %s %s', ...
    jobName, jobArrayString, quotedLogFile, envString, additionalSubmitArgs, quotedCommand);

end
