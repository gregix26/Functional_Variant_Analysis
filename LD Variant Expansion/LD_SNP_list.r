library(ensemblQueryR)
library(dplyr)
library(readr)
library(purrr)

#Check Server
ensemblQueryR::pingEnsembl()
ensemblQueryR::ensemblQueryGetPops()


# Input arguments
args <- commandArgs(trailingOnly = TRUE)
input_csv <- args[1]
outdir <- args[2]

dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# Read SNP list
snps <- read_csv(input_csv, col_types = cols()) %>%
  pull(rsid)

# Function to query LD
get_ld <- function(rsid) {
  message("Processing ", rsid)
  
  tryCatch({
    res <- ensemblQueryR::ensemblQueryLDwithSNPwindow(
      rsid = rsid,
      r2 = 0.9,
      d.prime = 0,
      window.size = 500, #500kb window
      pop = "1000GENOMES:phase_3:EUR"
    )
    
   if (nrow(res) == 0) {
        message("No LD partners found for ", rsid)
        return(NULL)
      }
    
    res %>%
      select(-matches("population|n_")) %>%
      mutate(index_snp = rsid)
    
  }, error = function(e) {
    warning("Failed for ", rsid)
    NULL
  })
}

# Run LD expansion
cat("Starting LD expansion...\n")
ld_results <- map(snps, get_ld)

# Filter successful results
successful_results <- ld_results[!sapply(ld_results, is.null)]
failed_snps <- snps[sapply(ld_results, is.null)]

cat("Successfully processed:", length(successful_results), "SNPs\n")
cat("Failed SNPs:", length(failed_snps), "\n")

# Write outputs
walk2(ld_results, snps, ~{
  if (!is.null(.x)) {
    write_csv(
      .x,
      file.path(outdir, paste0("LD_", .y, ".csv"))
    )
  }
})

cat("LD expansion complete!\n")
cat("Results written to:", outdir, "\n")
