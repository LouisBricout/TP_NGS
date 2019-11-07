#!/bin/bash
# Working directory
WORK_DIR=~/variant-calling/data

# Create the directory and cd into it
mkdir -p ${WORK_DIR}
cd ${WORK_DIR}

########################################################################################################################
# Requirements:
#	Java (version 8)
#	FastQC (version 0.11.7)
#	BWA-MEM (version 0.7.17-r1194-dirty)
#	SAMtools (version 1.9)
#	IGV (version 2.4.14)
########################################################################################################################

java -version
fastqc -version
bwa
samtools
java -jar ${PICARD}

##########################################################
## Download, extract and index the reference chromosome ##
##########################################################
#boucle prenant les trois samples en même temps

# Download the reference Human chromosome (chromosome 20) from Ensembl
# Command: wget
# Input: url (http:// or ftp://)
# Ouput: compressed reference sequence (.fa.gz)
wget ftp://ftp.ensembl.org/pub/release-98/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.chromosome.20.fa.gz -O Homo_sapiens.Chr20.fa.gz
# On récupère la séquence du Chr.20 depuis le site

# Extract the reference chromosome
# Command: gunzip
# Input: compressed reference sequence (.fa.gz)
# Ouput: reference sequence (remove .gz file)
gunzip Homo_sapiens.Chr20.fa.gz

# Index the reference chromosome
# Command: bwa index
# Input: reference (.fa)
# Ouput: indexed reference (.fa.amb, .fa.ann, .fa.bwt, fa.pac, .fa.sa)
bwa index Homo_sapiens.Chr20.fa
# l'indexation est une étape préalable nécessaire au bwa mem, qui a besoin ce ça + le fichier original

######################################################
## Mapping of a family trio to the reference genome ##
######################################################

# Variables definition
FTP_SEQ_FOLDER=ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/phase3/ # Ftp folder from 1000Genomes project

# Download index file containing sequencing runs information
# Command: wget
# Input: url (http:// or ftp://)
# Ouput: text file (.index)
wget ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/phase3/20130502.phase3.analysis.sequence.index -O 20130502.phase3.index
# contient les infos de tous les runs de 1000 génomes, on va extraire celles du père


for INDIVIDUAL in "HG02024" "HG02025"
do
# Filter paired exome sequencing runs related to ${SAMPLE_NAME} (HG02026)
# Command: grep && grep -v
# Input: tab-separated values file (.index)
# Ouput: filtered comma-separated values file (.index)
grep ${INDIVIDUAL} 20130502.phase3.index | grep "exome" | grep 'PAIRED' | grep 'Pond-' | grep -v 'Solexa' | grep -v 'from blood' | grep -v '_1.filt.fastq.gz' | grep -v '_2.filt.fastq.gz' | sed 's/\t/,/g' > ${INDIVIDUAL}.index
#on récupère les données du père sur le fichier ci-dessus

# File containing the list of alignments (each line is a .bam file)
# This file is necessary to merge multiple alignments into a single alignment.
# Command: touch
# Input: file name
# Ouput: empty file (.bamlist)
echo "" > ${INDIVIDUAL}.bamlist

NUMBER_RUNS=8
#head -n ${NUMBER_RUNS}
#les deux lignes ci-dessus sont, en remplacement du cat, une façon de gérer le nombre de reads à computer
# for each sequencing run (the first 8), align to the reference, sort, add read group and index
head -n ${NUMBER_RUNS} ${INDIVIDUAL}.index | while IFS="," read FASTQ_FILE MD5 RUN_ID STUDY_ID STUDY_NAME CENTER_NAME SUBMISSION_ID SUBMISSION_DATE SAMPLE_ID SAMPLE_NAME POPULATION EXPERIMENT_ID INSTRUMENT_PLATFORM INSTRUMENT_MODEL LIBRARY_NAME RUN_NAME RUN_BLOCK_NAME INSERT_SIZE LIBRARY_LAYOUT PAIRED_FASTQ WITHDRAWN WITHDRAWN_DATE COMMENT READ_COUNT BASE_COUNT ANALYSIS_GROUP
do

    # Variables definition
    FASTQ_FILE_1=${FASTQ_FILE/.filt.fastq.gz/_1.filt.fastq.gz} # Path of the fasta file in the FTP folder
    FASTQ_FILE_2=${FASTQ_FILE/.filt.fastq.gz/_2.filt.fastq.gz} # Path of the fasta file in the FTP folder (pairing file)

    # Download paired sequencing reads for the ${SAMPLE_NAME}
    # Command: wget
    # Input: url (http:// or ftp://)
    # Ouput: compressed sequencing reads (.fastq.gz)
    wget ${FTP_SEQ_FOLDER}${FASTQ_FILE_1} -O ${SAMPLE_NAME}_${RUN_ID}_1.filt.fastq.gz
    wget ${FTP_SEQ_FOLDER}${FASTQ_FILE_2} -O ${SAMPLE_NAME}_${RUN_ID}_2.filt.fastq.gz
#les deux éléments recomposent l'url, que l'on utlise pour renommer les fichiers correctement

    # Map, filter, and sort the paired reads of the sequencing run against the reference genome
    # Command: bwa mem && samtools view && samtools sort
    # Input: indexed reference (.fa), and compressed sequencing reads (.fastq.gz)
    # Ouput: sorted alignment (.bam)
     bwa mem -M -t 4 Homo_sapiens.Chr20.fa ${SAMPLE_NAME}_${RUN_ID}_1.filt.fastq.gz ${SAMPLE_NAME}_${RUN_ID}_2.filt.fastq.gz | samtools view -@ 4 -S -b -h -f 3 | samtools sort > ${SAMPLE_NAME}_${RUN_ID}.sorted.bam

    # Add Read group
    # Command: gatk AddOrReplaceReadGroups
    # Input: alignment (.bam) and read group
    # Ouput: alignment (.bam)
    java -jar ${PICARD} AddOrReplaceReadGroups I=${SAMPLE_NAME}_${RUN_ID}.sorted.bam O=${SAMPLE_NAME}_${RUN_ID}.sorted.RG.bam \
                                         RGID=${RUN_ID} RGLB=${LIBRARY_NAME} RGPL=${INSTRUMENT_PLATFORM} \
                                         RGPU=${RUN_NAME} RGSM=${SAMPLE_NAME} RGPI=${INSERT_SIZE}

    # Append the file name (.bam) to the list of alignments that will be merged
    echo ${SAMPLE_NAME}_${RUN_ID}.sorted.RG.bam >> ${SAMPLE_NAME}.bamlist
done

# Merge the list of alignments into a single file
# Command: samtools merge
# Input: file containing the list of alignments (each line is a .bam file)
# Ouput: alignment (.bam)
samtools merge -b ${INDIVIDUAL}.bamlist ${INDIVIDUAL}.bam 

# Index the alignment
# Command: samtools index
# Input: alignment (.sam or .bam)
# Ouput: indexed alignment (.sam.bai or .bam.bai)
samtools index ${INDIVIDUAL}.bam
done