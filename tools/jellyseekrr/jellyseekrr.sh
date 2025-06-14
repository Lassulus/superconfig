#!/usr/bin/env bash
set -euo pipefail

# Configuration
JELLYSEERR_URL="https://flox.lassul.us"

# Get API key from pass or environment
JELLYSEERR_API_KEY="${JELLYSEERR_API_KEY:-$(pass show www/flox.lassul.us/api_key 2>/dev/null | tr -d '\n' || true)}"

# Check if API key is available
if [[ -z "$JELLYSEERR_API_KEY" ]]; then
    echo "Error: Could not retrieve API key" >&2
    echo "Set JELLYSEERR_API_KEY environment variable or ensure 'pass show www/flox.lassul.us/api_key' works" >&2
    exit 1
fi

# Get search query from command line or prompt
if [[ $# -eq 0 ]]; then
    echo "Usage: jellyseerr <search_query>" >&2
    echo "Example: jellyseerr 'The Matrix'" >&2
    exit 1
fi

search_query="$*"

# Create a temporary cookie jar
COOKIE_JAR=$(mktemp)
trap 'rm -f "$COOKIE_JAR"' EXIT

# Function to authenticate and get session
authenticate() {
    # Try to authenticate with the API key
    local auth_response
    auth_response=$(curl -s \
        -c "$COOKIE_JAR" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"api\",\"password\":\"$JELLYSEERR_API_KEY\"}" \
        "${JELLYSEERR_URL}/api/v1/auth/local")
    
    if ! echo "$auth_response" | jq -e '.id' > /dev/null 2>&1; then
        echo "Warning: Authentication failed, trying direct API key approach" >&2
        return 1
    fi
    return 0
}

# Function to search for content
search_content() {
    local query="$1"
    
    # First try with API key header
    local response
    response=$(curl -s \
        -H "X-Api-Key: $JELLYSEERR_API_KEY" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        "${JELLYSEERR_URL}/api/v1/search?query=$(printf '%s' "$query" | jq -sRr @uri)")
    
    # If that fails with cookie error, try with session
    if echo "$response" | grep -q "cookie.*required"; then
        authenticate || {
            echo "Failed to authenticate" >&2
            exit 1
        }
        response=$(curl -s \
            -b "$COOKIE_JAR" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            "${JELLYSEERR_URL}/api/v1/search?query=$(printf '%s' "$query" | jq -sRr @uri)")
    fi
    
    echo "$response"
}

# Function to request content
request_content() {
    local media_type="$1"
    local media_id="$2"
    local title="$3"
    
    local request_data
    if [[ "$media_type" == "movie" ]]; then
        request_data=$(jq -n \
            --arg mediaType "movie" \
            --argjson mediaId "$media_id" \
            '{
                mediaType: $mediaType,
                mediaId: $mediaId
            }')
    else
        # For TV shows, request all seasons
        request_data=$(jq -n \
            --arg mediaType "tv" \
            --argjson mediaId "$media_id" \
            '{
                mediaType: $mediaType,
                mediaId: $mediaId,
                seasons: "all"
            }')
    fi
    
    local response
    # Try with API key first, then with cookies if that fails
    response=$(curl -s \
        -X POST \
        -H "X-Api-Key: $JELLYSEERR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$request_data" \
        "${JELLYSEERR_URL}/api/v1/request")
    
    # If that fails with cookie error, use session cookies
    if echo "$response" | grep -q "cookie.*required"; then
        response=$(curl -s \
            -X POST \
            -b "$COOKIE_JAR" \
            -H "Content-Type: application/json" \
            -d "$request_data" \
            "${JELLYSEERR_URL}/api/v1/request")
    fi
    
    if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
        echo "✓ Successfully requested: $title"
    else
        echo "✗ Failed to request: $title"
        echo "Response: $response" >&2
    fi
}

# Search for content
echo "Searching for: $search_query" >&2
search_results=$(search_content "$search_query")

# Check if search was successful
if ! echo "$search_results" | jq -e '.results' > /dev/null 2>&1; then
    echo "Error: Search failed or no results found" >&2
    echo "Response: $search_results" >&2
    exit 1
fi

# Parse results and create menu options
menu_options=$(echo "$search_results" | jq -r '
    .results[] | 
    select(.mediaType == "movie" or .mediaType == "tv") |
    [
        .id,
        .mediaType,
        .title // .name,
        (.releaseDate // .firstAirDate // "Unknown" | split("-")[0]),
        (.overview // "No description available" | .[0:100] + if length > 100 then "..." else "" end)
    ] |
    "\(.[0])|\(.[1])|\(.[2]) (\(.[3])) - \(.[4])"
')

if [[ -z "$menu_options" ]]; then
    echo "No movies or TV shows found for: $search_query" >&2
    exit 1
fi

# Show menu and get selection
selected=$(echo "$menu_options" | menu)

if [[ -z "$selected" ]]; then
    echo "No selection made" >&2
    exit 0
fi

# Parse selection
media_id=$(echo "$selected" | cut -d'|' -f1)
media_type=$(echo "$selected" | cut -d'|' -f2)
title=$(echo "$selected" | cut -d'|' -f3)

# Request the selected content
echo "Requesting: $title" >&2
request_content "$media_type" "$media_id" "$title"