nextflow.enable.dsl=2

params.input = "pathtoSNPlist?input_snps.csv" //File containing list of SNps (one per line)
params.outdir = "results/ld" //Directory to store LD output files

process LD_EXPANSION {

    tag "$input_csv"

    input:
    path input_csv

    output:
    path "${params.outdir}/*"

    script:
    """
    Rscript LD Variant Expression/LD_SNP_list.R ${input_csv} ${params.outdir}
    """
}

workflow {
    LD_EXPANSION(params.input)
}
