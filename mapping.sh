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

# Download the reference Human chromosome (chromosome 20) from Ensembl
# Command: wget
# Input: url (http:// or ftp://)
# Ouput: compressed reference sequence (.fa.gz)
wget ftp://ftp.ensembl.org/pub/release-98/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.chromosome.20.fa.gz -O Homo_sapiens.Chr20.fa.gz

# On récupère la séquence du Chr.20 depuis un site. On enregistre la séquence dans un fichier.

# Extract the reference chromosome
# Command: gunzip
# Input: compressed reference sequence (.fa.gz)
# Ouput: reference sequence (remove .gz file)
gunzip Homo_sapiens.Chr20.fa.gz

#extraction de la séquence de référence du Chromosome 20

# Index the reference chromosome
# Command: bwa index
# Input: reference (.fa)
# Ouput: indexed reference (.fa.amb, .fa.ann, .fa.bwt, fa.pac, .fa.sa)
bwa index Homo_sapiens.Chr20.fa

#grosso modo, numérotation
# l'indexation est une étape préalable nécessaire au bwa mem, qui a besoin ce ça + le fichier original

######################################################
## Mapping of a family trio to the reference genome ##
######################################################

# The sequences are from an East Asian (Kinh Vietnamese) family forming a trio : daughter/mother/father
# Data available at http://www.internationalgenome.org/data-portal/sample/HG02024
# Daughter:
#       StudyId: SRP004063
#       SampleName: HG02024
#       Library: Pond-206419
#       ExperimentID: SRX001596
#       RunId: SRR822145
#       PlatformUnit:  C19U4ACXX121217.7.tagged_373.bam
#       InstrumentModel: Illumina HiSeq 2000
#       InsertSize: 160
#       Link: ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR822/SRR822145/SRR822145_1.fastq.gz
#       Link2: ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR822/SRR822145/SRR822145_2.fastq.gz
# Mother:
#       StudyId: SRP004063
#       SampleName: HG02025
#       Library: Catch-88584
#       ExperimentID: SRX103760
#       RunId: SRR359188
#       PlatformUnit: BI.PE.110902_SL-HBC_0182_AFCD046MACXX.7.tagged_851.srf
#       InstrumentModel: Illumina HiSeq 2000
#       InsertSize: 96
#       Link: ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR359/SRR359188/SRR359188_2.fastq.gz
# Father:
#       StudyId: SRP004063
#       SampleName: HG02026

#############################
## Mapping of the daughter ##
#############################

# Download paired sequencing reads for the daughter (SampleName: HG02024, RunId: SRR822145)
# Command: wget
# Input: url (http:// or ftp://)
# Ouput: compressed sequencing reads (.fastq.gz)
wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR822/SRR822145/SRR822145_2.fastq.gz -O HG02024_SRR822145_2.filt.fastq.gz

#on récupère les données de la fille

# Map the paired sequencing reads against the reference Human chromosome 20
# Command: bwa mem
# Options: -M (Mark shorter split hits as secondary for GATK compatibility)
#          -t [number of CPU] (multi-threading)
# Input: indexed reference (.fa), and compressed sequencing reads (.fastq.gz)
# Ouput: alignment (.sam)
bwa mem -M -t 4 Homo_sapiens.Chr20.fa HG02024_SRR822145_1.filt.fastq.gz HG02024_SRR822145_2.filt.fastq.gz > HG02024_SRR822145.sam

#alignement des reads sur la séquence de référence, utilise des paired reads (reads dont on sait qu'ils sont proches sur la séquence du Chr 20)
# si un read s'aligne, l'autre ne va pas loin = + rapide
# commence à aligner à partir du milieu du read, puis étend de chaque côté pour voir si ça fitte


# (Optional)
# Compute summary statistics of the alignment
# Command: samtools flagstats
# Input: alignment (.sam)
# Ouput: text file (human and computer readable)
samtools flagstat HG02024_SRR822145.sam > HG02024_SRR822145.sam.flagstats

#analyse stat de l'alignement

# Compress the alignment and filter unaligned reads
# Command: samtools view
# Options:
#      -@ [number of CPU] (multi-threading)
#	   -S (input format is auto-detected)
# 	   -b (output BAM)
#	   -h (include header in output)
#      -f [flag] (include reads with all  of the FLAGs in INT present)
# 	      flag=3 for read paired & read mapped in proper pair, see
#	      https://broadinstitute.github.io/picard/explain-flags.html
# Input: alignment (.sam)
# Ouput: compressed alignment (.bam)
samtools view -@ 4 -S -b -h -f 3 HG02024_SRR822145.sam > HG02024_SRR822145.bam

