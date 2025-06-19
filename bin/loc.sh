#!/bin/bash
set -euxo pipefail

declare -a exclude_patterns=(
  "LICENSE"
  ".gitignore"
  "**/.gitignore"
  ".idea/"
  "**/.idea/"
  "Justfile"
  "**/Justfile"
  "*.md"
  "**/*.md"
  "**/*.mdx"
  "**/*.sh"
  "**/*.sql"
  "integration_test/**/*"
  "examples/**/*"
  "manifest.toml"
  "**/manifest.toml"
)
declare -a git_ls_files_args=("--exclude-standard")
for pattern_from_array in "${exclude_patterns[@]}"; do
  git_ls_files_args+=(":!:${pattern_from_array}")
done
git ls-files -z "${git_ls_files_args[@]}" | xargs -0 wc -l | sort
