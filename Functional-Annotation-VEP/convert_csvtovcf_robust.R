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

# -------- helper: connect to Ensembl with host fallbacks --------
# Called fresh for each CSV to avoid stale sessions.
# GRCh38 is the default/current assembly.
# The mirror argument cannot be combined with GRCh/version, so we use
# useMart() with explicit hosts instead of useEnsembl() + mirror.
connect_ensembl <- function() {
  hosts <- c(
    "https://www.ensembl.org",
    "https://uswest.ensembl.org",
    "https://useast.ensembl.org",
    "https://asia.ensembl.org"
  )
  
  for (host in hosts) {
    cat("  Trying Ensembl host:", host, "\n")
    ensembl <- tryCatch({
      useMart(
        biomart = "ENSEMBL_MART_SNP",
        dataset = "hsapiens_snp",
        host    = host
      )
    }, error = function(e) {
      cat("  Failed to connect to", host, ":", e$message, "\n")
      NULL
    })
    
    if (!is.null(ensembl)) {
      cat("  Successfully connected via", host, "\n")
      return(ensembl)
    }
  }
  
  return(NULL)  # All hosts failed
}

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
    "##reference=GRCh38",
    "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO"
  )
  
  writeLines(header, out_file)
  fwrite(vcf, out_file, sep = "\t", append = TRUE, col.names = FALSE)
  cat("  Created VCF for", snp_id, "\n")
  return(snp_id)
}

# -------- main loop over CSVs --------
total_vcfs_created <- 0

for (csv in csv_files) {
  
  cat("\n=== Processing", basename(csv), "===\n")
  
  # Read CSV
  ld <- tryCatch({
    fread(csv)
  }, error = function(e) {
    cat("  Error reading CSV:", e$message, "\n")
    NULL
  })
  
  if (is.null(ld)) {
    cat("  Skipping", basename(csv), "due to read error\n")
    next
  }
  
  cat("  Loaded", nrow(ld), "rows from CSV\n")
  
  # Check required columns
  required_cols <- c("snp_in_ld", "index_snp")
  missing_cols  <- setdiff(required_cols, colnames(ld))
  if (length(missing_cols) > 0) {
    cat("  Error: Missing columns:", paste(missing_cols, collapse = ", "), "\n")
    cat("  Available columns:", paste(colnames(ld), collapse = ", "), "\n")
    next
  }
  
  # Collect unique SNPs from both columns; NAs (lead SNPs with no LD partners) are dropped
  # but the index_snp itself is always included
  snps <- unique(c(ld$index_snp, ld$snp_in_ld))
  snps <- snps[!is.na(snps)]
  
  cat("  Found", length(snps), "unique SNPs to process (including index_snp)\n")
  
  if (length(snps) == 0) {
    cat("  WARNING: No valid SNPs found for", basename(csv), "- skipping\n")
    next  # Skip this CSV only; do NOT quit the session
  }
  
  # ---- Fresh Ensembl connection for each CSV ----
  cat("  Connecting to Ensembl for", basename(csv), "...\n")
  ensembl <- connect_ensembl()
  
  if (is.null(ensembl)) {
    # Hard error: refuse to create fake-coordinate VCFs
    stop(
      "Could not connect to any Ensembl mirror while processing ", basename(csv),
      ". Aborting to prevent fake coordinates from entering VEP. ",
      "Check your network connection and rerun."
    )
  }
  
  # ---- Query Ensembl in chunks with retry ----
  cat("  Querying Ensembl for SNP information...\n")
  
  chunk_size  <- 20
  max_retries <- 3
  all_snp_info <- NULL
  
  for (i in seq(1, length(snps), chunk_size)) {
    end_idx    <- min(i + chunk_size - 1, length(snps))
    chunk_snps <- snps[i:end_idx]
    
    cat("    Querying chunk", ceiling(i / chunk_size), ":", length(chunk_snps), "SNPs\n")
    
    chunk_info <- NULL
    
    for (retry in seq_len(max_retries)) {
      chunk_info <- tryCatch({
        getBM(
          attributes = c("refsnp_id", "chr_name", "chrom_start", "allele"),
          filters    = "snp_filter",
          values     = chunk_snps,
          mart       = ensembl
        )
      }, error = function(e) {
        cat("      Attempt", retry, "failed:", e$message, "\n")
        NULL
      })
      
      if (!is.null(chunk_info)) break
      
      if (retry < max_retries) {
        wait <- 2 ^ retry  # Exponential backoff: 2s, 4s
        cat("      Waiting", wait, "s before retry...\n")
        Sys.sleep(wait)
        
        # Reconnect before retrying — session may have gone stale
        cat("      Reconnecting to Ensembl before retry...\n")
        ensembl <- connect_ensembl()
        if (is.null(ensembl)) {
          stop(
            "Lost Ensembl connection during chunk query for ", basename(csv),
            " (chunk starting at SNP index ", i, "). ",
            "Aborting to prevent fake coordinates."
          )
        }
      }
    }
    
    if (is.null(chunk_info)) {
      stop(
        "Failed to retrieve Ensembl data for chunk starting at SNP index ", i,
        " in ", basename(csv), " after ", max_retries, " attempts. ",
        "Aborting to prevent fake coordinates."
      )
    }
    
    all_snp_info <- rbind(all_snp_info, chunk_info)
  }
  
  snp_info <- as.data.table(all_snp_info)
  cat("  Retrieved info for", nrow(snp_info), "SNPs from Ensembl\n")
  
  if (nrow(snp_info) == 0) {
    cat("  No SNP information retrieved from Ensembl for", basename(csv), "- skipping\n")
    next
  }
  
  # ---- Process alleles ----
  cat("  Processing allele information...\n")
  
  snp_info <- snp_info[!is.na(allele) & allele != ""]
  valid_alleles <- snp_info[grepl("/", allele)]
  
  cat("  Found", nrow(valid_alleles), "SNPs with valid allele format\n")
  
  if (nrow(valid_alleles) == 0) {
    cat("  No SNPs with proper allele format (A/T) found for", basename(csv), "- skipping\n")
    next
  }
  
  alleles <- tstrsplit(valid_alleles$allele, "/", fixed = TRUE)
  valid_alleles[, REF := alleles[[1]]]
  valid_alleles[, ALT := alleles[[2]]]
  
  final_snp_info <- valid_alleles[
    chr_name %in% c(as.character(1:22), "X", "Y")
  ]
  
  cat("  Final SNPs for VCF creation:", nrow(final_snp_info), "\n")
  
  # ---- Write one VCF per SNP ----
  vcfs_this_file <- 0
  for (snp in unique(final_snp_info$refsnp_id)) {
    out_vcf <- file.path(out_dir, paste0(snp, ".vcf"))
    result  <- write_single_snp_vcf(snp, out_vcf, final_snp_info)
    if (!is.null(result)) {
      vcfs_this_file <- vcfs_this_file + 1
    }
  }
  
  cat("  Created", vcfs_this_file, "VCF files for", basename(csv), "\n")
  total_vcfs_created <- total_vcfs_created + vcfs_this_file
}

# -------- Summary --------
cat("\n=== SUMMARY ===\n")
cat("Total VCF files created across all CSVs:", total_vcfs_created, "\n")

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
