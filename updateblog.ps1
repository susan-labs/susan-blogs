param(
    [string]$SourcePath = "C:\MyBlogs\MyBlogs\BlogPosts",
    [string]$DestinationPath = "",
    [string]$RepoUrl = "git@github.com:susan-labs/susankhanal-blog.git",
    [switch]$SkipCommit,
    [switch]$SkipPush,
    [switch]$UseSubtreeDeploy,
    [string]$SubtreeBranch = "cloudflare"
)


# Set error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Change to the script's directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ScriptDir

if (-not $DestinationPath) {
    $DestinationPath = Join-Path $ScriptDir "content\posts"
}

# Check for required commands
$requiredCommands = @('git', 'hugo')

# Check for Python command (python or python3)
if (Get-Command 'python' -ErrorAction SilentlyContinue) {
    $pythonCommand = 'python'
} elseif (Get-Command 'python3' -ErrorAction SilentlyContinue) {
    $pythonCommand = 'python3'
} else {
    Write-Error "Python is not installed or not in PATH."
    exit 1
}

foreach ($cmd in $requiredCommands) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "$cmd is not installed or not in PATH."
        exit 1
    }
}

# Step 1: Check if Git is initialized, and initialize if necessary
if (-not (Test-Path ".git")) {
    Write-Host "Initializing Git repository..."
    git init
    git remote add origin $RepoUrl
} else {
    Write-Host "Git repository already initialized."
    $remotes = git remote
    if (-not ($remotes -contains 'origin')) {
        Write-Host "Adding remote origin..."
        git remote add origin $RepoUrl
    } else {
        $originUrl = git remote get-url origin
        if ($originUrl -ne $RepoUrl) {
            Write-Host "Warning: origin remote does not match expected URL." -ForegroundColor Yellow
            Write-Host "  origin:   $originUrl" -ForegroundColor Yellow
            Write-Host "  expected: $RepoUrl" -ForegroundColor Yellow
        }
    }
}

# Step 2: Sync posts from Obsidian to Hugo content folder using Robocopy
Write-Host "Syncing posts from Obsidian..."

if (-not (Test-Path $SourcePath)) {
    Write-Error "Source path does not exist: $SourcePath"
    exit 1
}

if (-not (Test-Path $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
}

# Use Robocopy to mirror the directories
$robocopyOptions = @('/MIR', '/Z', '/W:5', '/R:3')
$robocopyResult = robocopy $SourcePath $DestinationPath @robocopyOptions

if ($LASTEXITCODE -ge 8) {
    Write-Error "Robocopy failed with exit code $LASTEXITCODE"
    exit 1
}

# Step 3: Process Markdown files with Python script to handle image links
Write-Host "Processing image links in Markdown files..."
if (-not (Test-Path "images.py")) {
    Write-Error "Python script images.py not found."
    exit 1
}

# Execute the Python script
try {
    & $pythonCommand images.py
} catch {
    Write-Error "Failed to process image links."
    exit 1
}

# Step 4: Build the Hugo site
Write-Host "Building the Hugo site..."
try {
    hugo
} catch {
    Write-Error "Hugo build failed."
    exit 1
}

# Step 5: Add changes to Git
Write-Host "Staging changes for Git..."
$hasChanges = (git status --porcelain) -ne ""
if (-not $hasChanges) {
    Write-Host "No changes to stage."
} else {
    git add content static images.py scripts hugo.toml README.md updateblog.ps1
}

# Step 6: Commit changes with a dynamic message
if ($SkipCommit) {
    Write-Host "Skipping commit (SkipCommit set)." -ForegroundColor Yellow
} else {
    $commitMessage = "New Blog Post on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $hasStagedChanges = (git diff --cached --name-only) -ne ""
    if (-not $hasStagedChanges) {
        Write-Host "No changes to commit."
    } else {
        Write-Host "Committing changes..."
        git commit -m "$commitMessage"
    }
}

# Step 7: Push all changes to the main branch
if ($SkipPush) {
    Write-Host "Skipping push to main (SkipPush set)." -ForegroundColor Yellow
} else {
    Write-Host "Deploying to GitHub Main..."
    git push origin main
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to push to Main branch. Continuing to subtree deploy if requested."
    }
}

# Optional Step 8: Push public/ via subtree for alternate deploy workflows
if ($UseSubtreeDeploy) {
    if ($SkipPush) {
        Write-Host "Skipping subtree deploy because SkipPush is set." -ForegroundColor Yellow
        Write-Host "All done! Site synced, processed, built, and staged locally."
        exit 0
    }

    Write-Host "Deploying public folder to branch '$SubtreeBranch'..."

    $currentBranch = (git rev-parse --abbrev-ref HEAD).Trim()
    $tmpSourceBranch = "subtree-source"
    $tmpBranch = "subtree-deploy"

    if (git branch --list $tmpSourceBranch) {
        git branch -D $tmpSourceBranch | Out-Null
    }
    if (git branch --list $tmpBranch) {
        git branch -D $tmpBranch | Out-Null
    }

    # Commit fresh public output on a temporary branch so subtree split includes latest build files.
    git checkout -b $tmpSourceBranch
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create temporary source branch."
        exit 1
    }

    git add -f public
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to stage public folder for subtree deploy."
        git checkout $currentBranch | Out-Null
        git branch -D $tmpSourceBranch | Out-Null
        exit 1
    }

    $hasPublicStagedChanges = (git diff --cached --name-only -- public) -ne ""
    if ($hasPublicStagedChanges) {
        git commit -m "Build public for $SubtreeBranch deploy on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to commit temporary public build changes."
            git checkout $currentBranch | Out-Null
            git branch -D $tmpSourceBranch | Out-Null
            exit 1
        }
    }

    git subtree split --prefix public -b $tmpBranch | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Subtree split failed."
        git checkout $currentBranch | Out-Null
        git branch -D $tmpSourceBranch | Out-Null
        exit 1
    }

    git push origin "$tmpBranch`:$SubtreeBranch" --force
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push subtree branch."
        git checkout $currentBranch | Out-Null
        git branch -D $tmpSourceBranch | Out-Null
        git branch -D $tmpBranch | Out-Null
        exit 1
    }

    git checkout $currentBranch | Out-Null
    git branch -D $tmpSourceBranch | Out-Null
    git branch -D $tmpBranch | Out-Null
}

Write-Host "All done! Site synced, processed, committed, built, and deployed to main."
