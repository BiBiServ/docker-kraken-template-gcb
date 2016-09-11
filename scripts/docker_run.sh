#!/bin/bash

if [ $# -ne 4 ]
  then
    echo 
    echo "Usage: docker_run.sh CONTAINER SCRATCHDIR SPOOLDIR COMMAND"
    echo 
    echo "wrapper to run docker"
    echo 
    exit 0;
fi

CONTAINER=$1
SCRATCHDIR=$2
SPOOLDIR=$3
COMMAND=$4

sudo docker pull $CONTAINER
sudo docker run \
    -e "NSLOTS=$NSLOTS" \
    -v $SCRATCHDIR:/path/inside/container/to/scratchdir \
    -v $SPOOLDIR:/path/inside/container/to/spooldir \
    $CONTAINER \
    $COMMAND
