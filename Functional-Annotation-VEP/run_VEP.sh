#!/bin/bash
# Parameters from Nextflow

INPUT_VCF="$1"
OUTPUT_FILE="$2" 
CACHE_DIR="$3"
PLUGINS_DIR="$4"
PLUGIN_DATA_DIR="$5"

# Check if parameters are provided
if [ $# -ne 5 ]; then
    echo "Usage: $0 <input.vcf> <output.vep.txt> <cache_dir> <plugins_dir> <plugin_data_dir>"
    exit 1
fi

echo "Running VEP annotation on: $INPUT_VCF"
echo "Output file: $OUTPUT_FILE"
echo "Cache directory: $CACHE_DIR"
echo "Plugins directory: $PLUGINS_DIR"
echo "Plugin data directory: $PLUGIN_DATA_DIR"

# Create absolute paths
CACHE_DIR_ABS=$(realpath "$CACHE_DIR")
PLUGINS_DIR_ABS=$(realpath "$PLUGINS_DIR")
PLUGIN_DATA_DIR_ABS=$(realpath "$PLUGIN_DATA_DIR")

# Resolve symlinks for VCF file - copy it to a real file if it's a symlink
if [ -L "$INPUT_VCF" ]; then
    echo "VCF file is a symlink, copying to real file..."
    cp -L "$INPUT_VCF" "${INPUT_VCF}.tmp"
    mv "${INPUT_VCF}.tmp" "$INPUT_VCF"
fi

# Check that VCF file exists and is readable
if [ ! -f "$INPUT_VCF" ]; then
    echo "ERROR: VCF file $INPUT_VCF does not exist!"
    exit 1
fi

# Check that directories exist
if [ ! -d "$CACHE_DIR_ABS" ]; then
    echo "ERROR: Cache directory $CACHE_DIR_ABS does not exist!"
    exit 1
fi

if [ ! -d "$PLUGINS_DIR_ABS" ]; then
    echo "ERROR: Plugins directory $PLUGINS_DIR_ABS does not exist!"
    exit 1
fi

if [ ! -d "$PLUGIN_DATA_DIR_ABS" ]; then
    echo "ERROR: Plugin data directory $PLUGIN_DATA_DIR_ABS does not exist!"
    exit 1
fi

# Check that AlphaMissense file exists
if [ ! -f "$PLUGIN_DATA_DIR_ABS/AlphaMissense_hg38.tsv.gz" ]; then
    echo "WARNING: AlphaMissense_hg38.tsv.gz not found in $PLUGIN_DATA_DIR_ABS"
fi

echo "Running Docker VEP..."

  #--stats_file /opt/vep/data/"$OUTPUT_FILE.html" \
  
docker run --rm \
  -u $(id -u):$(id -g) \
  -v $(pwd):/opt/vep/data \
  -v "$CACHE_DIR_ABS":/opt/vep/cache \
  -v "$PLUGINS_DIR_ABS":/opt/vep/plugins \
  -v "$PLUGIN_DATA_DIR_ABS":/opt/vep/plugin_data \
  -v "/home/kg522/data/ensembl-vep/vep_plugin_data/fasta":/opt/vep/fasta \
  ensemblorg/ensembl-vep \
  vep \
    --input_file /opt/vep/data/"$INPUT_VCF" \
    --output_file /opt/vep/data/"$OUTPUT_FILE" \
    --species homo_sapiens \
    --assembly GRCh38 \
    --cache_version 115 \
    --offline \
    --cache \
    --dir_cache /opt/vep/cache \
    --dir_plugins /opt/vep/plugins \
    --clin_sig_allele 1 \
    --symbol \
    --domains \
    --regulatory \
    --canonical \
    --protein \
    --pubmed \
    --variant_class \
    --gene_phenotype \
    --biotype \
    --mirna \
    --hgvs \
    --fasta /opt/vep/fasta/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz \
    --plugin Enformer,file=/opt/vep/plugin_data/enformer_grch38.vcf.gz \
    --plugin GeneBe \
    --plugin MaveDB,file=/opt/vep/plugin_data/MaveDB_variants.tsv.gz,single_aminoacid_changes=0 \
    --plugin OpenTargets,file=/opt/vep/plugin_data/OTGenetics.tsv.gz \
    --plugin Downstream \
    --plugin IntAct,mutation_file=/opt/vep/plugin_data/mutations.tsv,mapping_file=/opt/vep/plugin_data/mutation_gc_map.txt.gz,all=1 \
    --plugin mutfunc,db=/opt/vep/plugin_data/mutfunc_data.db \
    --plugin MechPredict,file=/opt/vep/plugin_data/MechPredict_input.tsv \
    --plugin dbNSFP,/opt/vep/plugin_data/dbNSFP5.3.1a_grch38.gz,ALL \
    --tab \
    --flag_pick_allele_gene \
    --force_overwrite
VEP_EXIT_CODE=$?

if [ $VEP_EXIT_CODE -ne 0 ]; then
    echo "ERROR: VEP failed with exit code $VEP_EXIT_CODE"
    exit $VEP_EXIT_CODE
fi

echo "VEP annotation completed successfully!"
