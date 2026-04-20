# -------- paths --------
csv_dir   <- "ld_results"
out_dir   <- "vcfs"
dbsnp_vcf <- "/home/dsSNP_hg19/00-All.vcf.gz"
dir.create(out_dir, showWarnings = FALSE)

cat("Starting CSV to VCF conversion (dbSNP hg19)...\n")

# Sanity-check that bcftools can see the VCF index
tbi <- paste0(dbsnp_vcf, ".tbi")
if (!file.exists(tbi)) {
  stop("Tabix index not found: ", tbi,
       "\nRun: bcftools index -t ", dbsnp_vcf)
}

# -------- list CSV files --------
csv_files <- list.files(csv_dir, pattern = "\\.csv$", full.names = TRUE)
if (length(csv_files) == 0) stop("No CSV files found in: ", csv_dir)

# -------- helper: extract SNPs from dbSNP using bcftools --------
get_snp_info <- function(snps) {
  cat("  Querying dbSNP (targeted)...\n")

  tmp_ids <- tempfile(fileext = ".txt")
  tmp_out <- tempfile(fileext = ".tsv")
  on.exit(unlink(c(tmp_ids, tmp_out)), add = TRUE)

  fwrite(data.table(snps), tmp_ids, col.names = FALSE)

  # FIX: build the command as a single string with correct quoting.
  # The -i filter expression must be one unbroken shell token.
  cmd <- paste0(
    "bcftools view",
    " -i 'ID=@", tmp_ids, "'",      # note: single = is valid bcftools syntax
    " ", shQuote(dbsnp_vcf),
    " | bcftools query -f '%CHROM\\t%POS\\t%ID\\t%REF\\t%ALT\\n'",
    " > ", tmp_out
  )

  ret <- system(cmd)
  if (ret != 0) cat("  bcftools returned non-zero exit code:", ret, "\n")

  if (!file.exists(tmp_out) || file.info(tmp_out)$size == 0) {
    cat("  No matching SNPs found\n")
    return(NULL)
  }

  dt <- fread(tmp_out, header = FALSE,
              col.names = c("CHROM", "POS", "ID", "REF", "ALT"))

  # FIX: strip 'chr' prefix if present (some dbSNP builds use chr1, chr2 …)
  dt[, CHROM := sub("^chr", "", CHROM)]

  return(dt)
}

# -------- helper: write single SNP VCF --------
write_single_snp_vcf <- function(row, out_file) {
  header <- c(
    "##fileformat=VCFv4.2",
    "##reference=GRCh37",
    "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO"
  )
  writeLines(header, out_file)

  # FIX: add placeholder QUAL / FILTER / INFO columns so the VCF is valid
  row_out <- copy(row)
  row_out[, c("QUAL", "FILTER", "INFO") := list(".", ".", ".")]
  fwrite(row_out[, .(CHROM, POS, ID, REF, ALT, QUAL, FILTER, INFO)],
         out_file, sep = "\t", append = TRUE, col.names = FALSE)
}

# -------- main loop --------
total_vcfs_created <- 0

for (csv in csv_files) {
  cat("\n=== Processing", basename(csv), "===\n")

  ld <- fread(csv)
  required_cols <- c("snp_in_ld", "index_snp")

  if (!all(required_cols %in% colnames(ld))) {
    cat("  Missing required columns; skipping\n")
    next
  }

  snps <- unique(c(ld$index_snp, ld$snp_in_ld))
  snps <- snps[!is.na(snps) & nzchar(snps)]
  cat("  SNPs to query:", length(snps), "\n")
  if (length(snps) == 0) next

  # ---- query dbSNP ----
  snp_info <- get_snp_info(snps)

  if (is.null(snp_info) || nrow(snp_info) == 0) {
    cat("  No SNPs found in dbSNP\n")
    next
  }

  # keep autosomes + sex chromosomes only
  snp_info <- snp_info[CHROM %in% c(as.character(1:22), "X", "Y")]
  cat("  Found", nrow(snp_info), "valid SNPs\n")

  # ---- write one VCF per SNP ----
  vcfs_this_file <- 0
  for (i in seq_len(nrow(snp_info))) {
    row     <- snp_info[i]
    out_vcf <- file.path(out_dir, paste0(row$ID, ".vcf"))
    write_single_snp_vcf(row, out_vcf)
    vcfs_this_file <- vcfs_this_file + 1
  }

  cat("  Created", vcfs_this_file, "VCFs\n")
  total_vcfs_created <- total_vcfs_created + vcfs_this_file
}

# -------- summary --------
cat("\n=== SUMMARY ===\n")
cat("Total VCFs created:", total_vcfs_created, "\n")
