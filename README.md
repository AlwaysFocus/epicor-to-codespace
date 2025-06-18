# Epicor GitHub Actions

A comprehensive set of GitHub Actions workflows for automating Epicor ERP development tasks, including bidirectional synchronization between Epicor and GitHub repositories.

## Available Workflows

### 1. Epicor to Codespace Setup
Downloads Epicor packages (DLLs and C# files) from your web application and sets up a complete .NET 8 development environment in GitHub Codespaces.

## Features

- 🚀 **Automated Repository Creation**: Creates new repositories or updates existing ones
- 📁 **Flexible Path Support**: Supports root-level projects or subfolder structures
- 📦 **Package Management**: Downloads and organizes DLLs and C# source files
- 🛠️ **.NET 8 Project Setup**: Configures a complete .NET 8 console application
- 💻 **Codespace Integration**: Automatically creates or updates GitHub Codespaces
- 🔧 **Development Ready**: Pre-configured with C# extensions and tools

## Prerequisites

1. A GitHub organization or personal account
2. Your epicor environment accessible via URL
3. GitHub Personal Access Token (PAT) with appropriate permissions
4. GitHub repository to host this workflow

## Setup Instructions

### Step 1: Fork or Copy This Repository

1. Fork this repository or copy all files to your GitHub organization
2. Ensure all files maintain their directory structure:
   ```
   .github/workflows/
     epicor-to-codespace.yml
   scripts/
     download-epicor.sh
     setup-repository.sh
     setup-dotnet-project.sh
     manage-codespace.sh
   .devcontainer/devcontainer.json
   ```

### Step 2: Configure GitHub Secrets

Navigate to your repository's Settings → Secrets and variables → Actions, and add the following secrets:

| Secret Name | Description | Required | Used By |
|-------------|-------------|----------|---------|
| `EPICOR_URL` | Your web application endpoint URL that returns the ZIP file (EpicorBaseURL/api/v2/efx/your_company/BootStrapBill/DownloadProject) | ✅ | Download |
| `EPICOR_BASE_URL` | Base URL for Epicor API | ✅ | Push | Note: Code note provided for push
| `EPICOR_API_KEY` | API key for authentication (if required) | ⚠️ | Both |
| `EPICOR_BASIC_AUTH` | Basic auth credentials in base64 (if required) | ⚠️ | Both |
| `GH_PAT` | GitHub Personal Access Token with repo and codespace permissions | ✅ | Download |
| `WEBHOOK_URL` | Webhook URL for error notifications (optional) | ❌ | Both |

#### Creating a GitHub Personal Access Token (PAT)

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Select the following permissions:
   - `repo` (Full control of private repositories)
   - `workflow` (Update GitHub Action workflows)
   - `codespace` (Create and manage codespaces)
4. Copy the token and save it as the `GH_PAT` secret

### Step 3: Make Scripts Executable

The workflow will automatically make scripts executable, but if you need to test locally:

```bash
chmod +x scripts/*.sh
```

## Usage

### Epicor to Codespace Setup

#### Method 1: Manual Trigger (GitHub UI)

1. Go to your repository on GitHub
2. Click on the "Actions" tab
3. Select "Epicor to Codespace Setup" workflow
4. Click "Run workflow"
5. Enter the repository path (e.g., `my-epicor-project` or `existing-repo/epicor-module`)
6. Click "Run workflow"

#### Method 2: API Trigger

```bash
# Using curl
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token YOUR_GH_PAT" \
  https://api.github.com/repos/YOUR_ORG/YOUR_REPO/dispatches \
  -d '{
    "event_type": "epicor-setup",
    "client_payload": {
      "repository_path": "my-epicor-project"
    }
  }'
```


## Repository Path Examples

| Input | Result |
|-------|--------|
| `my-project` | Creates/updates repository `my-project` with project in root |
| `my-project/module1` | Creates/updates repository `my-project` with project in `module1` folder |
| `existing-repo/new-module` | Updates existing repository with new project in `new-module` folder |

## Project Structure

After the workflow completes, your repository will have:

```
your-repo/
├── .devcontainer/
│   └── devcontainer.json      # Codespace configuration
├── EpicorProject/             # Or in subfolder if specified
│   ├── lib/                   # All DLL files from Epicor
│   ├── src/                   # All C# source files
│   ├── EpicorProject.csproj   # .NET 8 project file
│   ├── Program.cs             # Entry point
│   ├── appsettings.json       # Configuration
│   └── .gitignore             # Git ignore rules
├── EpicorProject.sln          # Solution file
└── README.md                  # Project documentation
```

## Workflow Outputs

The workflow provides:
- **Codespace URL**: Direct link to open the Codespace
- **Repository URL**: Link to the created/updated repository
- **Summary**: Detailed information in GitHub Actions summary

## Authentication Options

The download script supports multiple authentication methods:

1. **No Authentication**: If your endpoint is public
2. **API Key Only**: Uses `X-API-Key` header
3. **Basic Auth Only**: Uses `Authorization: Basic` header
4. **Both**: Uses both API Key and Basic Auth headers

## Troubleshooting

### Common Issues

1. **"Failed to create repository"**
   - Ensure your PAT has `repo` permissions
   - Check if the repository name is valid (alphanumeric, hyphens, underscores)

2. **"Failed to download package"**
   - Verify `EPICOR_URL` is correct
   - Check authentication credentials
   - Ensure the endpoint returns a valid ZIP file

3. **"Failed to create Codespace"**
   - Verify PAT has `codespace` permissions
   - Check your Codespace usage limits
   - Try with a smaller machine type

4. **"Build errors in .NET project"**
   - This is often expected if DLLs have dependencies
   - The project will still be created and can be fixed in Codespace



### Viewing Logs

1. Go to Actions tab in your repository
2. Click on the workflow run
3. Click on the job to see detailed logs
4. Check the step that failed for specific error messages

## Security Considerations

- All secrets are encrypted and never exposed in logs
- Use private repositories for sensitive code
- Regularly rotate your PAT and API keys
- Consider using GitHub Apps instead of PATs for production use
- The workflow validates input paths to prevent injection attacks

## Customization

### Modifying the .NET Project Template

Edit `scripts/setup-dotnet-project.sh` to:
- Change the project type (web, library, etc.)
- Add additional NuGet packages
- Modify the project structure
- Change framework version

### Changing Codespace Configuration

Edit `.devcontainer/devcontainer.json` to:
- Add more VS Code extensions
- Change the base image
- Modify system requirements
- Add additional development tools

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review workflow logs in GitHub Actions
3. Ensure all prerequisites are met
4. Verify secret values are correct


### Response Handling

The workflow:
- Retries failed uploads (up to 3 attempts)
- Reports status for each function (SUCCESSFUL/UNSUCCESSFUL)
- Generates summary in GitHub Actions
- Sends webhook notifications on failure

## License

This project is licensed under the [Creative Commons Attribution-NonCommercial 4.0 International License (CC BY-NC 4.0)](https://creativecommons.org/licenses/by-nc/4.0/).

**You are free to:**

*   **Share** — copy and redistribute the material in any medium or format.
*   **Adapt** — remix, transform, and build upon the material.

**Under the following terms:**

*   **Attribution** — You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
*   **NonCommercial** — You may not use the material for commercial purposes.

For more details, see the [LICENSE](LICENSE) file.
