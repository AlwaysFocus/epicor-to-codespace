#!/bin/bash
set -e

# Setup repository and folder structure

REPO_NAME="$1"
SUBFOLDER="$2"
ORG_NAME="${GITHUB_REPOSITORY_OWNER}"

echo "Setting up repository: $ORG_NAME/$REPO_NAME"

# Function to check if repository exists
check_repo_exists() {
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token $GH_PAT" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$ORG_NAME/$REPO_NAME")
    
    if [ "$http_code" = "200" ]; then
        return 0  # Repository exists
    else
        return 1  # Repository doesn't exist
    fi
}

# Function to create repository
create_repository() {
    echo "Creating new repository: $REPO_NAME"
    
    local response=$(curl -s -X POST \
        -H "Authorization: token $GH_PAT" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user/repos" \
        -d '{
            "name": "'"$REPO_NAME"'",
            "description": "Epicor project repository - Auto-generated",
            "private": true,
            "auto_init": true
        }')
    
    # Check if creation was successful
    local created_name=$(echo "$response" | jq -r '.name // empty')
    if [ -z "$created_name" ]; then
        echo "::error::Failed to create repository. Response: $response"
        exit 1
    fi
    
    echo "Repository created successfully!"
    
    # Wait for repository to be fully initialized
    sleep 5
}

# Check if repository exists
if check_repo_exists; then
    echo "Repository already exists: $ORG_NAME/$REPO_NAME"
    REPO_EXISTS="true"
else
    create_repository
    REPO_EXISTS="false"
fi

# Clone the repository
WORK_DIR="/tmp/repo-work"
rm -rf "$WORK_DIR"

echo "Cloning repository..."
git clone "https://${GH_PAT}@github.com/$ORG_NAME/$REPO_NAME.git" "$WORK_DIR"

cd "$WORK_DIR"

# Configure git
git config user.email "github-actions[bot]@users.noreply.github.com"
git config user.name "github-actions[bot]"

# Get default branch
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
git checkout "$DEFAULT_BRANCH"

# Create subfolder structure if specified
if [ -n "$SUBFOLDER" ]; then
    echo "Creating subfolder structure: $SUBFOLDER"
    mkdir -p "$SUBFOLDER"
    PROJECT_PATH="$SUBFOLDER"
else
    PROJECT_PATH="."
fi

# Create a marker file to track repository setup
SETUP_MARKER=".epicor-setup"
if [ -f "$PROJECT_PATH/$SETUP_MARKER" ]; then
    echo "Project already set up in $PROJECT_PATH. Will update with new content."
    PROJECT_EXISTS="true"
else
    echo "Setting up new project in $PROJECT_PATH"
    PROJECT_EXISTS="false"
    mkdir -p "$PROJECT_PATH"
    echo "{\"setup_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"version\": \"1.0\"}" > "$PROJECT_PATH/$SETUP_MARKER"
fi

# Set outputs for GitHub Actions
REPOSITORY_URL="https://github.com/$ORG_NAME/$REPO_NAME"
echo "repository_url=$REPOSITORY_URL" >> $GITHUB_OUTPUT
echo "project_path=$PROJECT_PATH" >> $GITHUB_OUTPUT
echo "work_dir=$WORK_DIR" >> $GITHUB_OUTPUT
echo "repo_exists=$REPO_EXISTS" >> $GITHUB_OUTPUT
echo "project_exists=$PROJECT_EXISTS" >> $GITHUB_OUTPUT

echo "Repository setup completed!"
echo "Repository URL: $REPOSITORY_URL"
echo "Project path: $PROJECT_PATH"
