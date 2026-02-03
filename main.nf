nextflow.enable.dsl=2

// Parameters
params.input       = "input_snps.csv"
params.outdir       = "results"
params.vep_cache    = "/home/law22/data/.vep"
params.genome_fa    = "/home/law22/data/LIV/Functional_Variant/Test/hg38.fa"

// Process to run LD expansion
process RUN_LD_EXPANSION {
    tag "LD_expansion"
    
    input:
    val input_file
    val output_dir

    output:
    val true, emit: done

    script:
    """
    nextflow run ${projectDir}/run_LDexpansion.nf \\
      --input ${input_file} \\
      --outdir ${output_dir}
    """
}

// Process to run VEP
process RUN_VEP_PIPELINE {
    tag "VEP_annotation"
    
    input:
    val ld_done
    val output_dir
    val vep_cache

    output:
    val true, emit: done

    script:
    """
    nextflow run ${projectDir}/run_VEP.nf \\
      --csvs "${output_dir}/ld_results/*.csv" \\
      --vcf_out "${output_dir}/vcfs" \\
      --vep_out "${output_dir}/vep" \\
      --vep_cache ${vep_cache}
    """
}

// Process to run SpliceAI
process RUN_SPLICEAI_PIPELINE {
    tag "SpliceAI_analysis"
    
    input:
    val vep_done
    val output_dir
    val genome_fa

    output:
    val true, emit: done

    script:
    """
    nextflow run ${projectDir}/run_SpliceAI.nf \\
      --vcf_out "${output_dir}/vcfs" \\
      --spliceai_out "${output_dir}/spliceai" \\
      --genome_fa ${genome_fa}
    """
}

workflow {
    // Step 1: LD Expansion
    ld_result = RUN_LD_EXPANSION(params.input, params.outdir)
    
    // Step 2: VEP (waits for LD to complete)
    vep_result = RUN_VEP_PIPELINE(ld_result.done, params.outdir, params.vep_cache)
    
    // Step 3: SpliceAI (waits for VEP to complete)
    RUN_SPLICEAI_PIPELINE(vep_result.done, params.outdir, params.genome_fa)
}