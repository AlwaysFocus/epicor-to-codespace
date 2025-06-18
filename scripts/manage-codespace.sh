#!/bin/bash
set -e

# Manage GitHub Codespace creation and updates

REPO_NAME="$1"
ORG_NAME="${GITHUB_REPOSITORY_OWNER}"

echo "Managing Codespace for repository: $ORG_NAME/$REPO_NAME"

# First, let's commit and push all changes
cd /tmp/repo-work

# Add all changes
git add -A

# Create commit message with details
COMMIT_MSG="Update Epicor project with latest packages

- Added/Updated DLLs and C# source files
- Configured .NET 8 project structure
- Set up development environment
"

# Commit changes
git commit -m "$COMMIT_MSG" || echo "No changes to commit"

# Push to remote
echo "Pushing changes to repository..."
git push origin HEAD

# Create README if it doesn't exist
if [ ! -f README.md ]; then
    cat > README.md << EOF
# Epicor Project

This project was automatically generated from Epicor packages.

## Project Structure
- **lib/**: Contains all referenced DLL files from Epicor
- **src/**: Contains all C# source files from Epicor
- **.devcontainer/**: Codespace configuration with .NET 8 and C# extensions

## Getting Started in Codespace
1. Open this repository in GitHub Codespaces
2. The environment will automatically set up with .NET 8 and all required extensions
3. Run \`dotnet build\` to build the project
4. Run \`dotnet run\` to execute the application

## Project Configuration
- Framework: .NET 8.0
- Language: C# (latest version)
- IDE: Visual Studio Code with C# extensions

## Development
The project is pre-configured with:
- Microsoft.Extensions.DependencyInjection
- Microsoft.Extensions.Logging
- Microsoft.Extensions.Configuration
- Newtonsoft.Json

All Epicor DLLs are referenced from the \`lib\` folder and will be copied to the output directory during build.
EOF
    
    git add README.md
    git commit -m "Add README.md" || true
    git push origin HEAD
fi

# Check if a Codespace already exists for this repository
echo "Checking for existing Codespaces..."
EXISTING_CODESPACES=$(curl -s \
    -H "Authorization: token $GH_PAT" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/user/codespaces" | \
    jq -r --arg repo "$REPO_NAME" --arg org "$ORG_NAME" \
    '.codespaces[] | select(.repository.name == $repo and .owner.login == $org) | .name' | \
    head -n1)

if [ -n "$EXISTING_CODESPACES" ] && [ "$EXISTING_CODESPACES" != "null" ]; then
    echo "Found existing Codespace: $EXISTING_CODESPACES"
    CODESPACE_NAME="$EXISTING_CODESPACES"
    
    # Stop the codespace if it's running (to trigger rebuild on next start)
    echo "Stopping Codespace to apply updates..."
    curl -s -X POST \
        -H "Authorization: token $GH_PAT" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user/codespaces/$CODESPACE_NAME/stop" || true
    
    sleep 2
else
    echo "Creating new Codespace..."
    
    # Create the Codespace
    CREATE_RESPONSE=$(curl -s -X POST \
        -H "Authorization: token $GH_PAT" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$ORG_NAME/$REPO_NAME/codespaces" \
        -d '{
            "ref": "main",
            "devcontainer_path": ".devcontainer/devcontainer.json",
            "idle_timeout_minutes": 30,
            "retention_period_minutes": 10080,
            "machine": "basicLinux32gb"
        }')
    
    CODESPACE_NAME=$(echo "$CREATE_RESPONSE" | jq -r '.name // empty')
    
    if [ -z "$CODESPACE_NAME" ]; then
        echo "::error::Failed to create Codespace"
        echo "Response: $CREATE_RESPONSE"
        
        # Try with a smaller machine type as fallback
        echo "Retrying with smaller machine type..."
        CREATE_RESPONSE=$(curl -s -X POST \
            -H "Authorization: token $GH_PAT" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$ORG_NAME/$REPO_NAME/codespaces" \
            -d '{
                "ref": "main",
                "devcontainer_path": ".devcontainer/devcontainer.json",
                "idle_timeout_minutes": 30,
                "retention_period_minutes": 10080
            }')
        
        CODESPACE_NAME=$(echo "$CREATE_RESPONSE" | jq -r '.name // empty')
        
        if [ -z "$CODESPACE_NAME" ]; then
            echo "::error::Failed to create Codespace even with default machine type"
            echo "Response: $CREATE_RESPONSE"
            exit 1
        fi
    fi
    
    echo "Created new Codespace: $CODESPACE_NAME"
fi

# Wait for Codespace to be ready
echo "Waiting for Codespace to be ready..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    CODESPACE_STATE=$(curl -s \
        -H "Authorization: token $GH_PAT" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user/codespaces/$CODESPACE_NAME" | \
        jq -r '.state // empty')
    
    if [ "$CODESPACE_STATE" = "Available" ] || [ "$CODESPACE_STATE" = "Idle" ]; then
        echo "Codespace is ready!"
        break
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
    echo "Codespace state: $CODESPACE_STATE (attempt $ATTEMPT/$MAX_ATTEMPTS)"
    
    if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
        echo "::warning::Codespace creation is taking longer than expected. It will be ready soon."
        break
    fi
    
    sleep 10
done

# Construct Codespace URL
CODESPACE_URL="https://github.com/codespaces/${CODESPACE_NAME}"

# Alternative URL format that opens VS Code in browser
VSCODE_URL="https://${CODESPACE_NAME}.github.dev/"

# Set outputs
echo "url=$CODESPACE_URL" >> $GITHUB_OUTPUT
echo "vscode_url=$VSCODE_URL" >> $GITHUB_OUTPUT
echo "name=$CODESPACE_NAME" >> $GITHUB_OUTPUT

echo "========================================="
echo "Codespace setup completed!"
echo "========================================="
echo "Codespace Name: $CODESPACE_NAME"
echo "GitHub URL: $CODESPACE_URL"
echo "VS Code URL: $VSCODE_URL"
echo "========================================="