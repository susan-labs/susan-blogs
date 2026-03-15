<#
.SYNOPSIS
    Creates a new Hugo blog post as a Page Bundle (folder + index.md + images/).
    Opens the post in VS Code when done.

.EXAMPLE
    .\New-BlogPost.ps1
#>

$BlogRoot = Split-Path $PSScriptRoot -Parent
$PostsDir = Join-Path $BlogRoot "content\posts"

Write-Host ""
Write-Host "=== New Blog Post ===" -ForegroundColor Green
Write-Host ""

# --- Gather input ---
$Title = ""
while (-not $Title.Trim()) {
    $Title = Read-Host "Post title (e.g. 'Setting up Pi-hole on Ubuntu')"
}

$Category = Read-Host "Category (e.g. Networking, Linux, Self-Hosted) [press Enter to skip]"

$TagInput = Read-Host "Tags, comma-separated (e.g. pihole, dns, ubuntu) [press Enter to skip]"
$Tags = if ($TagInput.Trim()) {
    ($TagInput -split ",") | ForEach-Object { "`"$($_.Trim())`"" }
} else { @() }

$Description = Read-Host "Short description (one sentence) [press Enter to skip]"

# --- Build slug ---
$Date       = Get-Date -Format "yyyy-MM-dd"
$SlugRaw    = $Title.ToLower() -replace "[^a-z0-9\s-]", "" -replace "\s+", "-" -replace "-+", "-"
$FolderName = "$Date-$SlugRaw"
$PostDir    = Join-Path $PostsDir $FolderName
$ImagesDir  = Join-Path $PostDir "images"
$IndexFile  = Join-Path $PostDir "index.md"

if (Test-Path $PostDir) {
    Write-Host "`nFolder already exists: $PostDir" -ForegroundColor Yellow
    exit 1
}

# --- Create structure ---
New-Item -ItemType Directory -Path $ImagesDir -Force | Out-Null

# --- Build frontmatter ---
$TagsToml   = if ($Tags.Count -gt 0) { "[$(($Tags) -join ', ')]" } else { "[]" }
$CatToml    = if ($Category.Trim()) { "`"$($Category.Trim())`"" } else { '""' }
$DescToml   = if ($Description.Trim()) { "`"$($Description.Trim())`"" } else { '""' }

$FrontMatter = @"
---
title: "$Title"
date: $Date
draft: false
tags: $TagsToml
categories: [$CatToml]
description: $DescToml
---

## Overview



---

## Step 1 — 



---

*Post in progress*
"@

Set-Content -Path $IndexFile -Value $FrontMatter -Encoding UTF8

Write-Host ""
Write-Host "Post created:" -ForegroundColor Green
Write-Host "  $IndexFile"
Write-Host ""
Write-Host "Next: add your screenshots with Add-Screenshots.ps1" -ForegroundColor Cyan

# Open in VS Code if available
if (Get-Command code -ErrorAction SilentlyContinue) {
    code $IndexFile
} else {
    Write-Host "(VS Code not found in PATH - open the file manually)"
}
