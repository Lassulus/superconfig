#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"

install_skill() {
  local skill_name="$1"
  local skill_dir="${SCRIPT_DIR}/${skill_name}"

  if [[ ! -f "${skill_dir}/SKILL.md" ]]; then
    echo "Error: ${skill_name}/SKILL.md not found" >&2
    return 1
  fi

  mkdir -p "${CLAUDE_SKILLS_DIR}/${skill_name}"
  ln -sf "${skill_dir}/SKILL.md" "${CLAUDE_SKILLS_DIR}/${skill_name}/SKILL.md"
  echo "Installed ${skill_name}"
}

if [[ $# -gt 0 ]]; then
  install_skill "$1"
else
  for skill_dir in "${SCRIPT_DIR}"/*/; do
    skill_name="$(basename "${skill_dir}")"
    [[ -f "${skill_dir}/SKILL.md" ]] && install_skill "${skill_name}"
  done
fi
