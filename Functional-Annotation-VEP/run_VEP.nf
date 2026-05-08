nextflow.enable.dsl=2

params.csvs        = "ld_results/*.csv"
params.vcf_out     = "vcf_results"
params.vep_out     = "VEP_results"
params.vep_cache   = "/home/kg522/data/.vep"
params.vep_plugins = "/home/kg522/data/ensembl-vep/plugins"
params.vep_plugin_data = "/home/kg522/data/ensembl-vep/vep_plugin_data"

workflow {
    // Process each CSV file separately
    csv_files = Channel.fromPath(params.csvs, checkIfExists: true)
    
    // Make VCFs from each CSV
    MAKE_VCFS(csv_files)
    
    // Get the tuple output and expand it
    vcf_channel = MAKE_VCFS.out.vcfs
        .transpose()
    
    // Run VEP on each VCF
    RUN_VEP(vcf_channel)
}



process MAKE_VCFS {
    tag "${csv.baseName}"
    publishDir "${params.vcf_out}/${csv.baseName}", 
               mode: 'copy', 
               pattern: "*.{vcf,tsv}",
               saveAs: { filename -> 
                   // Only save if we actually created files
                   filename.endsWith('.vcf') || filename.endsWith('.tsv') ? filename : null
               }
    conda 'conda-forge::r-base conda-forge::r-dplyr conda-forge::r-readr conda-forge::r-biomart conda-forge::r-data.table'
    
    input:
    path csv
    
    output:
    tuple val("${csv.baseName}"), path("*.vcf"), optional: true, emit: vcfs
    path "*.tsv", optional: true, emit: summary
    
    script:
    """
    mkdir -p ld_results
    mkdir -p vcfs
    cp ${csv} ld_results/
    
    echo "=== Processing ${csv.baseName} ==="
    
    Rscript ${projectDir}/Functional-Annotation-VEP/dsSNP_hg38_csvtovcf.R 
    
    # Check if any VCFs were created
    vcf_count=\$(ls vcfs/*.vcf 2>/dev/null | wc -l)
    
    if [ \$vcf_count -eq 0 ]; then
        echo "WARNING: No VCFs created for ${csv.baseName} - skipping"
        echo "This CSV had no valid SNPs in LD"
        
        # Create an empty summary file to document this
        echo -e "SNP_ID\tVCF_FILE\tSOURCE_CSV\tSTATUS" > ${csv.baseName}_summary.tsv
        echo -e "N/A\tN/A\t${csv}\tNO_SNPS_IN_LD" >> ${csv.baseName}_summary.tsv
        
        # Don't fail - just continue
        exit 0
    else
        mv vcfs/*.vcf .
        
        # Create summary TSV
        echo -e "SNP_ID\tVCF_FILE\tSOURCE_CSV\tSTATUS" > ${csv.baseName}_summary.tsv
        for vcf_file in *.vcf; do
            snp_id=\$(basename "\$vcf_file" .vcf)
            echo -e "\$snp_id\t\$vcf_file\t${csv}\tSUCCESS" >> ${csv.baseName}_summary.tsv
        done
        
        echo "Created \$vcf_count VCF files for ${csv.baseName}"
    fi
    """
}

process RUN_VEP {
    tag "${csv_name}/${vcf.simpleName}"
    publishDir "${params.vep_out}/${csv_name}", 
               mode: 'copy', 
               pattern: "*.tsv"
    container 'ensemblorg/ensembl-vep'
    
    input:
    tuple val(csv_name), path(vcf)
    
    output:
    path "${vcf.simpleName}.vep.tsv"
    
    script:
    """
    ${projectDir}/Functional-Annotation-VEP/run_VEP_hg38.sh \
        ${vcf} \
        ${vcf.simpleName}.vep.tsv \
        ${params.vep_cache} \ 
        ${params.vep_plugins} \
        ${params.vep_plugin_data}
    """
}
