#!/usr/bin/env nextflow

// Using DSL-2
nextflow.enable.dsl=2

include {
    interleave_reads;
    filter_abund_single;
    normalize_by_median;
    split_paired_reads
} from "./modules/process"

include {
    abundance_dist_single as abundance_dist_input
} from "./modules/process", addParams(
    histDir: "${params.outdir}/abundance_dist_input",
    publishFastq: false
)

include {
    abundance_dist_single as abundance_dist_output
} from "./modules/process", addParams(
    histDir: "${params.outdir}/abundance_dist_output",
    publishFastq: "${params.paired}" != "true"
)

// Function which prints help message text
def helpMessage() {
    log.info"""
    Usage:

    nextflow run FredHutch/khmer-nf <args>

    Required Arguments:
        --indir        # Folder containing FASTQ file(s) to analyze
        --paired       # FASTQ files are paired-end (default: true)
                       # If true:
                       #      Reads will be found matching the pattern
                       #      <indir>/*<spacer>{1,2}<suffix>
                       # If false:
                       #      Reads will be found matching the pattern
                       #      <indir>/*<suffix>

        --outdir       # Folder to place output files

    # Default params
        --spacer       # Used for paired-end reads (default: _R)
        --suffix       # Used for paired-end reads (default: .fastq.gz)

    """.stripIndent()
}


workflow {

    // Print the help message
    if (params.help){
        helpMessage();
        exit 0
    }
    if (!params.indir){
        helpMessage();
        log.info"""Please specify parameter: indir"""
        exit 0
    }
    if (!params.outdir){
        helpMessage();
        log.info"""Please specify parameter: outdir"""
        exit 0
    }

    log.info"""
Running khmer-nf

Parameters:

    I/O:
        indir = ${params.indir}
        paired = ${params.paired}
        spacer = ${params.spacer}
        suffix = ${params.suffix}
        outdir = ${params.outdir}

    Filtering:
        k = ${params.k}
        median_abund = ${params.median_abund}
        min_abund = ${params.min_abund}

    Resources:
        cpus = ${params.cpus}
        memory_gb = ${params.memory_gb}
        container__khmer = ${params.container__khmer}

"""

    // If the reads are paired-end
    if ("${params.paired}" == "true"){
        
        log.info"""Processing paired-end reads from ${params.indir}/*${params.spacer}{1,2}${params.suffix}"""

        Channel
            .fromFilePairs(
                "${params.indir}/*${params.spacer}{1,2}${params.suffix}",
                checkIfExists: true
            )
            .ifEmpty { error "No file pairs found at ${params.indir}/*${params.spacer}{1,2}${params.suffix}" }
            .map {
                it -> [it[0], it[1][0], it[1][1]]
            }
            | interleave_reads

        reads_ch = interleave_reads.out.fastq

    } else { // If the reads are single-end

        log.info"""Processing single-end reads from ${params.indir}/*${params.suffix}"""

        Channel
            .fromPath(
                "${params.indir}/*${params.suffix}",
                checkIfExists: true
            ).map {
                it -> [it.name.replace("${params.suffix}", ""), it]
            }
            .set { reads_ch }
    }

    // Calculate the abundance distribution of the input
    abundance_dist_input(reads_ch)

    // Perform normalization by median
    normalize_by_median(reads_ch)

    // If --min_abund was not set to 0
    if ("${params.min_abund}" != "0") {
        log.info"""Filtering by minimum abundance (${params.min_abund})"""
        filter_abund_single(normalize_by_median.out.fastq)
        final_interleaved = filter_abund_single.out
    } else {
        log.info"""Skipping the minimum abundance filter"""
        final_interleaved = normalize_by_median.out.fastq
    }

    // Calculate the abundance distribution of the output
    abundance_dist_output(final_interleaved)

    // If the reads are paired-end
    if ("${params.paired}" == "true"){

        log.info"""Deinterleaving outputs"""
        split_paired_reads(final_interleaved)

    }

}