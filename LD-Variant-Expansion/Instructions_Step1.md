Capturing LD windows
- Uses ensemblLD (1000G phase 3) in poulation-specific manner (EUR)
- r^2 threshold explicitly defined as 0.7 
- window-based LD expansion (500kb) 

This script reads in a csv of rsIDs, loops them safely to create LD windows and capture SNPs in high LD and then writes one LD file per SNP of Interest (one file for lead SNP and its high LD SNPs). 

Dependencies: conda-forge, bioconda, dplyr, readr, purr, remotes, libxml2 and xml2, ensemblQueryR (remotes::install_github("ainefairbrother/ensemblQueryR"))

Usage:
nextflow run run_LDexpansion.nf --input /path/to/your/snps.csv --outdir /path/to/output/

