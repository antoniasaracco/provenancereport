process MULTIQC {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/multiqc:1.30--pyhdfd78af_0'
        : 'quay.io/biocontainers/multiqc:1.30--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(multiqc_files)
    path multiqc_config
    path extra_multiqc_config
    path logo
    val multiqc_report_title

    output:
    tuple val(meta), path("${prefix}.html"), emit: html
    tuple val(meta), path('multiqc_data'), emit: data
    tuple val(meta), path('multiqc_plots'), emit: plots, optional: true
    path 'versions.yml', emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: 'multiqc_report'
    def config = multiqc_config ? "--config ${multiqc_config}" : ''
    def extra_config = extra_multiqc_config ? "--config ${extra_multiqc_config}" : ''
    def logo_arg = logo ? "--logo ${logo}" : ''
    def title = multiqc_report_title ? "--title '${multiqc_report_title}'" : ''
    """
    multiqc \\
        --force \\
        ${config} \\
        ${extra_config} \\
        ${logo_arg} \\
        ${title} \\
        --filename ${prefix}.html \\
        ${args} \\
        .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$(multiqc --version | sed -e 's/multiqc, version //')
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: 'multiqc_report'
    """
    touch ${prefix}.html
    mkdir multiqc_data
    touch multiqc_data/multiqc_data.json
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: 1.30
    END_VERSIONS
    """
}
