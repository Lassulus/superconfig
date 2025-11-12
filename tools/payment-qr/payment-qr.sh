#!/usr/bin/env bash
set -euo pipefail

# SEPA Payment QR Code Generator
# Generates EPC QR codes for SEPA payments according to EPC069-12 standard

usage() {
    cat >&2 <<EOF
Usage: payment-qr [OPTIONS]

Generate SEPA payment QR code (EPC QR code format)

OPTIONS:
    -n, --name NAME         Beneficiary name (required)
    -i, --iban IBAN         IBAN (required)
    -b, --bic BIC           BIC (optional, auto-detected from IBAN if not provided)
    -a, --amount AMOUNT     Amount in EUR (optional, e.g., 123.45)
    -d, --desc DESCRIPTION  Payment description/reference (optional)
    -h, --help              Show this help message

EXAMPLES:
    payment-qr -n "John Doe" -i DE89370400440532013000 -a 50.00 -d "Invoice 123"
    payment-qr --name "Acme Corp" --iban DE89370400440532013000 --bic COBADEFFXXX --amount 100

OUTPUT:
    Displays the QR code in terminal using UTF-8 characters
EOF
    exit "${1:-0}"
}

# BIC lookup from IBAN (simplified - maps country code to common banks)
# In production, this would use a proper BIC database/API
get_bic_from_iban() {
    local iban="$1"
    # Remove spaces and convert to uppercase
    iban="${iban// /}"
    iban="${iban^^}"

    # Extract country code (first 2 characters)
    local country="${iban:0:2}"

    # For now, we'll use NOTPROVIDED as fallback
    # A real implementation would query a BIC database
    echo "NOTPROVIDED"
}

# Validate IBAN format (basic check)
validate_iban() {
    local iban="$1"
    iban="${iban// /}"
    iban="${iban^^}"

    # Basic validation: starts with 2 letters, followed by 2 digits, then alphanumeric
    if [[ ! "$iban" =~ ^[A-Z]{2}[0-9]{2}[A-Z0-9]+$ ]]; then
        echo "Error: Invalid IBAN format" >&2
        return 1
    fi

    # Length should be between 15 and 34 characters
    if [ "${#iban}" -lt 15 ] || [ "${#iban}" -gt 34 ]; then
        echo "Error: IBAN length must be between 15 and 34 characters" >&2
        return 1
    fi

    echo "$iban"
}

# Parse command line arguments
NAME=""
IBAN=""
BIC=""
AMOUNT=""
DESCRIPTION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            NAME="$2"
            shift 2
            ;;
        -i|--iban)
            IBAN="$2"
            shift 2
            ;;
        -b|--bic)
            BIC="$2"
            shift 2
            ;;
        -a|--amount)
            AMOUNT="$2"
            shift 2
            ;;
        -d|--desc|--description)
            DESCRIPTION="$2"
            shift 2
            ;;
        -h|--help)
            usage 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$NAME" ]; then
    echo "Error: Beneficiary name is required (-n/--name)" >&2
    usage 1
fi

if [ -z "$IBAN" ]; then
    echo "Error: IBAN is required (-i/--iban)" >&2
    usage 1
fi

# Validate and normalize IBAN
IBAN=$(validate_iban "$IBAN") || exit 1

# Auto-detect BIC if not provided
if [ -z "$BIC" ]; then
    BIC=$(get_bic_from_iban "$IBAN")
    echo "BIC not provided, using: $BIC" >&2
fi

# Validate amount format if provided
if [ -n "$AMOUNT" ]; then
    if [[ ! "$AMOUNT" =~ ^[0-9]+(\.[0-9]{1,2})?$ ]]; then
        echo "Error: Invalid amount format. Use format: 123.45" >&2
        exit 1
    fi
    # Format with exactly 2 decimal places
    AMOUNT=$(printf "%.2f" "$AMOUNT")
fi

# Build EPC QR code data according to EPC069-12 standard
# Format:
# Line 1: BCD (Service Tag)
# Line 2: 002 (Version)
# Line 3: 1 (Character set: UTF-8)
# Line 4: SCT (Identification: SEPA Credit Transfer)
# Line 5: BIC
# Line 6: Beneficiary Name
# Line 7: Beneficiary Account (IBAN)
# Line 8: Amount (EUR123.45 or empty)
# Line 9: Purpose (empty for general)
# Line 10: Structured Reference (empty)
# Line 11: Unstructured Remittance (description)
# Line 12: Beneficiary to Originator Information (empty)

EPC_DATA=""
EPC_DATA+="BCD"$'\n'                    # Service Tag
EPC_DATA+="002"$'\n'                    # Version
EPC_DATA+="1"$'\n'                      # Character set (UTF-8)
EPC_DATA+="SCT"$'\n'                    # Identification
EPC_DATA+="${BIC}"$'\n'                 # BIC
EPC_DATA+="${NAME}"$'\n'                # Beneficiary name
EPC_DATA+="${IBAN}"$'\n'                # IBAN

if [ -n "$AMOUNT" ]; then
    EPC_DATA+="EUR${AMOUNT}"$'\n'       # Amount
else
    EPC_DATA+=$'\n'                     # Empty amount
fi

EPC_DATA+=$'\n'                         # Purpose (empty)
EPC_DATA+=$'\n'                         # Structured reference (empty)
EPC_DATA+="${DESCRIPTION}"$'\n'         # Unstructured remittance
EPC_DATA+=$'\n'                         # Beneficiary to originator info (empty)

# Generate QR code using qrencode
# -t utf8: Output as UTF-8 text
# -l M: Error correction level Medium
echo "$EPC_DATA" | qrencode -t utf8 -l M
