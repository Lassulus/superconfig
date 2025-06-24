#!/usr/bin/env bash
set -euo pipefail

# Default separator
SEPARATOR="-"

# Parse command line options
while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--separator)
      SEPARATOR="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Generate a random name in the format: adjective-noun"
      echo ""
      echo "Options:"
      echo "  -s, --separator CHAR    Use CHAR as separator (default: -)"
      echo "  -h, --help             Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read adjectives and nouns
mapfile -t ADJECTIVES < "$SCRIPT_DIR/adjectives.txt"
mapfile -t NOUNS < "$SCRIPT_DIR/nouns.txt"

# Select random adjective and noun
ADJ_INDEX=$((RANDOM % ${#ADJECTIVES[@]}))
NOUN_INDEX=$((RANDOM % ${#NOUNS[@]}))

# Output the generated name
echo "${ADJECTIVES[$ADJ_INDEX]}${SEPARATOR}${NOUNS[$NOUN_INDEX]}"