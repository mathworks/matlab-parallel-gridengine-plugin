#!/bin/sh

# Copyright 2006-2021 The MathWorks, Inc.

# This PE start script expects to be called
# startmatlabpe.sh <pe_hostfile>
# Where pe_hostfile contains the nodes we've been assigned
#
# We will create $TMPDIR/machines which contains a machinefile correctly
# formatted for execution
#
# This file is based on Grid Engine's example MPI PE startup script

PeHostfile2MachineFile()
{
   cat $1 | while read line; do
      host=`echo $line|cut -f1 -d" "|cut -f1 -d"."`
      nslots=`echo $line|cut -f2 -d" "`
      i=1
      while [ $i -le $nslots ]; do
          echo $host
          i=`expr $i + 1`
      done
   done
}

# test number of args
me=`basename $0`
if [ $# -ne 1 ] ; then
   echo "$me: got wrong number of arguments" >&2
   exit 1
fi

pe_hostfile=$1

# ensure pe_hostfile is readable
if [ ! -r $pe_hostfile ] ; then
   echo "$me: can't read $pe_hostfile" >&2
   exit 1
fi

# create machine-file
# remove column with number of slots per queue
# mpi does not support them in this form
machines="$TMPDIR/machines"
PeHostfile2MachineFile ${pe_hostfile} > ${machines}
