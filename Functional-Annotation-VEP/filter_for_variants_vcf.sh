#!/bin/bash
# Usage: ./filter_vcfs.sh <csv_file> <input_vcf_dir> <output_base_dir>
# CSV should have columns: Lead_SNP, Uploaded_variation
set -e  # Exit on error

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <csv_file> <input_vcf_dir> <output_base_dir>"
    echo "Example: $0 variants.csv /path/to/vcfs /path/to/output"
    exit 1
fi

CSV_FILE="$1"
INPUT_VCF_DIR="$2"
OUTPUT_BASE_DIR="$3"

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file not found: $CSV_FILE"
    exit 1
fi

# Check if input VCF directory exists
if [ ! -d "$INPUT_VCF_DIR" ]; then
    echo "Error: Input VCF directory not found: $INPUT_VCF_DIR"
    exit 1
fi

# Create output base directory if it doesn't exist
mkdir -p "$OUTPUT_BASE_DIR"

echo "Processing variants from: $CSV_FILE"
echo "Input VCF directory: $INPUT_VCF_DIR"
echo "Output base directory: $OUTPUT_BASE_DIR"
echo ""

# Skip header line and process each row
tail -n +2 "$CSV_FILE" | while IFS=',' read -r lead_snp uploaded_variation rest; do
    # Remove quotes and whitespace
    lead_snp=$(echo "$lead_snp" | tr -d '"' | tr -d ' ')
    uploaded_variation=$(echo "$uploaded_variation" | tr -d '"' | tr -d ' ')

    echo "Processing: Lead_SNP=$lead_snp, Uploaded_variation=$uploaded_variation"

    # Create output directory structure: output_base/Lead_SNP/Uploaded_variation/
    OUTPUT_DIR="$OUTPUT_BASE_DIR/$lead_snp/$uploaded_variation"
    mkdir -p "$OUTPUT_DIR"

    # Find all VCF files in input directory (including subdirectories)
    find "$INPUT_VCF_DIR" -type f \( -name "*.vcf" -o -name "*.vcf.gz" \) | while read -r vcf_file; do
        vcf_basename=$(basename "$vcf_file")
        output_vcf="$OUTPUT_DIR/$vcf_basename"

        # Check if both variants are present in the VCF file
        if grep -q "$uploaded_variation" "$vcf_file"; then
            echo "  Found variants in: $vcf_basename"
            # Copy the entire VCF file
            cp "$vcf_file" "$output_vcf"
            echo "    Copied to: $output_vcf"
        fi
    done

    echo ""
done

echo "Processing complete!"
echo "Output directory: $OUTPUT_BASE_DIR"
