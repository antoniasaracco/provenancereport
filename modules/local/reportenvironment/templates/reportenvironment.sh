#!/usr/bin/env bash

extract_inspection_metadata() {
    local python_command=''

    printf 'Not available\n' > report_engine.txt

    if command -v python >/dev/null 2>&1; then
        python_command='python'
    elif command -v python3 >/dev/null 2>&1; then
        python_command='python3'
    else
        return
    fi

    "\${python_command}" - "${inspection}" <<'PYTHON'
import json
import pathlib
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    inspection = json.load(handle)

engines = inspection.get("engines") or []
if len(engines) != 1:
    raise SystemExit(
        f"Expected exactly one Quarto execution engine, but found: {engines or 'none'}"
    )
pathlib.Path("report_engine.txt").write_text(str(engines[0]), encoding="utf-8")

cell_number = 0
for document in (inspection.get("fileInformation") or {}).values():
    for cell in (document.get("codeCells") or []):
        if str(cell.get("language", "")).lower() != "r":
            continue
        cell_number += 1
        pathlib.Path(f"r_cell_{cell_number:04d}.R").write_text(
            cell.get("source", ""),
            encoding="utf-8",
        )
PYTHON
}

collect_r_package_versions() {
    : > inspected_versions.csv

    if ! command -v Rscript >/dev/null 2>&1; then
        return
    fi

    Rscript --vanilla - <<'RSCRIPT'
cell_files <- Sys.glob("r_cell_*.R")
if (length(cell_files) == 0L) {
    quit(save = "no", status = 0L)
}

packages <- character()

package_name <- function(node) {
    if (is.symbol(node) || is.character(node)) {
        return(as.character(node)[[1L]])
    }
    character()
}

walk_expression <- function(node) {
    if (is.call(node)) {
        call_head <- node[[1L]]
        function_name <- if (is.symbol(call_head)) as.character(call_head) else character()

        if (length(function_name) == 1L && function_name %in% c("library", "require", "requireNamespace", "loadNamespace") && length(node) >= 2L) {
            packages <<- c(packages, package_name(node[[2L]]))
        }

        if (length(function_name) == 1L && function_name %in% c("::", ":::") && length(node) >= 2L) {
            packages <<- c(packages, package_name(node[[2L]]))
        }

        invisible(lapply(as.list(node), walk_expression))
    } else if (is.expression(node) || is.pairlist(node) || is.list(node)) {
        invisible(lapply(node, walk_expression))
    }
}

for (cell_file in cell_files) {
    parsed_cell <- tryCatch(parse(file = cell_file, keep.source = FALSE), error = function(error) expression())
    walk_expression(parsed_cell)
}

packages <- sort(unique(packages[nzchar(packages)]))
installed <- rownames(installed.packages())
package_versions <- vapply(
    packages,
    function(package) {
        if (package %in% installed) as.character(packageVersion(package)) else "not installed"
    },
    character(1L)
)

versions <- data.frame(
    package = c("R", packages),
    version = c(paste(R.version[["major"]], R.version[["minor"]], sep = "."), unname(package_versions)),
    stringsAsFactors = FALSE
)
write.table(versions, "inspected_versions.csv", sep = ",", row.names = FALSE, col.names = FALSE, quote = FALSE)
RSCRIPT
}

write_versions_yaml() {
    awk -F',' 'NF >= 2 && \$1 != "" && \$2 != "" && !seen[\$1]++' "${notebook_versions}" > notebook_versions.final.csv

    if [ -s notebook_versions.final.csv ]; then
        cp notebook_versions.final.csv versions.final.csv
        printf 'Notebook versions.csv (authoritative)\n' > version_source.txt
    else
        awk -F',' 'NF >= 2 && \$1 != "" && \$2 != "" && !seen[\$1]++' inspected_versions.csv > versions.final.csv
        printf 'Quarto inspection fallback\n' > version_source.txt
    fi

    if [ -s versions.final.csv ]; then
        printf '"%s":\n' "${runtime_process}" > versions.yml
        awk -F',' '{
            key = \$1
            value = substr(\$0, index(\$0, ",") + 1)
            printf "  \"%s\": \"%s\"\\n", key, value
        }' versions.final.csv >> versions.yml
    else
        printf '"%s": {}\n' "${runtime_process}" > versions.yml
    fi
}

collect_r_runtime_session_info() {
    if command -v Rscript >/dev/null 2>&1; then
        Rscript --vanilla -e 'sessionInfo()' > r_runtime_session_info.txt 2>/dev/null || printf 'Not available\n' > r_runtime_session_info.txt
    else
        printf 'Not available\n' > r_runtime_session_info.txt
    fi
}

collect_python_version() {
    if command -v python >/dev/null 2>&1; then
        python --version > python_version.txt 2>&1 || printf 'Not available\n' > python_version.txt
    elif command -v python3 >/dev/null 2>&1; then
        python3 --version > python_version.txt 2>&1 || printf 'Not available\n' > python_version.txt
    else
        printf 'Not available\n' > python_version.txt
    fi
}

write_runtime_environment_table() {
    local python_version
    local report_engine
    local version_source
    python_version=\$(tr '\t\r\n' '   ' < python_version.txt | sed 's/[[:space:]]*\$//')
    report_engine=\$(tr '\t\r\n' '   ' < report_engine.txt | sed 's/[[:space:]]*\$//')
    version_source=\$(tr '\t\r\n' '   ' < version_source.txt | sed 's/[[:space:]]*\$//')

    cat <<-END_MQC > runtime_environment_mqc.tsv
field\tvalue
Process\t${task.process}
Runtime source process\t${runtime_process}
Runtime backend\t${runtime_backend}
Runtime reference\t${runtime_reference ?: 'Not configured'}
Quarto engine\t\${report_engine}
Container engine\t${workflow.containerEngine ?: 'None'}
Python\t\${python_version}
Package version source\t\${version_source}
END_MQC
}

write_r_runtime_session_info_section() {
    cat <<-END_MQC > r_runtime_session_info_mqc.yaml
id: 'nf-core-provenancereport-r-runtime-session-info'
description: 'R sessionInfo() collected in a separate process inside the report runtime.'
section_name: 'R runtime sessionInfo()'
plot_type: 'html'
data: |
  <p><strong>Scope:</strong> This describes a separate R process in the report runtime. It does not show packages loaded during notebook execution; use the Software Versions section for those versions.</p>
  <pre style="white-space: pre-wrap; overflow-x: auto; max-height: 32rem;">
END_MQC

    sed \
        -e 's/&/\\&amp;/g' \
        -e 's/</\\&lt;/g' \
        -e 's/>/\\&gt;/g' \
        -e 's/^/  /' \
        r_runtime_session_info.txt >> r_runtime_session_info_mqc.yaml

    printf '  </pre>\n' >> r_runtime_session_info_mqc.yaml
}

collect_python_version
extract_inspection_metadata
collect_r_package_versions
collect_r_runtime_session_info
write_versions_yaml
write_runtime_environment_table
write_r_runtime_session_info_section
