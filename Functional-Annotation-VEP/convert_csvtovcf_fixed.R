library(data.table)
library(biomaRt)

# -------- paths --------
csv_dir  <- "ld_results"          # directory with LD_*.csv
out_dir  <- "vcfs"                # where VCFs will be written
dir.create(out_dir, showWarnings = FALSE)

cat("Starting CSV to VCF conversion...\n")

# -------- list CSV files --------
csv_files <- list.files(
  csv_dir,
  pattern = "\\.csv$",
  full.names = TRUE
)

cat("Found CSV files:", length(csv_files), "\n")
if (length(csv_files) == 0) {
  stop("No CSV files found in directory: ", csv_dir)
}

# -------- connect to Ensembl (FIXED: use GRCh37) --------
cat("Connecting to Ensembl biomaRt...\n")
tryCatch({
  ensembl <- useEnsembl(
    biomart = "snp",
    dataset = "hsapiens_snp",
    GRCh = 37  # FIXED: changed from 38 to 37
  )
  cat("Successfully connected to Ensembl\n")
}, error = function(e) {
  cat("Error connecting to Ensembl:", e$message, "\n")
  stop("Failed to connect to biomaRt")
})

# -------- helper: write single SNP VCF --------
write_single_snp_vcf <- function(snp_id, out_file, snp_info) {
  
  row <- snp_info[refsnp_id == snp_id]
  if (nrow(row) == 0) {
    cat("  Warning: No info found for SNP", snp_id, "\n")
    return(NULL)
  }

  vcf <- data.table(
    CHROM  = paste0("chr", row$chr_name),
    POS    = row$chrom_start,
    ID     = row$refsnp_id,
    REF    = row$REF,
    ALT    = row$ALT,
    QUAL   = ".",
    FILTER = "PASS",
    INFO   = "."
  )

  header <- c(
    "##fileformat=VCFv4.2",
    "##reference=GRCh37",  # FIXED: changed from GRCh38
    "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO"
  )

  writeLines(header, out_file)
  fwrite(vcf, out_file, sep = "\t", append = TRUE, col.names = FALSE)
  cat("  Created VCF for", snp_id, "\n")
}

# -------- main loop over CSVs --------
total_vcfs_created <- 0

for (csv in csv_files) {
  
  cat("\n=== Processing", basename(csv), "===\n")
  
  # Read CSV with error handling
  tryCatch({
    ld <- fread(csv)
    cat("  Loaded", nrow(ld), "rows from CSV\n")
  }, error = function(e) {
    cat("  Error reading CSV:", e$message, "\n")
    next
  })
  
  # Check if required columns exist
  required_cols <- c("snp_in_ld")
  missing_cols <- setdiff(required_cols, colnames(ld))
  if (length(missing_cols) > 0) {
    cat("  Error: Missing columns:", paste(missing_cols, collapse = ", "), "\n")
    cat("  Available columns:", paste(colnames(ld), collapse = ", "), "\n")
    next
  }
  
  # Get unique SNPs
  snps <- unique(ld$snp_in_ld)
  snps <- snps[!is.na(snps)]  # Remove any NA values
  
  cat("  Found", length(snps), "unique SNPs to process\n")
  
  if (length(snps) == 0) {
    cat("  No valid SNPs found in this file\n")
    next
  }
  
  # Query Ensembl with error handling and chunking
  cat("  Querying Ensembl for SNP information...\n")
  
  tryCatch({
    # Query in chunks to avoid timeout
    chunk_size <- 50
    all_snp_info <- NULL
    
    for (i in seq(1, length(snps), chunk_size)) {
      end_idx <- min(i + chunk_size - 1, length(snps))
      chunk_snps <- snps[i:end_idx]
      
      cat("    Querying chunk", ceiling(i/chunk_size), ":", length(chunk_snps), "SNPs\n")
      
      chunk_info <- getBM(
        attributes = c(
          "refsnp_id",
          "chr_name",
          "chrom_start",
          "allele"
        ),
        filters = "snp_filter",
        values = chunk_snps,
        mart = ensembl
      )
      
      all_snp_info <- rbind(all_snp_info, chunk_info)
    }
    
    snp_info <- as.data.table(all_snp_info)
    cat("  Retrieved info for", nrow(snp_info), "SNPs from Ensembl\n")
    
  }, error = function(e) {
    cat("  Error querying Ensembl:", e$message, "\n")
    next
  })
  
  if (nrow(snp_info) == 0) {
    cat("  No SNP information retrieved from Ensembl\n")
    next
  }
  
  # FIXED: Clean alleles with better error handling
  cat("  Processing allele information...\n")
  
  # Filter for valid alleles first
  snp_info <- snp_info[!is.na(allele) & allele != ""]
  
  if (nrow(snp_info) == 0) {
    cat("  No valid alleles found\n")
    next
  }
  
  # Check for alleles with "/" separator
  valid_alleles <- snp_info[grepl("/", allele)]
  cat("  Found", nrow(valid_alleles), "SNPs with valid allele format\n")
  
  if (nrow(valid_alleles) == 0) {
    cat("  No SNPs with proper allele format (A/T) found\n")
    next
  }
  
  # Split alleles
  alleles <- tstrsplit(valid_alleles$allele, "/", fixed = TRUE)
  valid_alleles[, REF := alleles[[1]]]
  valid_alleles[, ALT := alleles[[2]]]
  
  # Keep autosomes + sex chromosomes
  final_snp_info <- valid_alleles[
    chr_name %in% c(as.character(1:22), "X", "Y")
  ]
  
  cat("  Final SNPs for VCF creation:", nrow(final_snp_info), "\n")
  
  # Write one VCF per SNP
  vcfs_this_file <- 0
  for (snp in unique(final_snp_info$refsnp_id)) {
    out_vcf <- file.path(out_dir, paste0(snp, ".vcf"))
    result <- write_single_snp_vcf(snp, out_vcf, final_snp_info)
    if (!is.null(result)) {
      vcfs_this_file <- vcfs_this_file + 1
    }
  }
  
  cat("  Created", vcfs_this_file, "VCF files for this CSV\n")
  total_vcfs_created <- total_vcfs_created + vcfs_this_file
}

cat("\n=== SUMMARY ===\n")
cat("Total VCF files created:", total_vcfs_created, "\n")

# List created files
vcf_files <- list.files(out_dir, pattern = "\\.vcf$")
cat("VCF files in output directory:", length(vcf_files), "\n")

if (length(vcf_files) > 0) {
  cat("Sample VCF files created:\n")
  cat(paste("  ", head(vcf_files, 5), collapse = "\n"), "\n")
  
  if (length(vcf_files) > 5) {
    cat("  ... and", length(vcf_files) - 5, "more\n")
  }
} else {
  stop("No VCF files were created!")
}

cat("CSV to VCF conversion completed successfully!\n")
