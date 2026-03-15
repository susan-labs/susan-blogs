<#
.SYNOPSIS
    Validates the Hugo build, then commits and pushes to GitHub.
    Cloudflare Pages will automatically pick up the push and redeploy.

.EXAMPLE
    .\Publish-Blog.ps1
    .\Publish-Blog.ps1 -Message "Add pfSense setup guide"
    .\Publish-Blog.ps1 -SkipBuild

.PARAMETER Message
    Git commit message. If not provided, you'll be prompted.

.PARAMETER SkipBuild
    Skip the local hugo build check (not recommended).
#>

param(
    [string]$Message   = "",
    [switch]$SkipBuild
)

$BlogRoot = Split-Path $PSScriptRoot -Parent
Set-Location $BlogRoot

Write-Host ""
Write-Host "=== Publish to GitHub ===" -ForegroundColor Green
Write-Host ""

$ExpectedOrigin = "git@github.com:susan-labs/susankhanal-blog.git"

# --- Check git is available ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "git not found in PATH. Install Git for Windows." -ForegroundColor Red; exit 1
}

# --- Check hugo is available ---
if (-not (Get-Command hugo -ErrorAction SilentlyContinue)) {
    Write-Host "hugo not found in PATH." -ForegroundColor Red; exit 1
}

# --- Warn if git remote does not match expected repo ---
$OriginUrl = git remote get-url origin 2>$null
if ($LASTEXITCODE -eq 0 -and $OriginUrl -ne $ExpectedOrigin) {
    Write-Host "Warning: origin does not match expected repo." -ForegroundColor Yellow
    Write-Host "  origin:   $OriginUrl" -ForegroundColor Yellow
    Write-Host "  expected: $ExpectedOrigin" -ForegroundColor Yellow
}

# --- Validate build ---
if (-not $SkipBuild) {
    Write-Host "Running hugo build check..." -ForegroundColor Cyan
    $BuildOutput = hugo --minify 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Hugo build FAILED. Fix errors before publishing:" -ForegroundColor Red
        $BuildOutput | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
    Write-Host "Build OK." -ForegroundColor Green
} else {
    Write-Host "Skipping build check." -ForegroundColor Yellow
}

# --- Check for changes ---
$Status = git status --porcelain
if (-not $Status) {
    Write-Host ""
    Write-Host "Nothing to commit - working tree is clean." -ForegroundColor Yellow
    exit 0
}

# --- Show what will be committed ---
Write-Host ""
Write-Host "Changed files:" -ForegroundColor Cyan
git status --short
Write-Host ""

# --- Commit message ---
if (-not $Message.Trim()) {
    # Try to auto-detect the newest post title for a smart default
    $NewPosts = git status --porcelain | Where-Object { $_ -match "content/posts" } | Select-Object -First 1
    $DefaultMsg = if ($NewPosts) {
        $FolderMatch = [regex]::Match($NewPosts, 'content/posts/([^/]+)')
        if ($FolderMatch.Success) { "Add post: $($FolderMatch.Groups[1].Value)" } else { "Update blog" }
    } else { "Update blog" }

    $Message = Read-Host "Commit message [default: '$DefaultMsg']"
    if (-not $Message.Trim()) { $Message = $DefaultMsg }
}

# --- Git add / commit / push ---
git add content static scripts images.py hugo.toml README.md updateblog.ps1
if ($LASTEXITCODE -ne 0) { Write-Host "git add failed." -ForegroundColor Red; exit 1 }

git commit -m $Message
if ($LASTEXITCODE -ne 0) { Write-Host "git commit failed." -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "Pulling latest from GitHub..." -ForegroundColor Cyan
git pull origin main --rebase 2>&1 | Out-Null

Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
git push
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "git push failed. Check your remote is set:" -ForegroundColor Red
    Write-Host "  git remote add origin https://github.com/susan-labs/susankhanal-blog.git"
    Write-Host "  git push -u origin main"
    exit 1
}

Write-Host ""
Write-Host "Done! Cloudflare Pages will rebuild in ~30 seconds." -ForegroundColor Green
Write-Host "Watch build progress at: https://dash.cloudflare.com -> Pages" -ForegroundColor Cyan
Write-Host ""