#ressort une version compressée de l'alignement dont on a ôté les reads qui n'ont pas pu être alignés

# Sort the alignment
# Command: samtools sort
# Input: compressed alignment (.bam)
# Ouput: sorted and compressed alignment (.bam)
samtools sort HG02024_SRR822145.bam > HG02024_SRR822145.sorted.bam

#met les reads dans l'ordre de leur position sur le chromosome

# Add Read group (cf https://gatkforums.broadinstitute.org/gatk/discussion/6472/read-groups)
# Command: gatk AddOrReplaceReadGroups
# Input: alignment (.bam) and read group (Read group identifier, DNA preparation library identifier, Platform, Platform Unit, Sample)
# Ouput: annotated alignment (.bam)
java -jar ${PICARD} AddOrReplaceReadGroups I=HG02024_SRR822145.sorted.bam \
                                         O=daughter.bam \
                                         RGID=SRR822145 RGLB=Pond-206419 RGPL=ILLUMINA \
                                         RGPU=C19U4ACXX121217.7.tagged_373.bam RGSM=HG02024 RGPI=160
#Annotation du fichier avec des métadonnées dont on en disposait pas avant, permet d'affiner l'analyse des reads
# (séquenceur, library, numéro du run, flowcell et lane où on a fait le run, individu etc) --> permet de détecter et corriger des biais dans l'analyse

# (Optional)
# Compute statistics of the alignment
# Command: samtools-stats
# Input: alignment (.bam)
# Ouput: text file (human and computer readable)
samtools stats daughter.bam > daughter.bam.stats
#5% des reads sont mappés au Chr 20, ce qui est cohérent sachant que les reads sont sur tout le génome
#et que le chr 20 est petit


# Index the alignment
# Command: samtools index
# Input: alignment (.bam)
# Ouput: indexed alignment (.bam.bai)
samtools index daughter.bam
#fichier nécessaire pour visualiser l'alignement dans IGV

###########################
## Mapping of the mother ##
###########################

# Variables definition
FTP_SEQ_FOLDER=ftp://ftp.sra.ebi.ac.uk/vol1/fastq # Ftp folder from 1000Genomes project
RUN_ID=SRR359188 # Read group identifier
SAMPLE_NAME=HG02025 # Sample
INSTRUMENT_PLATFORM=Illumina # Platform/technology used to produce the read
LIBRARY_NAME=Catch-88584 # DNA preparation library identifier
RUN_NAME=BI.PE.110902_SL-HBC_0182_AFCD046MACXX.7.tagged_851.srf # Platform Unit
INSERT_SIZE=96 # Insert size
RUN=SRR359
#on spécifie les éléments d'identification pour pouvoir récupérer les reads
#il faut initialiser les variables avant de lancer le wget

# Download paired sequencing reads for the mother
# Command: wget
# Input: url (http:// or ftp://)
# Ouput: compressed sequencing reads (.fastq.gz)
#wget ${FTP_SEQ_FOLDER}/data/${SAMPLE_NAME}/sequence_read/${RUN_ID}_1.filt.fastq.gz -O ${SAMPLE_NAME}_${RUN_ID}_1.filt.fastq.gz
#wget ${FTP_SEQ_FOLDER}/data/${SAMPLE_NAME}/sequence_read/${RUN_ID}_2.filt.fastq.gz -O ${SAMPLE_NAME}_${RUN_ID}_2.filt.fastq.gz
#les liens ci-dessus sont incorrects, ils ont été ajustés en les liens ci-dessous
#on récupère les reads
#ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR359/SRR359188/SRR359188_2.fastq.gz
wget ${FTP_SEQ_FOLDER}/${RUN}/${RUN_ID}/${RUN_ID}_1.fastq.gz -O ${SAMPLE_NAME}_${RUN_ID}_1.filt.fastq.gz
wget ${FTP_SEQ_FOLDER}/${RUN}/${RUN_ID}/${RUN_ID}_2.fastq.gz -O ${SAMPLE_NAME}_${RUN_ID}_2.filt.fastq.gz

