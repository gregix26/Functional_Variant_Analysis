#!/bin/bash

# Parameters from Nextflow
INPUT_VCF="$1"
OUTPUT_FILE="$2" 
CACHE_DIR="$3"

# Check if parameters are provided
if [ $# -ne 3 ]; then
    echo "Usage: $0 <input.vcf> <output.vep.txt> <cache_dir>"
    exit 1
fi

echo "Running VEP annotation on: $INPUT_VCF"
echo "Output file: $OUTPUT_FILE"
echo "Cache directory: $CACHE_DIR"

# Create absolute path for cache directory
CACHE_DIR_ABS=$(realpath "$CACHE_DIR")

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

docker run --rm \
  -u $(id -u):$(id -g) \
  -v $(pwd):/opt/vep/data \
  -v "$CACHE_DIR_ABS":/opt/vep/cache \
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
  --regulatory \
  --protein \
  --polyphen b \
  --sift b \
  --gene_phenotype \
  --force_overwrite


