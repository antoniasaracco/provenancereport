process PROVENANCECOLLECT {
    tag 'execution report metadata'
    label 'process_single'
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/28/28717ccd9ce22dbfc219f3db088d5a1fc2ca1f575b5c65621218596dcdbaac95/data'
        : 'community.wave.seqera.io/library/jupyter_matplotlib_papermill_quarto_r-rmarkdown:6d15193ce3dfc665'}"

    input:
    path input_files, stageAs: 'inputs/*'
    tuple val(meta), path(quarto_report, stageAs: 'report/*')
    val pipeline_name
    val pipeline_version
    val launch_command
    val quarto_container

    output:
    path 'provenance_checksums_mqc.tsv', emit: checksums
    path 'provenance_environment_mqc.tsv', emit: environment

    script:
    def collector_container = task.container ?: 'none (local execution)'
    def safe_launch_command = launch_command.replaceAll(/[\r\n\t]/, ' ').replace("'", "'\"'\"'")
    """
    cat > provenance_checksums_mqc.tsv <<'EOF'
    # id: provenance-checksums
    # section_name: Input and report checksums
    # description: MD5 checksums for every pipeline input and the rendered Quarto report.
    # plot_type: table
    File\tKind\tMD5
    EOF

    for input_file in inputs/*; do
        printf '%s\\tInput\\t%s\\n' "\$(basename "\${input_file}")" "\$(md5sum "\${input_file}" | cut -d ' ' -f 1)" >> provenance_checksums_mqc.tsv
    done
    for report_file in report/*; do
        printf '%s\\tQuarto report\\t%s\\n' "\$(basename "\${report_file}")" "\$(md5sum "\${report_file}" | cut -d ' ' -f 1)" >> provenance_checksums_mqc.tsv
    done

    python_version="\$(python --version 2>&1 || true)"
    r_version="\$(R --version 2>/dev/null | head -n 1 || true)"
    [ -n "\${python_version}" ] || python_version='Not available'
    [ -n "\${r_version}" ] || r_version='Not available'

    cat > provenance_environment_mqc.tsv <<'EOF'
    # id: provenance-environment
    # section_name: Execution environment
    # description: Pipeline, command, container, and language runtime information captured for auditing.
    # plot_type: table
    Component\tValue
    EOF
    printf 'Pipeline\\t%s %s\\n' '${pipeline_name}' '${pipeline_version}' >> provenance_environment_mqc.tsv
    printf 'Launch command\\t%s\\n' '${safe_launch_command}' >> provenance_environment_mqc.tsv
    printf 'Quarto container\\t%s\\n' '${quarto_container}' >> provenance_environment_mqc.tsv
    printf 'Metadata collector container\\t%s\\n' '${collector_container}' >> provenance_environment_mqc.tsv
    printf 'Python\\t%s\\n' "\${python_version}" >> provenance_environment_mqc.tsv
    printf 'R\\t%s\\n' "\${r_version}" >> provenance_environment_mqc.tsv
    """
}
