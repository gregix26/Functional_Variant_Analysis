Step 1: Capturing LD windows
- Uses ensemblLD (1000G phase 3) in poulation-specific manner (EUR)
- r^2 threshold explicitly defined as 0.9 
- window-based LD expansion (500kb) 

This script reads in a csv of rsIDs, loops them safely to create LD windows and capture SNPs in high LD and then writes one LD file per SNP of Interest. 

To only run LD expansion step: 
Make sure that conda-forge and bioconda are installed in current environment.

nextflow run run_LDexpansion.nf --input /path/to/your/snps.csv --outdir /path/to/output/

