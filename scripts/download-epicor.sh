#!/bin/bash
set -e

# Download and extract Epicor package from web application

echo "Starting Epicor package download..."
echo "Library ID: $LIBRARY_ID"

# Create temp directory
TEMP_DIR="/tmp/epicor-package"
mkdir -p "$TEMP_DIR"

# Get library ID from parameter or use default
LIBRARY_ID="${1:-Scribe}"

# Prepare POST data
POST_DATA="{\"LibraryID\":\"$LIBRARY_ID\"}"

# Make POST request to Epicor API and get JSON response
echo "Downloading package from Epicor API..."
if [ -n "$EPICOR_BASIC_AUTH" ] && [ -n "$EPICOR_API_KEY" ]; then
    # Use both Basic Auth and API Key
    RESPONSE=$(curl -s \
        -X POST \
        -H "Content-Type: application/json; charset=utf-8" \
        -H "Authorization: Basic $EPICOR_BASIC_AUTH" \
        -H "X-API-Key: $EPICOR_API_KEY" \
        -d "$POST_DATA" \
        --fail \
        --show-error \
        "$EPICOR_URL")
elif [ -n "$EPICOR_BASIC_AUTH" ]; then
  
    # Use Basic Auth only
    RESPONSE=$(curl -s \
        -X POST \
        -H "Content-Type: application/json; charset=utf-8" \
        -H "Authorization: Basic $EPICOR_BASIC_AUTH" \
        ${EPICOR_API_KEY:+-H "X-API-Key: $EPICOR_API_KEY"} \
        -d "$POST_DATA" \
        --fail \
        --show-error \
        "$EPICOR_URL")
elif [ -n "$EPICOR_API_KEY" ]; then
    # Use API Key only
    RESPONSE=$(curl -s \
        -X POST \
        -H "Content-Type: application/json; charset=utf-8" \
        -H "X-API-Key: $EPICOR_API_KEY" \
        -d "$POST_DATA" \
        --fail \
        --show-error \
        "$EPICOR_URL")
else
    # No authentication
    RESPONSE=$(curl -s \
        -X POST \
        -H "Content-Type: application/json; charset=utf-8" \
        -d "$POST_DATA" \
        --fail \
        --show-error \
        "$EPICOR_URL")
fi

# Check if response is empty
if [ -z "$RESPONSE" ]; then
    echo "::error::Empty response from API"
    exit 1
fi

# Parse JSON response using jq
# Check for error in response
HAS_ERROR=$(echo "$RESPONSE" | jq -r '.Error // false')
if [ "$HAS_ERROR" = "true" ]; then
    ERROR_MESSAGE=$(echo "$RESPONSE" | jq -r '.Message // "Unknown error"')
    echo "::error::API Error: $ERROR_MESSAGE"
    exit 1
fi

# Extract base64 encoded zip file from JSON
BASE64_ZIP=$(echo "$RESPONSE" | jq -r '.Files // empty')
if [ -z "$BASE64_ZIP" ]; then
    echo "::error::No Files field found in API response"
    exit 1
fi

# Decode base64 and save as zip file
echo "Decoding base64 content..."
echo "$BASE64_ZIP" | base64 -d > "$TEMP_DIR/package.zip" || {
    echo "::error::Failed to decode base64 content"
    exit 1
}

# Verify download
if [ ! -f "$TEMP_DIR/package.zip" ]; then
    echo "::error::Failed to download package from $EPICOR_URL"
    exit 1
fi

# Get file size for logging
FILE_SIZE=$(du -h "$TEMP_DIR/package.zip" | cut -f1)
echo "Downloaded package size: $FILE_SIZE"

# Calculate hash for verification
PACKAGE_HASH=$(sha256sum "$TEMP_DIR/package.zip" | cut -d' ' -f1)
echo "Package SHA256: $PACKAGE_HASH"

# Extract ZIP
echo "Extracting package..."
unzip -q "$TEMP_DIR/package.zip" -d "$TEMP_DIR/extracted" || {
    echo "::error::Failed to extract package. The file might be corrupted."
    exit 1
}

# Find and count DLLs
echo "Analyzing package contents..."
find "$TEMP_DIR/extracted" -name "*.dll" -type f > /tmp/dll-list.txt
find "$TEMP_DIR/extracted" -name "*.cs" -type f > /tmp/cs-list.txt

# Count files
DLL_COUNT=$(wc -l < /tmp/dll-list.txt)
CS_COUNT=$(wc -l < /tmp/cs-list.txt)

echo "Found $DLL_COUNT DLL files"
echo "Found $CS_COUNT C# source files"

# Validate package contents
if [ "$DLL_COUNT" -eq 0 ] && [ "$CS_COUNT" -eq 0 ]; then
    echo "::error::No DLL or C# files found in the package"
    exit 1
fi

# Save metadata
cat > "$TEMP_DIR/metadata.json" <<EOF
{
  "download_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "package_hash": "$PACKAGE_HASH",
  "package_size": "$FILE_SIZE",
  "dll_count": $DLL_COUNT,
  "cs_count": $CS_COUNT,
  "source_url": "$EPICOR_URL"
}
EOF

# Set outputs for GitHub Actions
echo "dll_count=$DLL_COUNT" >> $GITHUB_OUTPUT
echo "cs_count=$CS_COUNT" >> $GITHUB_OUTPUT
echo "package_hash=$PACKAGE_HASH" >> $GITHUB_OUTPUT

# List some files for verification (first 10 of each type)
if [ "$DLL_COUNT" -gt 0 ]; then
    echo "Sample DLL files:"
    head -10 /tmp/dll-list.txt | while read dll; do
        echo "  - $(basename "$dll")"
    done
fi

if [ "$CS_COUNT" -gt 0 ]; then
    echo "Sample C# files:"
    head -10 /tmp/cs-list.txt | while read cs; do
        echo "  - $(basename "$cs")"
    done
fi

echo "Package download and extraction completed successfully!"
