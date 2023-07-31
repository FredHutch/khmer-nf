process normalize_by_median {
    container params.container__khmer
    publishDir "${params.outdir}/report", mode: 'copy', overwrite: true, pattern: "*.diginorm.report.txt"
    cpus params.cpus
    memory params.memory_gb

    input:
        tuple val(sampleName), path(fastq)

    output:
        tuple val(sampleName), path("${sampleName}.diginorm_output.fastq.gz"), emit: fastq
        path "${sampleName}.diginorm.report.txt", emit: report

    script:

    """#!/bin/bash
set -e

if [[ "${params.paired}" == "true" ]]; then
    FLAGS="-p"
else
    FLAGS=""
fi

normalize-by-median.py \
    \$FLAGS \
    -k ${params.k} \
    -M ${task.memory.toBytes()} \
    --cutoff ${params.median_abund} \
    -R "${sampleName}.diginorm.report.txt" \
    --output "${sampleName}.diginorm_output.fastq.gz" \
    --gzip \
    "${fastq}"
"""
}

process filter_abund_single {
    container params.container__khmer
    cpus params.cpus
    memory params.memory_gb
    
    input:
        tuple val(sampleName), path(fastq)

    output:
        tuple val(sampleName), path("${sampleName}.filtered.fastq.gz")

    script:

    """#!/bin/bash
set -e

filter-abund-single.py \
    "${fastq}" \
    -k ${params.k} \
    -M ${task.memory.toBytes()} \
    --threads ${task.cpus} \
    --cutoff ${params.min_abund} \
    --normalize-to ${params.median_abund} \
    -o "${sampleName}.filtered.fastq.gz" \
    --gzip
"""
}

process interleave_reads {
    container params.container__python

    input:
        tuple val(sampleName), path(R1), path(R2)

    output:
        tuple val(sampleName), path("${sampleName}.interleaved.fastq.gz")

    script:

    """#!/bin/bash
set -e

interleave_fastq.py \
    "${R1}" \
    "${R2}" \
    ${sampleName}.interleaved.fastq.gz
"""
}

process split_paired_reads {
    container params.container__khmer
    publishDir "${params.outdir}", mode: 'copy', overwrite: true

    input:
        tuple val(sampleName), path(fastq)

    output:
        tuple val(sampleName), path("${sampleName}.R1.fastq.gz"), path("${sampleName}.R2.fastq.gz"), path("${sampleName}.orphaned.fastq.gz")

    script:

    """#!/bin/bash
set -e

split-paired-reads.py \
    -0 "${sampleName}.orphaned.fastq.gz" \
    -1 "${sampleName}.R1.fastq.gz" \
    -2 "${sampleName}.R2.fastq.gz" \
    --gzip \
    "${fastq}"
"""
}

process abundance_dist_single {
    container params.container__khmer
    publishDir "${params.histDir}", pattern: "*.hist", mode: 'copy', overwrite: true
    publishDir "${params.outdir}", pattern: "*.fastq.gz", mode: 'copy', overwrite: true, enabled: params.publishFastq, saveAs: { "${sampleName}${params.suffix}" }

    cpus params.cpus
    memory params.memory_gb

    input:
        tuple val(sampleName), path(fastq)

    output:
        path "${sampleName}.hist", emit: hist
        path "*.fastq.gz", includeInputs: true, emit: fastq

    script:

    """#!/bin/bash
set -e

rm -f "${sampleName}.hist"
abundance-dist-single.py \
    -k ${params.k} \
    -T ${task.cpus} \
    -M ${task.memory.toBytes()} \
    -b \
    "${fastq}" \
    "${sampleName}.hist"
"""
}

process summarize_hist {
    container "${params.container__python_plotting}"
    publishDir "${params.outdir}", mode: 'copy', overwrite: true

    input:
        path "abundance_dist_input/"
        path "abundance_dist_output/"

    output:
        path "*.pdf"

    """
compare_hist.py
    """
}