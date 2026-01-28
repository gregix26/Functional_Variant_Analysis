## Run VEP as an initial step of functional annotation 

First, the VEP cache has to be downloaded: 
git clone https://github.com/Ensembl/ensembl-vep.git
cd ensembl-vep

To test that VEP is properly installed and working, run the following command in the ensmbl-vep folder: 
docker run --rm \
  -v /home/USER/data:/data \
  ensemblorg/ensembl-vep \
  vep --help | head

Then add execute permission to run_VEP.sh script with chmod +x  

The following packages also need to be installed for this step to work properly: 
biomaRt, data.table


In case ensembl server is down --> use convert_csvtovcf_robust.R script to connect to any of the servers
In case there is an issue with the vep cache --> download homosapiens ref dataset manually from https://ftp.ensembl.org/pub/release-115/variation/indexed_vep_cache/

# Command to run this step 
nextflow run run_VEP.nf -resume --csvs "/home/law22/data/LIV/Functional_Variant/Test/ld_results/*.csv" --vcf_out "/home/law22/data/LIV/Functional_Variant/Test/ld_results/vcfs" --vep_out "/home/law22/data/LIV/Functional_Variant/Test/results_vep" --vep_cache "/home/law22/data/LIV/scripts/ensembl-vep"

## Run SpliceAI as a second step of functional annotation 

First, SpliceAI needs to be installed. The simplest way to do this is with conda install -c bioconda spliceai. Alternatively, the github repository can be cloned git clone https://github.com/Illumina/SpliceAI.git

tensorflow (>=1.2.0) also needs to be installed. 

A reference genome file is also needed, available at http://hgdownload.cse.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz



