function submitString = getSubmitString(jobName, quotedLogFile, quotedCommand, ...
    additionalSubmitArgs, jobArrayString)
%GETSUBMITSTRING Gets the correct qsub command for an Grid Engine cluster

% Copyright 2010-2023 The MathWorks, Inc.

% Submit to Grid Engine using qsub. Note the following:
% "-S /bin/sh" - specifies that we run under /bin/sh
% "-N Job#" - specifies the job name
% "-t ..." specifies a job array string
% "-j yes" joins together output and error streams
% "-o ..." specifies where standard output goes to

if ~isempty(jobArrayString)
    jobArrayString = ['-t ', jobArrayString];
end

submitString = sprintf( 'qsub -S /bin/sh -N %s %s -j yes -o %s %s %s', ...
    jobName, jobArrayString, quotedLogFile, additionalSubmitArgs, quotedCommand);

end
