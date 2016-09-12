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

docker run -e "NSLOTS=$NSLOTS" ....

