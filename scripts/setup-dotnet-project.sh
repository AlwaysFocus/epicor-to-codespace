#!/bin/bash
set -e

# Setup .NET 8 project with Epicor DLLs and C# files

REPO_NAME="$1"
SUBFOLDER="$2"
ORG_NAME="${GITHUB_REPOSITORY_OWNER}"

# Navigate to working directory
cd /tmp/repo-work

# Determine project path
if [ -n "$SUBFOLDER" ]; then
    PROJECT_PATH="$SUBFOLDER"
else
    PROJECT_PATH="."
fi

cd "$PROJECT_PATH"

# Check if a .csproj file already exists
EXISTING_CSPROJ=$(find . -maxdepth 1 -name "*.csproj" -type f | head -n 1)

if [ -n "$EXISTING_CSPROJ" ]; then
    echo "Found existing project: $EXISTING_CSPROJ"
    PROJECT_NAME=$(basename "$EXISTING_CSPROJ" .csproj)
    echo "Updating existing project: $PROJECT_NAME"
else
    echo "Creating new .NET 8 console project..."
    PROJECT_NAME="EpicorProject"
    dotnet new console -n "$PROJECT_NAME" -f net8.0 --force
    cd "$PROJECT_NAME"
fi

# Create directory structure
echo "Setting up project directories..."
mkdir -p lib
mkdir -p src
mkdir -p src/Generated
mkdir -p src/Models
mkdir -p src/Services

# Copy DLLs to lib folder
echo "Copying DLL files to lib folder..."
DLL_COUNT=0
if [ -f /tmp/dll-list.txt ]; then
    # Check if the file is not empty
    if [ -s /tmp/dll-list.txt ]; then
        while IFS= read -r dll; do
            if [ -f "$dll" ]; then
                cp "$dll" lib/ || {
                    echo "Warning: Failed to copy $dll"
                    continue
                }
                DLL_COUNT=$((DLL_COUNT + 1))
                # Debug: Show progress for first few files
                if [ $DLL_COUNT -le 5 ]; then
                    echo "  Copied: $(basename "$dll")"
                fi
            else
                echo "Warning: DLL file not found: $dll"
            fi
        done < /tmp/dll-list.txt
    else
        echo "Warning: /tmp/dll-list.txt is empty"
    fi
else
    echo "Warning: /tmp/dll-list.txt not found"
fi
echo "Copied $DLL_COUNT DLL files"

# Copy C# source files to src folder
echo "Copying C# source files to src folder..."
CS_COUNT=0
if [ -f /tmp/cs-list.txt ]; then
    # Check if the file is not empty
    if [ -s /tmp/cs-list.txt ]; then
        while IFS= read -r cs; do
            if [ -f "$cs" ]; then
                # Get the relative path from the extracted folder
                rel_path=$(realpath --relative-to=/tmp/epicor-package/extracted "$cs" 2>/dev/null || basename "$cs")
                dir_path=$(dirname "$rel_path")
                
                # Create directory structure in src
                if [ "$dir_path" != "." ]; then
                    mkdir -p "src/$dir_path"
                fi
                
                # Copy the file
                cp "$cs" "src/$rel_path" || {
                    echo "Warning: Failed to copy $cs"
                    continue
                }
                CS_COUNT=$((CS_COUNT + 1))
                # Debug: Show progress for first few files
                if [ $CS_COUNT -le 5 ]; then
                    echo "  Copied: $rel_path"
                fi
            else
                echo "Warning: C# file not found: $cs"
            fi
        done < /tmp/cs-list.txt
    else
        echo "Warning: /tmp/cs-list.txt is empty"
    fi
else
    echo "Warning: /tmp/cs-list.txt not found"
fi
echo "Copied $CS_COUNT C# files"

# Create or update .csproj file
echo "Configuring project file..."
cat > "$PROJECT_NAME.csproj" << 'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <LangVersion>latest</LangVersion>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <RootNamespace>EpicorProject</RootNamespace>
  </PropertyGroup>
  
  <ItemGroup>
    <!-- Reference all DLLs in lib folder -->
    <Reference Include="lib\*.dll">
      <Private>true</Private>
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </Reference>
  </ItemGroup>
  
  <ItemGroup>
    <!-- Include all C# files from src folder -->
    <Compile Include="src\**\*.cs" />
    <!-- Remove the default Program.cs if we have one in src -->
    <Compile Remove="Program.cs" Condition="Exists('src\Program.cs')" />
  </ItemGroup>
  
  <ItemGroup>
    <!-- Common packages for Epicor development -->
    <PackageReference Include="Microsoft.Extensions.DependencyInjection" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Logging" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Configuration" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Configuration.Json" Version="8.0.0" />
    <PackageReference Include="Newtonsoft.Json" Version="13.0.3" />
  </ItemGroup>
