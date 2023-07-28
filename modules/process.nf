process normalize_by_median {
    container params.container__khmer
    publishDir "${params.outdir}/report", mode: 'copy', overwrite: true, pattern: "*.diginorm.report.txt"
    cpus params.cpus
    memory params.memory_gb

    input:
        tuple val(name), path(fastq)

    output:
        tuple val(name), path("${name}.diginorm_output.fastq.gz"), emit: fastq
        file "${name}.diginorm.report.txt", emit: report

    script:

    """#!/bin/bash
set -e

normalize-by-median.py \
    -p \
    -k ${params.k} \
    --cutoff ${params.median_abund} \
    -R "${name}.report.txt" \
    --output "${name}.diginorm_output.fastq.gz" \
    --gzip \
    "${fastq}"
"""
}

process filter_abund_single {
    container params.container__khmer
    cpus params.cpus
    memory params.memory_gb
    
    input:
        tuple val(name), path(fastq)

    output:
        tuple val(name), path("${name}.filtered.fastq.gz")

    script:

    """#!/bin/bash
set -e

filter-abund-single.py \
    -k ${params.k} \
    --threads ${task.cpus} \
    --cutoff ${params.min_abund} \
    --normalize-to ${params.median_abund}
    --output "${name}.filtered.fastq.gz" \
    --gzip \
    "${fastq}"
"""
}

process interleave_reads {
    container params.container__khmer

    input:
        tuple val(name), path(R1), path(R2)

    output:
        tuple val(name), path("${name}.interleaved.fastq.gz")

    script:

    """#!/bin/bash
set -e

interleave-reads.py \
    -o ${name}.interleaved.fastq.gz \
    --gzip \
    "${R1}" \
    "${R2}"
"""
}

process split_paired_reads {
    container params.container__khmer
    publishDir "${params.outdir}"

    input:
        tuple val(name), path(fastq)

    output:
        tuple val(name), path("${name}.R1.fastq.gz"), path("${name}.R2.fastq.gz"), path("${name}.orphaned.fastq.gz")

    script:

    """#!/bin/bash
set -e

split-paired-reads.py \
    -0 "${name}.orphaned.fastq.gz" \
    -1 "${name}.R1.fastq.gz" \
    -2 "${name}.R2.fastq.gz" \
    --gzip \
    "${fastq}"
"""
}

process abundance_dist_single {
    container params.container__khmer
    publishDir "${params.histDir}", pattern: "*.hist", mode: 'copy', overwrite: true
    publishDir "${params.outdir}", pattern: "*.fastq.gz", mode: 'copy', overwrite: true, enabled: params.publishFastq, saveAs: "${name}${params.suffix}"

    cpus params.cpus
    memory params.memory_gb

    input:
        tuple val(name), path(fastq)

    output:
        tuple val(name), path("${name}.hist")
        path "${fastq}"

    script:

    """#!/bin/bash
set -e

abundance-dist-single.py \
    -k ${params.k} \
    -T ${task.cpus} \
    -b \
    "${fastq}" \
    "${name}.hist"
"""
}
