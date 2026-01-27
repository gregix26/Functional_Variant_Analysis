library(data.table)
library(biomaRt)

# -------- paths --------
csv_dir  <- "ld_results"          # directory with LD_*.csv
out_dir  <- "vcfs"                # where VCFs will be written
dir.create(out_dir, showWarnings = FALSE)

# -------- list CSV files --------
csv_files <- list.files(
  csv_dir,
  pattern = "\\.csv$",
  full.names = TRUE
)

# -------- connect to Ensembl once --------
ensembl <- useEnsembl(
  biomart = "snp",
  dataset = "hsapiens_snp",
  GRCh = 38
)

# -------- helper: write single SNP VCF --------
write_single_snp_vcf <- function(snp_id, out_file, snp_info) {

  row <- snp_info[refsnp_id == snp_id]
  if (nrow(row) == 0) return(NULL)

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
}

# -------- main loop over CSVs --------
for (csv in csv_files) {

  message("Processing ", csv)

  ld <- fread(csv)

  snps <- unique(ld$snp_in_ld)

  # query Ensembl once per CSV
  snp_info <- getBM(
    attributes = c(
      "refsnp_id",
      "chr_name",
      "chrom_start",
      "allele"
    ),
    filters = "snp_filter",
    values = snps,
    mart = ensembl
  )

  # clean alleles (A/T)
  snp_info <- snp_info[grepl("/", allele)]
  alleles  <- tstrsplit(snp_info$allele, "/", fixed = TRUE)
  snp_info[, REF := alleles[[1]]]
  snp_info[, ALT := alleles[[2]]]

  # keep autosomes + sex chromosomes
  snp_info <- snp_info[
    chr_name %in% c(as.character(1:22), "X", "Y")
  ]

  # write one VCF per SNP
  for (snp in unique(snp_info$refsnp_id)) {
    out_vcf <- file.path(out_dir, paste0(snp, ".vcf"))
    write_single_snp_vcf(snp, out_vcf, snp_info)
  }
}

message("All VCFs written.")
