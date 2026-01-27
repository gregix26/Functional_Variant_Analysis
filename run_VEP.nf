nextflow.enable.dsl=2

params.csvs        = "ld_results/*.csv"
params.vcf_out     = "results/vcfs"
params.vep_out     = "results/vep"
params.vep_cache   = "/home/law22/data/.vep"

workflow {
    // Collect all CSV files into a single channel
    csv_files = Channel.fromPath(params.csvs, checkIfExists: true).collect()
    
    // Make VCFs from all CSVs at once
    vcfs = MAKE_VCFS(csv_files)
    
    // Flatten the VCF channel and run VEP on each
    RUN_VEP(vcfs.flatten())
}

process MAKE_VCFS {
    publishDir params.vcf_out, mode: 'copy'
    
    conda 'conda-forge::r-base conda-forge::r-dplyr conda-forge::r-readr conda-forge::r-biomart conda-forge::r-data.table'
    
    input:
    path csv_files

    output:
    path "*.vcf"

    script:
    """
    # Create the expected directory structure
    mkdir -p ld_results
    
    # Copy CSV files with explicit names to avoid globbing issues
    for csv in ${csv_files}; do
        cp "\${csv}" ld_results/
    done
    
    # List what we have for debugging
    echo "CSV files in ld_results:"
    ls -la ld_results/
    
    # Run the ROBUST R script with mirror fallbacks
    Rscript ${projectDir}/Functional-Annotation-VEP/convert_csvtovcf_robust.R
    
    # List VCFs created
    echo "VCFs created:"
    ls -la vcfs/
    
    # Move VCFs to process output directory
    if [ -d "vcfs" ] && [ "\$(ls -A vcfs)" ]; then
        mv vcfs/*.vcf .
    else
        echo "No VCF files were created"
        exit 1
    fi
    """
}

process RUN_VEP {
    tag "${vcf.simpleName}"
    
    publishDir params.vep_out, mode: 'copy'
    
    container 'ensemblorg/ensembl-vep'

    input:
    path vcf

    output:
    path "${vcf.simpleName}.vep.txt"

    script:
    """
    ${projectDir}/Functional-Annotation-VEP/run_VEP.sh \\
        ${vcf} \\
        ${vcf.simpleName}.vep.txt \\
        ${params.vep_cache}
    """
}
