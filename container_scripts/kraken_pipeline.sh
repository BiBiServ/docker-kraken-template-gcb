#!/bin/bash

SCRATCHDIR=<SCRATCHDIR>
SPOOLDIR=<SPOOLDIR>

if [ $# -ne 2 ]
  then
    echo 
    echo "Usage: kraken_pipeline.sh INFILE OUTNAME"
    echo 
    echo "Reportfile will be written to $SPOOLDIR/OUTNAME.report"
    echo
    exit 0;
fi

PATH=$PATH:/vol/scripts:/vol/krona/bin

echo "Downloading FASTQ File to $SCRATCHDIR..."

download FASTQ file here...

echo "Done downloading FASTQ file."

OUTFILE=
REPORTFILE=

## run kraken
echo "running kraken:"

/vol/kraken/kraken --preload --threads $NSLOTS --db <PATH TO KRAKEN DB> --fastq-input --gzip-compressed --output <SPOOLDIR/OUTFILE> <INFILE>

echo "kraken done."

## create reports
echo "creating Kraken report"
echo "/vol/kraken/kraken-report --db $SCRATCHDIR $OUTFILE > $REPORTFILE"
/vol/kraken/kraken-report --db $SCRATCHDIR $OUTFILE > $REPORTFILE
echo "Kraken report done"

#rm -v $OUTFILE
rm -v $SCRATCHDIR/$INFILE