# Map, filter, and sort the paired sequencing reads of the mother against the reference genome
# Command: bwa mem && samtools view && samtools sort
# Input: indexed reference (.fa), and compressed sequencing reads (.fastq.gz)
# Ouput: sorted alignment (.bam)
bwa mem -M -t 4 Homo_sapiens.Chr20.fa ${SAMPLE_NAME}_${RUN_ID}_1.filt.fastq.gz ${SAMPLE_NAME}_${RUN_ID}_2.filt.fastq.gz | samtools view -@ 4 -S -b -h -f 3 | samtools sort > ${SAMPLE_NAME}_${RUN_ID}.sorted.bam

# Add Read group
# Command: gatk AddOrReplaceReadGroups
# Input: alignment (.bam) and read group
# Ouput: alignment (.bam)
java -jar ${PICARD} AddOrReplaceReadGroups I=${SAMPLE_NAME}_${RUN_ID}.sorted.bam O=mother.bam \
                                         RGID=${RUN_ID} RGLB=${LIBRARY_NAME} RGPL=${INSTRUMENT_PLATFORM} \
                                         RGPU=${RUN_NAME} RGSM=${SAMPLE_NAME} RGPI=${INSERT_SIZE}
#ajout de données complémentaires aux reads alignés

# Index the alignment
# Command: samtools index
# Input: alignment (.bam)
# Ouput: indexed alignment (.bam.bai)
samtools index mother.bam

###########################
## Mapping of the father ##
###########################

# Variables definition
FTP_SEQ_FOLDER=ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/phase3/ # Ftp folder from 1000Genomes project
SAMPLE_NAME=HG02026 # Sample
#contient les reads du père

# Download index file containing sequencing runs information
# Command: wget
# Input: url (http:// or ftp://)
# Ouput: text file (.index)
wget ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/phase3/20130502.phase3.analysis.sequence.index -O 20130502.phase3.index
# contient les infos de tous les runs de 1000 génomes, on va extraire celles du père

# Filter paired exome sequencing runs related to father (HG02026)
# Command: grep && grep -v
# Input: tab-separated values file (.index)
# Ouput: filtered comma-separated values file (.index)
grep ${SAMPLE_NAME} 20130502.phase3.index | grep "exome" | grep 'PAIRED' | grep 'Pond-' | grep -v 'Solexa' | grep -v 'from blood' | grep -v '_1.filt.fastq.gz' | grep -v '_2.filt.fastq.gz' | sed 's/\t/,/g' > father.index
#on récupère les données du père sur le fichier ci-dessus

NUMBER_RUNS=8
#head -n ${NUMBER_RUNS}
#les deux lignes ci-dessus sont, en remplacement du cat, une façon de gérer le nombre de reads à computer
# for each sequencing run (the first 8), align to the reference, sort, add read group and index
cat father.index | while IFS="," read FASTQ_FILE MD5 RUN_ID STUDY_ID STUDY_NAME CENTER_NAME SUBMISSION_ID SUBMISSION_DATE SAMPLE_ID SAMPLE_NAME POPULATION EXPERIMENT_ID INSTRUMENT_PLATFORM INSTRUMENT_MODEL LIBRARY_NAME RUN_NAME RUN_BLOCK_NAME INSERT_SIZE LIBRARY_LAYOUT PAIRED_FASTQ WITHDRAWN WITHDRAWN_DATE COMMENT READ_COUNT BASE_COUNT ANALYSIS_GROUP
do

    # Variables definition
    FASTQ_FILE_1=${FASTQ_FILE/.filt.fastq.gz/_1.filt.fastq.gz} # Path of the fasta file in the FTP folder
    FASTQ_FILE_2=${FASTQ_FILE/.filt.fastq.gz/_2.filt.fastq.gz} # Path of the fasta file in the FTP folder (pairing file)

    # Download paired sequencing reads for the father
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
done
# File containing the list of alignments (each line is a .bam file)
# This file is necessary to merge multiple alignments into a single alignment.
# Command: touch
# Input: file name
# Ouput: empty file (.bamlist)
ls ${SAMPLE_NAME}*.RG.bam > ${SAMPLE_NAME}.bamlist

# Merge the list of alignments into a single file
# Command: samtools merge
# Input: file containing the list of alignments (each line is a .bam file)
# Ouput: alignment (.bam)
samtools merge -b ${SAMPLE_NAME}.bamlist ${SAMPLE_NAME}.bam 

# Index the alignment
# Command: samtools index
# Input: alignment (.sam or .bam)
# Ouput: indexed alignment (.sam.bai or .bam.bai)
samtools index ${SAMPLE_NAME}.bam
