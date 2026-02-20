#!/bin/bash

# import_skill.sh
# Usage: ./import_skill.sh <github_url>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <github_url>"
    exit 1
fi

GITHUB_URL=$1

# Basic URL validation and extraction
# Example: https://github.com/sickn33/antigravity-awesome-skills/tree/main/skills/api-documentation-generator
if [[ $GITHUB_URL =~ github\.com/([^/]+)/([^/]+)/(tree|blob)/([^/]+)/(.*) ]]; then
    OWNER=${BASH_REMATCH[1]}
    REPO=${BASH_REMATCH[2]}
    BRANCH=${BASH_REMATCH[4]}
    FILE_PATH=${BASH_REMATCH[5]}
else
    echo "Error: Invalid GitHub URL format."
    echo "Expected format: https://github.com/OWNER/REPO/tree/BRANCH/PATH"
    exit 1
fi

SKILL_NAME=$(basename "$FILE_PATH")
TARGET_DIR="skills/$SKILL_NAME"

echo "Importing skill: $SKILL_NAME"
echo "From: $OWNER/$REPO ($BRANCH) at $FILE_PATH"

mkdir -p "$TARGET_DIR"

download_content() {
    local path=$1
    local local_dest=$2
    
    local api_url="https://api.github.com/repos/$OWNER/$REPO/contents/$path?ref=$BRANCH"
    local response=$(curl -s "$api_url")
    
    # Check if response is an error object
    if echo "$response" | jq -e 'type == "object" and .message != null' > /dev/null; then
        echo "Error from GitHub API: $(echo "$response" | jq -r '.message')"
        return 1
    fi

    # Handle single file vs directory
    if echo "$response" | jq -e 'type == "array"' > /dev/null; then
        # Directory
        mkdir -p "$local_dest"
        echo "$response" | jq -c '.[]' | while read -r item; do
            local item_name=$(echo "$item" | jq -r '.name')
            local item_path=$(echo "$item" | jq -r '.path')
            local item_type=$(echo "$item" | jq -r '.type')
            
            if [ "$item_type" == "dir" ]; then
                download_content "$item_path" "$local_dest/$item_name"
            else
                local download_url=$(echo "$item" | jq -r '.download_url')
                echo "Downloading: $item_path"
                curl -sL "$download_url" -o "$local_dest/$item_name"
            fi
        done
    else
        # Single file
        local download_url=$(echo "$response" | jq -r '.download_url')
        local file_name=$(echo "$response" | jq -r '.name')
        echo "Downloading: $path"
        curl -sL "$download_url" -o "$local_dest/$file_name"
    fi
}

download_content "$FILE_PATH" "$TARGET_DIR"

echo "Done! Skill imported to: $TARGET_DIR"
