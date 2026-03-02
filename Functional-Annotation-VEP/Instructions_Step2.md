# Run VEP as an initial step of functional annotation 

First, the VEP cache has to be downloaded: 
git clone https://github.com/Ensembl/ensembl-vep.git

To test that VEP is properly installed and working, run the following command in the ensmbl-vep folder: 
docker run --rm \
  -v /home/USER/data:/data \
  ensemblorg/ensembl-vep \
  vep --help | head

Then add execute permission to run_VEP.sh and run_SpliceAI.sh script with chmod +x  

The following packages also need to be installed for this step to work properly: 
biomaRt, data.table

In case ensembl server is down --> use convert_csvtovcf_robust.R script to connect to any of the servers
In case there is an issue with the vep cache --> download homosapiens ref dataset (hg38) manually from https://ftp.ensembl.org/pub/release-115/variation/indexed_vep_cache/ (no need to install VEP itself)

## Command to run VEP - gives you an output directory with lead SNP subdirectory and all their high LD SNPs and their VEP results in tab columns 
nextflow run run_VEP.nf 
--csvs '/home/kg522/data/Functional-Variants/LD_Expansion_Results/full_dataset/ld_results/*.csv' 
--vcf_out /home/kg522/data/Functional-Variants/LD_Expansion_Results/case_vcfs 
--vep_out /home/kg522/data/Functional-Variants/[output_file]
--vep_cache /home/kg522/data/ensembl-vep

## You can filter VEP results with VEP - specify what you want to filter for (example: coding variants)
nextflow run filter_VEP.nf 
--tsv_dir /home/kg522/data/Functional-Variants/VEP_case 
--vep_filter_out /home/kg522/data/[output_file]

## To merges the tsv files of tsv VEP results per variant, run this (gives one comprehensive csv file of all variants and their VEP columns)
./merge_tsv_horizontal.sh [parent_directory] [output_file]

## To select for particular variants and make a new directory with just those variants (for example, a subset of variants to run spliceAI on)

./filter_for_spliceai.sh /home/kg522/data/Functional-Variants/spliceIA_input/control/control_splicing_variants.csv /home/kg522/data/Functional-Variants/vep_control_260226 /home/kg522/data/Functional-Variants/spliceai_control_vcf

# On filtered splice variants, run SpliceAI

First, SpliceAI needs to be installed. The simplest way to do this is with conda install -c bioconda spliceai. Alternatively, the github repository can be cloned git clone https://github.com/Illumina/SpliceAI.git

tensorflow (>=1.2.0) also needs to be installed. 

A reference genome file is also needed, available at http://hgdownload.cse.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz





