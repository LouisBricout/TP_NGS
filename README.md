#SNP Identification and characterization on 1000 genomes project exome sequences

This program is meant to be a pipeline to analyze sequencing reads. 
In this particular case, the samples are exome sequences from Chromosome 20, and the analysis focuses on identifying SNPs.
These sequences were obtained from the 1000 genomes project databank, and belong to three members of a Vietnamese family (mother, father, daughter).
The analysis is divided into three parts:
-Mapping of the sequencing reads to a reference sequence for Chromosome 20
-SNP identification, or variant calling
-Characterization of the SNPs in accordance with the association of the samples (genetic relatedness in this case)

Identifying SNPs can prove useful to study population dynamics or disease-associated and disease-protective mutations.
This program can be modulated to detect and characterize SNPs for different types and amounts of reads and samples.

#Getting Started

Installation.sh should be run prior to anything else, as it will download, extract and facilitate the local execution of functions that are required to run the analysis.

#Program core

mapping.sh fetches, maps and aligns the sequencing reads of one sample to the reference chromosome sequence. The central executable for this part is bwa mem.
mapping.trio is a modulable for loop of mapping.sh  which allows rapid mapping of several samples.
 
variant-calling.sh uses mapped sequences and reference SNPs and indels to identify new SNPs in the samples.
Read alignment and precision is also refined with both reference data and data from the sequencing reads.

Trio analysis compares and contrasts SNPs in each sample according to their familial relations.

#Metadata
Built with Python.
8 commits to date on 11/18/2019.

#Acknowledgements

Major contributors include Granier E., Hans.J, Humbert.A