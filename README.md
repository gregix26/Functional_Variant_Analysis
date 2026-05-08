# Functional Variant Prioritization Pipeline

Aim: The aim of this Functional Variant Analysis Pipeline is to systematically prioritise functionally causal variants from post-GWAS or post-COLOC signals by integration linkage disequilibrium (LD) structure, functional annotation, splicing prediction and chromatin evidence. 

Workflow Sequence: 
## Step 1: LD-based Variant Expansion 
In a first step, a list of SNPs of Interest is expanded to include high LD SNPs and summarised by quering Ensembls LD data, using a threhshold of r2 > 0.7 and a window size = 500kb around the SNP of Interest.
## Step 2: Functional Annotation 
In a second step, variants (expanded SNP list) are mapped to genes, transcripts and regulatory elements by leveraging VEP to read each variant and check where it maps on the genome, using Ensembl transcript models and determining consequences from sequence ontology terms. Various functions are incorporated to investigate: a. Protein Coding Variants b. Regulatory Element Annotation c. Transcription Factor Binding Sites. Plugins can be added and removed to increase or refine annotations. 
## Step 3: Molecular Impact Prediction 
SpliceAI is used to predict splicing effects of variants under investigation. SpliceAI predicts change in splicing probabilities at each base in a sequence window of +/- 500kb. 

Optional scoring: For non-coding variants, a score of "importance" can be added via LINSIGHT (similar to CADD or REVEL for coding variants), a database of precalculated scores informing pressures of negative selection on non-coding sequences. For this, selected non-coding variants need to be reannotated in VEP with hg19 build. Download precalculated scores: http://compgen.cshl.edu/LINSIGHT/LINSIGHT.bw You will also need to install pyBigWig (recommended to run in separate Python environment).

AlphaGenome predictions of variant impact can also be incorporated here as additional line of evidence, although the cell-type-specific predictions can be sparse or weak.

Compiling non-coding and regulatory variants, genomic location of variants need to be stored in BED format. Using ATAC-seq, Hi-C or other epigenetic data, functional variants can be weeded out by intersecting epigenetic data with the variants. Open/active chromatin = possible functional role. 

## Step 4: Scoring System
Evidence from chromatin profiling analyses is scored and variants with highest functional evidence are prioritized.

## Step 5: Transcription Factor Disruption Analysis
Using the list of putatively functional variants, the reference and alternate sequences are scanned for TF motifs within a 20bp window. Delta score = REF - ALT motif score informs us about gained, lost, strengtened or weaked motifs that might disrupt the binding of TF families. For more complex analysis, consider using CRESted and TF-MINDI for cell-type-specific prediction of motif syntax disruption by prioritized variants.

<img width="4288" height="3426" alt="image" src="https://github.com/user-attachments/assets/fe9c6887-9d66-45f8-8ea9-448a3af4eb32" />



