process QUARTO_INSPECT {
    tag "${meta.id}"
    label 'process_low'
    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'docker://ghcr.io/quarto-dev/quarto:1.7.31'
        : 'ghcr.io/quarto-dev/quarto:1.7.31'}"

    input:
    tuple val(meta), path(notebook)

    output:
    tuple val(meta), path("${prefix}.inspect.json"), emit: inspection
    tuple val("${task.process}"), val('quarto'), eval('quarto -v'), emit: versions_quarto, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Set environment variables needed for Quarto inspection
    export XDG_CACHE_HOME="./.xdg_cache_home"
    export XDG_DATA_HOME="./.xdg_data_home"

    quarto inspect \
        ${args} \
        ${notebook} \
        ${prefix}.inspect.json

    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    cat <<-END_JSON > ${prefix}.inspect.json
    {
      "quarto": {"version": "stub"},
      "engines": ["knitr"],
      "formats": {},
      "resources": [],
      "fileInformation": {}
    }
    END_JSON

    """
}