</Project>
EOF

# Create a basic Program.cs if none exists in src
if [ ! -f "src/Program.cs" ] && [ ! -f "Program.cs" ]; then
    echo "Creating default Program.cs..."
    cat > Program.cs << 'EOF'
using System;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace EpicorProject
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("=================================");
            Console.WriteLine("Epicor Project - .NET 8");
            Console.WriteLine("=================================");
            Console.WriteLine();
            
            // Set up dependency injection
            var services = new ServiceCollection();
            ConfigureServices(services);
            
            var serviceProvider = services.BuildServiceProvider();
            var logger = serviceProvider.GetRequiredService<ILogger<Program>>();
            
            logger.LogInformation("Application started");
            
            try
            {
                // Display project information
                Console.WriteLine($"DLLs loaded from: {System.IO.Path.GetFullPath("lib")}");
                Console.WriteLine($"Source files loaded from: {System.IO.Path.GetFullPath("src")}");
                Console.WriteLine();
                
                // List loaded DLLs
                var dllFiles = System.IO.Directory.GetFiles("lib", "*.dll");
                Console.WriteLine($"Loaded {dllFiles.Length} DLL files");
                
                // Add your Epicor-specific initialization code here
                Console.WriteLine("Ready to use Epicor components!");
                
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Application error");
                Console.WriteLine($"Error: {ex.Message}");
            }
            
            Console.WriteLine();
            Console.WriteLine("Press any key to exit...");
            Console.ReadKey();
        }
        
        static void ConfigureServices(IServiceCollection services)
        {
            // Configure logging
            services.AddLogging(configure => configure.AddConsole());
            
            // Add your services here
            // services.AddSingleton<IMyService, MyService>();
        }
    }
}
EOF
fi

# Create appsettings.json
echo "Creating appsettings.json..."
cat > appsettings.json << 'EOF'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "Microsoft.Hosting.Lifetime": "Information"
    }
  },
  "Epicor": {
    "ApiUrl": "",
    "ApiKey": "",
    "Environment": "Development"
  }
}
EOF

# Create .gitignore if it doesn't exist
if [ ! -f .gitignore ]; then
    echo "Creating .gitignore..."
    cat > .gitignore << 'EOF'
## Ignore Visual Studio temporary files, build results, and
## files generated by popular Visual Studio add-ons.

# User-specific files
*.rsuser
*.suo
*.user
*.userosscache
*.sln.docstates

# Build results
[Dd]ebug/
[Dd]ebugPublic/
[Rr]elease/
[Rr]eleases/
x64/
x86/
[Ww][Ii][Nn]32/
[Aa][Rr][Mm]/
[Aa][Rr][Mm]64/
bld/
[Bb]in/
[Oo]bj/
[Ll]og/
[Ll]ogs/

# Visual Studio cache/options directory
.vs/

# .NET
project.lock.json
project.fragment.lock.json
artifacts/

# Files built by Visual Studio
*.pidb
*.svclog
*.scc

# Visual Studio Code
.vscode/*
!.vscode/settings.json
!.vscode/tasks.json
!.vscode/launch.json
!.vscode/extensions.json
*.code-workspace

# Rider
.idea/
*.sln.iml

# User-specific files
*.suo
*.user
*.userosscache
*.sln.docstates

# NuGet Packages
*.nupkg
*.snupkg
# The packages folder can be ignored because of Package Restore
**/[Pp]ackages/*
# except build/, which is used as an MSBuild target.
!**/[Pp]ackages/build/
# Uncomment if necessary however generally it will be regenerated when needed
#!**/[Pp]ackages/repositories.config
# NuGet v3's project.json files produces more ignorable files
*.nuget.props
*.nuget.targets
EOF
fi

# Navigate back to repository root
cd /tmp/repo-work

# Copy .devcontainer configuration from source repository
echo "Setting up dev container configuration..."
if [ -d "$GITHUB_WORKSPACE/.devcontainer" ]; then
    cp -r "$GITHUB_WORKSPACE/.devcontainer" .devcontainer
    echo "Dev container configuration copied successfully"
