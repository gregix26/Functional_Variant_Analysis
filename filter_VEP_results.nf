nextflow.enable.dsl=2

params.tsv_dir = "VEP_controls"
params.vep_filter_out = "VEP_controls_filtered"

workflow {
    tsv_files = Channel.fromPath("${params.tsv_dir}/*/*.tsv", checkIfExists: true)
                       .map { file -> 
                           def lead_snp = file.parent.name  // Fixed: 'def' was split
                           tuple(lead_snp, file)
                       }
    FILTER_VEP(tsv_files)
}

process FILTER_VEP {
    tag "${lead_snp}/${tsv.simpleName}"
    
    publishDir "${params.vep_filter_out}/${lead_snp}", 
               mode: 'copy', 
               pattern: "*.filtered.tsv"
    
    input:
    tuple val(lead_snp), path(tsv)
    
    output:
    tuple val(lead_snp), path("${tsv.simpleName}.filtered.tsv"), optional: true
    
    script:
    """
    # Copy the file to ensure it's a real file, not a symlink
    cp ${tsv} input.tsv
    
    docker run --rm \
        -u \$(id -u):\$(id -g) \
        -v \$(pwd):/data \
        -w /data \
        ensemblorg/ensembl-vep \
        filter_vep \
            --input_file input.tsv \
            --output_file ${tsv.simpleName}.filtered.tsv \
            --format tab \
            --filter "(Consequence matches stop_gained|stop_lost|start_lost|frameshift_variant|splice_acceptor_variant|splice_donor_variant|missense_variant|inframe_insertion|inframe_deletion|protein_altering_variant|synonymous_variant|stop_retained_variant|start_retained_variant|incomplete_terminal_codon_variant|coding_sequence_variant|transcript_ablation|transcript_amplification|feature_elongation|feature_truncation|NMD_transcript_variant|splice_donor_5th_base_variant|splice_region_variant|splice_polypyrimidine_tract_variant)"

            
    # Count lines that DON'T start with # (actual data rows)
    data_lines=\$(grep -v "^#" ${tsv.simpleName}.filtered.tsv | wc -l)
    
    # If no data rows, remove the file
    if [ "\$data_lines" -eq 0 ]; then
        echo "No data rows found after filtering for ${lead_snp}/${tsv.simpleName}"
        rm ${tsv.simpleName}.filtered.tsv
    else
        echo "Found \$data_lines data row(s) for ${lead_snp}/${tsv.simpleName}"
    fi
    """
}
