for vcf in /home/law22/data/LIV/Functional_Variant/Test/ld_results/vcfs/*.vcf; do
  base=$(basename "$vcf" .vcf)

  docker run --rm \
    -u $(id -u):$(id -g) \
    -v /home/law22/data:/data \
    ensemblorg/ensembl-vep \
    vep \
    --input_file /data/SNP_Input/vcfs/${base}.vcf \
    --output_file /data/VEP_results/output.vep_${base}.txt \
    --species homo_sapiens \
    --assembly GRCh38 \
    --offline \
    --cache \
    --dir_cache /data/.vep \
    --regulatory \
    --protein \
    --polyphen b \
    --gene_phenotype \
    --use_given_ref
done


