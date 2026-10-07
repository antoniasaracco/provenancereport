process REPORTENVIRONMENT {
    tag 'report runtime environment'
    label 'process_single'
    container {
        try {
            runtime_backend != 'conda' && runtime_backend != 'none' && runtime_reference != 'Not configured' ? runtime_reference : null
        } catch (MissingPropertyException _ignored) {
            // `nextflow inspect` evaluates directives before process inputs are bound.
            null
        }
    }
    conda {
        try {
            runtime_backend == 'conda' && runtime_reference != 'Not configured' ? runtime_reference : null
        } catch (MissingPropertyException _ignored) {
            // `nextflow inspect` evaluates directives before process inputs are bound.
            null
        }
    }

    input:
    tuple val(runtime_process), val(runtime_backend), val(runtime_reference), path(inspection), path(notebook_versions)

    output:
    path "runtime_environment_mqc.tsv"  , emit: multiqc_table
    path "r_runtime_session_info_mqc.yaml", emit: multiqc_r_session
    path "versions.yml"                 , emit: versions, topic: versions

    script:
    template 'reportenvironment.sh'

    stub:
    """
    cat <<-END_MQC > runtime_environment_mqc.tsv
    field\tvalue
    Process\t${task.process}
    Runtime source process\t${runtime_process}
    Runtime backend\t${runtime_backend}
    Runtime reference\t${runtime_reference ?: 'Not configured'}
    Quarto engine\tUnknown (stub)
    Container engine\t${workflow.containerEngine ?: 'None'}
    Python\tNot available
    Package version source\tNot available (stub)
    END_MQC

    cat <<-END_MQC > r_runtime_session_info_mqc.yaml
    id: 'nf-core-provenancereport-r-runtime-session-info'
    description: 'R sessionInfo() collected in a separate process inside the report runtime.'
    section_name: 'R runtime sessionInfo()'
    plot_type: 'html'
    data: |
      <p><strong>Scope:</strong> This describes a separate R process in the report runtime. It does not show packages loaded during notebook execution.</p>
      <pre style="white-space: pre-wrap; overflow-x: auto; max-height: 32rem;">
      Not available
      </pre>
    END_MQC

    cat <<-END_VERSIONS > versions.yml
    "${runtime_process}": {}
    END_VERSIONS

    """
}
