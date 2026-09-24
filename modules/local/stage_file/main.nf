process STAGE_FILE {
    tag 'stage file'
    label 'process_single'

    input:
    // Native tasks do not stage `path` inputs, so keep the source Path as a value.
    val(stage_file)

    output:
    path(stage_file.name), emit: staged_file

    exec:
    java.nio.file.Files.copy(
        stage_file,
        task.workDir.resolve(stage_file.name),
        java.nio.file.StandardCopyOption.REPLACE_EXISTING,
    )
}
