# Docker Kraken Template

## Start BiBiGrid Cluster
First, we need to start a bibigrid cluster in the cloud. If you have
not done this already, edit the properties file downloaded from the
gcb-tutorial repository and add your credentials and path to your SSH
key file. 

Start bibigrid:

    bibigrid -u $USER -c -o bibigrid.properties

Login to master node (see BiBiGrid output how to set environment variables):

    ssh -i ~/.ssh/SSH_CREDENTIALS.pem ssh -i id_rsa ubuntu@$BIBIGRID_MASTER

## Download Github repository
Now your are logged on to the master node of your cloud-based SGE
cluster! We will clone the docker-kraken-template-gcb github repository to
the master node and continue working on the master node.

Clone the Docker Kraken Pipeline from Github:

    cd /vol/spool
    git clone https://github.com/BiBiServ/docker-kraken-template-gcb.git
    cd docker-kraken-template-gcb

## Set environment variables
The command line calls on this page assume that you have several
environment variables set for your cloud environment. This makes it
easier to copy & paste the commands:

    export NUM_NODES=4
    export NUM_CORES=4
    export HOST_SPOOLDIR=/vol/spool
    export HOST_SCRATCHDIR=/vol/scratch
    export DOCKER_USERNAME=<DOCKERHUB ACCOUNT NAME>

## Kraken Docker Image

The `Dockerfile` includes all information about the Docker image.
Place scripts you want to have accessible in the Docker image
into the `container_scripts` directory. These scripts will be
called to download the database to the hosts and run the analyses.

```
FROM bibiserv/gcb-ubuntu

# the following required packages from the base ubuntu installation
# have already been installed in the bibiserv/ubuntu-gcb image
# to avoid high download traffic during the tutorial

#RUN apt-get update && \
#    apt-get install -y -f perl-modules libgomp1 python-swiftclient && \
#    rm -rf /var/lib/apt/lists/*

# create directories where the host file system can be mounted
RUN mkdir /vol

# copy the required scripts that run the pipeline from your machine to the
# Docker image and make them executable
ADD ./kraken/ /vol/kraken/
RUN chmod 755 /vol/kraken/*
ADD ./container_scripts/ /vol/scripts/
```

### Login to DockerHub

We need to pull the updated image to each of the hosts
before we can start the analysis scripts. Before pushing 
to the DockerHub, you need to login:

    docker login -u $DOCKER_USERNAME
    
### Building and Pushing the Docker Image 

Now every time you made a changes to the container scripts,
you need to push the image to DockerHub:

    docker build -t "$DOCKER_USERNAME/kraken-docker" .
    docker push $DOCKER_USERNAME/kraken-docker

## Running Kraken containers on the cluster nodes

Let's start with a wrapper for the `docker run` command. 
This will make it easier to define the environment
of your cluster when running your container. We will call a 
`COMMAND` in the container using the following script. 
At the same time, we will define which `SCRATCHDIR` (local disk) 
and `SPOOLDIR` (NFS shared between the master and all slaves) 
of the host will be mounted to the container. 

    docker_run.sh CONTAINER SCRATCHDIR SPOOLDIR COMMAND

The `docker run` command inside the script should look
similar to this template:

    docker pull CONTAINER
    docker run \
        -e "NSLOTS=$NSLOTS" \
        -v SCRATCHDIR:/path/inside/container/to/scratchdir \
        -v SPOOLDIR:/path/inside/container/to/spooldir \
        CONTAINER \
        COMMAND

Edit the `docker_run.sh` script in the `scripts` folder and define
the mount points inside your container.

### Download Kraken Database

Now we can work on the Kraken pipeline which will run inside
the container.

First we need to download the Kraken database to each of
the hosts. You need to work on the `kraken_download_db.sh`
file. The Kraken Database is located in the SWIFT object store container `gcb`. 
To download it using the `swift` client, you simply call:

    swift -U gcb:swift -K ssbBisjNkXmwgSXbvyAN6CtQJJcW2moMHEAdQVN0 -A http://swift:7480/auth \
    download gcb minikraken.tgz --output <CONTAINER SCRATCHDIR>/minikraken.tgz

Write a script `kraken_download_db.sh` which will download the Kraken DB
and untar the file using `tar xvzf minikraken.tgz`. Save the script in the
`container_scripts` directory. 

**Note:** you need to run `docker build` and `docker push` after each change
you made to the container scripts. After that you can test the container
locally using your `docker_run.sh` wrapper.

If you want to distribute the jobs on the
cluster, use `qsub` to sumit the job to the SGE queue.
The `-pe` option ensures, that we only download the 
database **once on each host**:

    qsub -N DB_Download -t 1-$NUM_NODES -pe multislot $NUM_CORES -cwd \
    /vol/spool/docker-kraken-gcb/scripts/docker_run.sh \
    $DOCKER_USERNAME/kraken-docker $HOST_SCRATCHDIR $HOST_SPOOLDIR \
    /vol/scripts/kraken_download_db.sh


### Run Kraken Analysis

Start the pipeline for just one input file:

    qsub -N kraken_SRR935726 -pe multislot $NUM_CORES -cwd \
    /vol/spool/docker-kraken-gcb/scripts/docker_run.sh \
    $DOCKER_USERNAME/kraken-docker $HOST_SCRATCHDIR $HOST_SPOOLDIR \
    "/vol/scripts/kraken_pipeline.sh SRR935726.fastq.gz SRR935726"

You will find the output files in `/vol/spool`.

If your pipeline is working, analyze all FASTQ files:

    for i in `cat samples.txt | sed 's/.fastq.gz//g'`
    do 
    qsub -N kraken_$i -pe multislot $NUM_CORES -cwd \
    /vol/spool/docker-kraken-gcb/scripts/docker_run.sh \
    $DOCKER_USERNAME/kraken-docker $HOST_SCRATCHDIR $HOST_SPOOLDIR \
    "/vol/scripts/kraken_pipeline.sh $i.fastq.gz $i"
    done
    
### Generate Krona plot

    cd /vol/spool
    for i in *out; do cut -f2,3 $i > $i.krona; done
    ktImportTaxonomy *krona -o krona.html
    cp -r krona.html* ~/public_html
    
You can use your browser to look at the Krona output.
Go to: `http://<BIBIGRID_MASTER>/~ubuntu/`

## Clean up

After logout, terminate the BiBiGrid cluster:

    bibigrid -o bibigrid.properties -l
    bibigrid -o bibigrid.properties -t CLUSTERID
    

