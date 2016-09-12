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
easier to copy & paste the commands.

### Bielefeld Setup:

    export NUM_NODES=4
    export NUM_CORES=4
    export HOST_SPOOLDIR=/vol/spool
    export HOST_SCRATCHDIR=/vol/scratch
    export DOCKER_USERNAME=<DOCKERHUB ACCOUNT NAME>

### Giessen Setup:

    export NUM_NODES=4
    export NUM_CORES=4
    export HOST_DBDIR=/vol/krakendb
    export HOST_DATADIR=/vol/data
    export HOST_SPOOLDIR=/vol/spool
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

Let's start by creating wrapper script for the `docker run` command to make it easier for us to define the environment of the cluster when running a container. The script will call a `COMMAND` while simultaneously defining which `SCRATCHDIR` (local disk) and SPOOLDIR (NFS shared between the master and all slaves) of the host will be mounted to the container.

### Bielefeld Setup

    docker_run.sh CONTAINER SCRATCHDIR SPOOLDIR COMMAND

### Giessen Setup

    docker_run.sh CONTAINER DBDIR DATADIR SPOOLDIR COMMAND

The `docker run` command inside the script should look
like this (add mounts, container and command):

    docker run -e "NSLOTS=$NSLOTS" ....

Edit the `docker_run.sh` script in the `scripts` folder and define
the mount points inside your container.

### Download Kraken Database

**Note:** Donwloading the database to the local `SCRATCHDIR` is
only necessary in the Bielefeld Setup. In the Giessen Setup, the
database and data are provided via volumes and already mounted
to the cluster nodes during startup.

Now we can work on the Kraken pipeline which will run inside
the container. 

First we need to download the Kraken database to each of
the hosts. You need to work on the `kraken_download_db.sh`
file. The Kraken Database is located in the SWIFT object store container `gcb`. 
To download it using the `swift` client, you simply call:

    swift -U gcb:swift -K ssbBisjNkXmwgSXbvyAN6CtQJJcW2moMHEAdQVN0 -A http://swift:7480/auth \
    download gcb minikraken.tgz --output <CONTAINER SCRATCHDIR>/minikraken.tgz

Write a script `kraken_download_db.sh` which will download the Kraken DB to the 
container-local scratch disk. Untar the file using `tar xvzf minikraken.tgz`. 
Save the script in the `container_scripts` directory. 

**Note:** you need to run `docker build` and `docker push` after each change
you made to the container scripts. If you start a remote job, make sure you pull
the new version of the container. You can test the container
locally using your `docker_run.sh` wrapper.

If you want to distribute the jobs on the
cluster, use `qsub` to sumit the job to the SGE queue.
The `-pe` option ensures, that we only download the 
database **once on each host**

#### Bielefeld Setup:

    qsub -N DB_Download -t 1-$NUM_NODES -pe multislot $NUM_CORES -cwd \
    /vol/spool/docker-kraken-gcb/scripts/docker_run.sh \
    $DOCKER_USERNAME/kraken-docker $HOST_SCRATCHDIR $HOST_SPOOLDIR \
    /vol/scripts/kraken_download_db.sh


### Run Kraken Analysis

Next, we need to write a wrapper script for the kraken call. In the Bielefeld
setup you need to download the FASTQ file from SWIFT first:

    swift -U gcb:swift -K ssbBisjNkXmwgSXbvyAN6CtQJJcW2moMHEAdQVN0 \
    -A http://swift:7480/auth download gcb INFILE --output <SCRATCHDIR/INFILE>

In the Giessen Setup the FASTQ is already mounted to the host `HOST_DATADIR`.

**Note:** The list of input file names can be found in `samples.txt`.

Now you can run Kraken on the `INFILE`:

    /vol/kraken/kraken --preload --threads $NSLOTS --db <PATH TO KRAKEN DB> \
    --fastq-input --gzip-compressed --output <SPOOLDIR/OUTFILE> <INFILE>

**Note:** Every time you make changes to your script, to need to build and push your Docker container
before testing it using the `docker_run.sh` wrapper.

Start the pipeline for just one input file:

#### Bielefeld Setup:

    qsub -N kraken_SRR935726 -pe multislot $NUM_CORES -cwd \
    /vol/spool/docker-kraken-gcb/scripts/docker_run.sh \
    $DOCKER_USERNAME/kraken-docker $HOST_SCRATCHDIR $HOST_SPOOLDIR \
    "/vol/scripts/kraken_pipeline.sh SRR935726.fastq.gz SRR935726"

#### Giessen Setup:

    qsub -N kraken_SRR935726 -pe multislot $NUM_CORES -cwd \
    /vol/spool/docker-kraken-gcb/scripts/docker_run.sh \
    $DOCKER_USERNAME/kraken-docker $HOST_DBDIR $HOST_DATADIR $HOST_SPOOLDIR \
    "/vol/scripts/kraken_pipeline.sh SRR935726.fastq.gz SRR935726"


You will find the output files in `/vol/spool`.

If your pipeline is working, analyze all FASTQ files:

#### Bielefeld Setup:

    for i in `cat samples.txt | sed 's/.fastq.gz//g'`
    do 
    qsub -N kraken_$i -pe multislot $NUM_CORES -cwd \
    /vol/spool/docker-kraken-gcb/scripts/docker_run.sh \
    $DOCKER_USERNAME/kraken-docker $HOST_SCRATCHDIR $HOST_SPOOLDIR \
    "/vol/scripts/kraken_pipeline.sh $i.fastq.gz $i"
    done
    
#### Giessen Setup:

    for i in `cat samples.txt | sed 's/.fastq.gz//g'`
    do 
    qsub -N kraken_$i -pe multislot $NUM_CORES -cwd \
    /vol/spool/docker-kraken-gcb/scripts/docker_run.sh \
    $DOCKER_USERNAME/kraken-docker $HOST_DBDIR $HOST_DATADIR $HOST_SPOOLDIR \
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
    

