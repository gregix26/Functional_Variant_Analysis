nextflow.enable.dsl=2

params.input = "pathtoSNPlist/input_snps.csv" // File containing list of SNPs (one per line)
params.outdir = "results/" // Directory to store LD output files

process LD_EXPANSION {
    tag "$input_csv"
    
    publishDir "${params.outdir}", mode: 'copy'
    
    conda 'bioconda::r-base conda-forge::r-dplyr conda-forge::r-readr conda-forge::r-purrr bioconda::r-ensemblqueryr'
    
    input:
    path input_csv

    output:
    path "ld_results/*", emit: ld_files
    path "ld_results", emit: outdir

    script:
    """
    mkdir -p ld_results
    Rscript ${projectDir}/scripts/Functional_Variant_Analysis/LD-Variant-Expansion/LD_SNP_list.R ${input_csv} ld_results
    """
}

workflow {
    input_ch = Channel.fromPath(params.input, checkIfExists: true)  //validates that input files exist 
    LD_EXPANSION(input_ch)
}