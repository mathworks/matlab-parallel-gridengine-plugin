#!/bin/sh
# This wrapper script is intended to be submitted to Grid Engine to support
# communicating jobs.
#
# Ensure that under Grid Engine, we're in /bin/sh too:
#$ -S /bin/sh
#
# This script uses the following environment variables set by the submit MATLAB code:
# PARALLEL_SERVER_CMR         - the value of ClusterMatlabRoot (may be empty)
# PARALLEL_SERVER_MATLAB_EXE  - the MATLAB executable to use
# PARALLEL_SERVER_MATLAB_ARGS - the MATLAB args to use
#
# The following environment variables are forwarded through mpiexec:
# PARALLEL_SERVER_DECODE_FUNCTION     - the decode function to use
# PARALLEL_SERVER_STORAGE_LOCATION    - used by decode function
# PARALLEL_SERVER_STORAGE_CONSTRUCTOR - used by decode function
# PARALLEL_SERVER_JOB_LOCATION        - used by decode function

# Copyright 2006-2022 The MathWorks, Inc.

# If PARALLEL_SERVER_ environment variables are not set, assign any
# available values with form MDCE_ for backwards compatibility
PARALLEL_SERVER_CMR=${PARALLEL_SERVER_CMR:="${MDCE_CMR}"}
PARALLEL_SERVER_MATLAB_EXE=${PARALLEL_SERVER_MATLAB_EXE:="${MDCE_MATLAB_EXE}"}
PARALLEL_SERVER_MATLAB_ARGS=${PARALLEL_SERVER_MATLAB_ARGS:="${MDCE_MATLAB_ARGS}"}

# Create full paths to mw_smpd/mw_mpiexec if needed
FULL_SMPD=${PARALLEL_SERVER_CMR:+${PARALLEL_SERVER_CMR}/bin/}mw_smpd
FULL_MPIEXEC=${PARALLEL_SERVER_CMR:+${PARALLEL_SERVER_CMR}/bin/}mw_mpiexec
SMPD_LAUNCHED_HOSTS=""

###################################
## CUSTOMIZATION MAY BE REQUIRED ##
###################################
# This script assumes that SSH is set up to work without passwords between
# all nodes on the cluster.
# You may wish to modify SSH_COMMAND to include any additional ssh options that
# you require.
SSH_COMMAND="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Assert that we can read $TMPDIR/machines
if [ ! -r ${TMPDIR}/machines ] ; then
    echo "Couldn't read ${TMPDIR}/machines" >&2
    exit 1
fi

# Work out where we need to launch SMPDs given our hosts file - defines
# SMPD_HOSTS
chooseSmpdHosts() {
    # We must launch SMPD on each unique host that this job is to run on. We need
    # this information as a single line of text, and so we pipe the output of "uniq"
    # through "tr" to convert newlines to spaces
    SMPD_HOSTS=`sort $TMPDIR/machines | uniq | tr '\n' ' '`
}

# Work out which port to use for SMPD
chooseSmpdPort() {
    # Choose unique port for SMPD to run on. Derive from Grid Engine's JOB_ID
    SMPD_PORT=`expr $JOB_ID % 10000 + 20000`
}

# Work out how many processes to launch - set MACHINE_ARG
chooseMachineArg() {
    
    MACHINE_ARG="-n ${NSLOTS} -machinefile ${TMPDIR}/machines"
}

# Shut down SMPDs and exit with the exit code of the last command executed
cleanupAndExit() {
    EXIT_CODE=${?}
    echo ""
    echo "Stopping SMPD on ${SMPD_LAUNCHED_HOSTS} ..."
    for host in ${SMPD_LAUNCHED_HOSTS}
    do
        echo ${SSH_COMMAND} $host \"${FULL_SMPD}\" -shutdown -phrase MATLAB -port ${SMPD_PORT}
        ${SSH_COMMAND} $host \"${FULL_SMPD}\" -shutdown -phrase MATLAB -port ${SMPD_PORT}
    done
    echo "Exiting with code: ${EXIT_CODE}"
    exit ${EXIT_CODE}
}

# Use ssh to launch the SMPD daemons on each processor
launchSmpds() {
    # Launch the SMPD processes on all hosts using SSH
    echo "Starting SMPD on ${SMPD_HOSTS} ..."
    for host in ${SMPD_HOSTS}
      do
      # This script assumes that SSH is set up to work without passwords between
      # all nodes on the cluster
      echo ${SSH_COMMAND} $host \"${FULL_SMPD}\" -s -phrase MATLAB -port ${SMPD_PORT}
      ${SSH_COMMAND} $host \"${FULL_SMPD}\" -s -phrase MATLAB -port ${SMPD_PORT}
      ssh_return=${?}
      if [ ${ssh_return} -ne 0 ] ; then
          echo "Launching smpd failed for node: ${host}"
          exit 1
      else
          SMPD_LAUNCHED_HOSTS="${SMPD_LAUNCHED_HOSTS} ${host}"
      fi
    done
    echo "All SMPDs launched"
}

runMpiexec() {

    ENVS_TO_FORWARD="PARALLEL_SERVER_DECODE_FUNCTION,PARALLEL_SERVER_STORAGE_LOCATION,PARALLEL_SERVER_STORAGE_CONSTRUCTOR,PARALLEL_SERVER_JOB_LOCATION,PARALLEL_SERVER_DEBUG,PARALLEL_SERVER_LICENSE_NUMBER,MLM_WEB_LICENSE,MLM_WEB_USER_CRED,MLM_WEB_ID"
    LEGACY_ENVS_TO_FORWARD="MDCE_DECODE_FUNCTION,MDCE_STORAGE_LOCATION,MDCE_STORAGE_CONSTRUCTOR,MDCE_JOB_LOCATION,MDCE_DEBUG,MDCE_LICENSE_NUMBER"
    CMD="\"${FULL_MPIEXEC}\" -smpd -phrase MATLAB -port ${SMPD_PORT} \
        -l ${MACHINE_ARG} -genvlist $ENVS_TO_FORWARD,$LEGACY_ENVS_TO_FORWARD \
        \"${PARALLEL_SERVER_MATLAB_EXE}\" ${PARALLEL_SERVER_MATLAB_ARGS}"

    # As a debug stage: echo the command line...
    echo $CMD
    
    # ...and then execute it
    eval $CMD
    MPIEXEC_CODE=${?}
    if [ ${MPIEXEC_CODE} -ne 0 ] ; then
        exit ${MPIEXEC_CODE}
    fi
}

# Define the order in which we execute the stages defined above
MAIN() {
    # Install a trap to ensure that SMPDs are closed if something errors or the
    # job is cancelled.
    trap "cleanupAndExit" 0 1 2 15
    chooseSmpdHosts
    chooseSmpdPort
    launchSmpds
    chooseMachineArg
    runMpiexec
    exit 0 # Explicitly exit 0 to trigger cleanupAndExit
}

# Call the MAIN loop
MAIN
