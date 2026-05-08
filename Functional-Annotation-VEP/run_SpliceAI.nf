nextflow.enable.dsl=2

params.vcf_out     = "results/vcfs"
params.spliceai_out = "results/spliceai"
params.genome_fa   = "/home/law22/data/LIV/Functional_Variant/Test/hg38.fa"  // You'll need to set this path

workflow {
    // Use existing VCF files from VEP pipeline
    vcf_files = Channel.fromPath("${params.vcf_out}/*.vcf", checkIfExists: true)
    
    // Run SpliceAI on each existing VCF
    RUN_SPLICEAI(vcf_files)
}

process RUN_SPLICEAI {
    tag "${vcf.simpleName}"
    
    publishDir params.spliceai_out, mode: 'copy'
    
    conda 'bioconda::spliceai'
    
    input:
    path vcf

    output:
    path "${vcf.simpleName}.spliceai.vcf"

    script:
    """
    ${projectDir}/Functional-Annotation-VEP/run_SpliceAI.sh \\
        ${vcf} \\
        ${vcf.simpleName}.spliceai.vcf \\
        ${params.genome_fa}
    """
}