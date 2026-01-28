#!/bin/bash

# Parameters from Nextflow
INPUT_VCF="$1"
OUTPUT_FILE="$2" 
GENOME_FA="$3"

# Check if parameters are provided
if [ $# -ne 3 ]; then
    echo "Usage: $0 <input.vcf> <output.vcf> <genome.fa>"
    exit 1
fi

echo "Running SpliceAI annotation on: $INPUT_VCF"
echo "Output file: $OUTPUT_FILE"
echo "Genome reference: $GENOME_FA"

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

# Check that genome reference exists
if [ ! -f "$GENOME_FA" ]; then
    echo "ERROR: Genome reference $GENOME_FA does not exist!"
    exit 1
fi

# Run SpliceAI
spliceai -I "$INPUT_VCF" -O "$OUTPUT_FILE" -R "$GENOME_FA" -A grch38

# Check if output was created
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "ERROR: SpliceAI failed to create output file!"
    exit 1
fi

echo "SpliceAI annotation completed successfully!"

