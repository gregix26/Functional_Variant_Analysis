#!/bin/bash

# Script to merge TSV files from subdirectories horizontally
# Merges files based on common header (only one header row)
# Adds source subdirectory name as first column
# Usage: ./merge_tsv_horizontal.sh [parent_directory] [output_file]

# Set default values
PARENT_DIR="${1:-.}"
OUTPUT_FILE="${2:-merged_output.tsv}"

# Remove output file if it exists
rm -f "$OUTPUT_FILE"

# Temporary files
TEMP_DIR=$(mktemp -d)
ALL_FILES="$TEMP_DIR/all_files.txt"
HEADER_FILE="$TEMP_DIR/header.txt"

echo "Processing TSV files in: $PARENT_DIR"
echo "Output will be written to: $OUTPUT_FILE"
echo ""

# Collect all TSV files with their subdirectory names
> "$ALL_FILES"
for subdir in "$PARENT_DIR"/*/; do
    [ -d "$subdir" ] || continue
    
    subdir_name=$(basename "$subdir")
    echo "Found subdirectory: $subdir_name"
    
    for tsv_file in "$subdir"*.tsv; do
        [ -f "$tsv_file" ] || continue
        filename=$(basename "$tsv_file")
        echo "  - Found file: $filename"
        echo "$subdir_name|$tsv_file" >> "$ALL_FILES"
    done
done

# Check if any files were found
if [ ! -s "$ALL_FILES" ]; then
    echo "Error: No TSV files found in subdirectories!"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo ""
echo "Extracting headers and data..."

# Extract header from first file (the single # line, not ## lines)
FIRST_FILE=$(head -n 1 "$ALL_FILES" | cut -d'|' -f2)
HEADER=$(grep "^#[^#]" "$FIRST_FILE")

# Write header with Lead_SNP column (strip the leading # and add Lead_SNP)
echo -e "Lead_SNP\t$(echo "$HEADER" | sed 's/^#//')" > "$OUTPUT_FILE"

# Process each file and append data
while IFS='|' read -r subdir_name tsv_file; do
    filename=$(basename "$tsv_file")
    echo "Processing: $subdir_name / $filename"

    # Skip ## metadata lines, skip # header lines, skip empty lines
    grep -v "^#" "$tsv_file" | grep -v "^$" | while IFS= read -r line; do
        echo -e "${subdir_name}\t${line}" >> "$OUTPUT_FILE"
    done

done < "$ALL_FILES"

# Clean up
rm -rf "$TEMP_DIR"

echo ""
echo "✓ Merging complete!"
echo "✓ Output saved to: $OUTPUT_FILE"
