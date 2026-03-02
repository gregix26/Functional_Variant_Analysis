# Functional_Variant_Analysis

Aim: The aim of this Functional Variant Analysis Pipeline is to systematically prioritise functionally causal variants from post-GWAS or post-COLOC signals by integration linkage disequilibrium (LD) structure, functional annotation, splicing prediction and chromatin evidence. 

Workflow Sequence: 
## Step 1: LD-based Variant Expansion 
In a first step, a list of SNPs of Interest (csv file) is used as an input file. Then, SNPs in high LD with the SNPs of Interest are calculated and summarised by quering Ensembls LD data, using a threhshold of r2 > 0.9 and a window size = 500kb around the SNP of Interest.
## Step 2: Functional Annotation 
In a second step, variants (SNP list) are mapped to genes, transcripts and regulatory elements by leveraging VEP to read each variant and check where it maps on the genome, using Ensembl transcript models and determining consequences from sequence ontology terms. Various functions are incorporated to investigate: a. Protein Coding Variants b. Regulatory Element Annotation c. Transcription Factor Binding Sites. Plugins can be added and removed to increase or refine annotations. 
## Step 3: Molecular Impact Prediction 
SpliceAI is used to predict splicing effects of variants under investigation. SpliceAI predicts change in splicing probabilities at each base in a sequence window of +/- 500kb. 

For non-coding variants, the a score of "importance" is added via LINSIGHT, a database of precalculated scores informing pressures of negative selection on non-coding sequences. For this, selected non-coding variants need to be reannotated in VEP with hg19 build. 

For non-coding and regulatory variants, csv files of VEP results need to be converted into bed files. Using ATAC-seq, Hi-C or other epigenetic data, functional variants can be weeded out by overlaying epigenetic data over the variants. Open chromatin = possible functional role. 

## Step 4: Scoring system