else
    echo "Warning: No .devcontainer directory found in source repository"
    # Create a minimal devcontainer.json if source doesn't exist
    mkdir -p .devcontainer
    cat > .devcontainer/devcontainer.json << 'EOF'
{
  "name": "Epicor .NET 8 Development",
  "image": "mcr.microsoft.com/devcontainers/dotnet:1-8.0",
  "features": {
    "ghcr.io/devcontainers/features/dotnet:2": {
      "version": "8.0",
      "additionalVersions": "7.0"
    },
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/devcontainers/features/common-utils:2": {
      "installZsh": true,
      "configureZshAsDefaultShell": true,
      "username": "vscode",
      "upgradePackages": true
    }
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-dotnettools.csharp",
        "ms-dotnettools.vscode-dotnet-runtime",
        "ms-dotnettools.csdevkit",
        "ms-vscode.vscode-typescript-next",
        "streetsidesoftware.code-spell-checker",
        "editorconfig.editorconfig",
        "redhat.vscode-xml",
        "formulahendry.dotnet-test-explorer",
        "ryanluker.vscode-coverage-gutters",
        "eamodio.gitlens",
        "mhutchie.git-graph",
        "donjayamanne.githistory"
      ],
      "settings": {
        "dotnet.defaultSolution": "*.sln",
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
          "source.organizeImports": true,
          "source.fixAll": true
        },
        "files.exclude": {
          "**/bin": true,
          "**/obj": true,
          "**/.vs": true
        },
        "omnisharp.enableRoslynAnalyzers": true,
        "omnisharp.enableEditorConfigSupport": true,
        "csharp.semanticHighlighting.enabled": true,
        "csharp.inlayHints.enableInlayHintsForParameters": true,
        "csharp.inlayHints.enableInlayHintsForLiteralParameters": true,
        "csharp.inlayHints.enableInlayHintsForIndexerParameters": true,
        "csharp.inlayHints.enableInlayHintsForObjectCreationParameters": true,
        "csharp.inlayHints.enableInlayHintsForOtherParameters": true,
        "csharp.inlayHints.suppressInlayHintsForParametersThatDifferOnlyBySuffix": true,
        "csharp.inlayHints.suppressInlayHintsForParametersThatMatchMethodIntent": true,
        "csharp.inlayHints.suppressInlayHintsForParametersThatMatchArgumentName": true,
        "csharp.inlayHints.enableInlayHintsForTypes": true,
        "csharp.inlayHints.enableInlayHintsForImplicitVariableTypes": true,
        "csharp.inlayHints.enableInlayHintsForLambdaParameterTypes": true,
        "csharp.inlayHints.enableInlayHintsForImplicitObjectCreation": true
      }
    }
  },
  "postCreateCommand": "dotnet restore && dotnet build || echo 'Build completed with warnings'",
  "postStartCommand": "dotnet dev-certs https",
  "remoteUser": "vscode",
  "mounts": [],
  "forwardPorts": [5000, 5001],
  "portsAttributes": {
    "5000": {
      "label": "HTTP",
      "onAutoForward": "notify"
    },
    "5001": {
      "label": "HTTPS",
      "onAutoForward": "notify"
    }
  },
  "hostRequirements": {
    "cpus": 2,
    "memory": "4gb",
    "storage": "32gb"
  }
}
EOF
    echo "Created default dev container configuration"
fi

# Create or update solution file
SOLUTION_FILE="${PROJECT_NAME}.sln"
if [ ! -f "$SOLUTION_FILE" ]; then
    echo "Creating solution file..."
    dotnet new sln -n "$PROJECT_NAME" --force
fi

# Add project to solution
echo "Adding project to solution..."
if [ -n "$SUBFOLDER" ]; then
    dotnet sln add "$PROJECT_PATH/$PROJECT_NAME/$PROJECT_NAME.csproj" || true
else
    dotnet sln add "$PROJECT_NAME/$PROJECT_NAME.csproj" || true
fi

# Try to restore packages
echo "Restoring NuGet packages..."
cd "$PROJECT_PATH/$PROJECT_NAME"
dotnet restore || echo "Warning: Package restore completed with warnings"

# Try to build the project
echo "Attempting to build project..."
dotnet build --no-restore || echo "Warning: Build completed with errors. This is expected if there are unresolved dependencies."

echo "Project setup completed!"
echo "Project location: $PROJECT_PATH/$PROJECT_NAME"