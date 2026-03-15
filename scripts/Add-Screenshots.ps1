<#
.SYNOPSIS
    Copies recent screenshots from your Screenpresso folder into the current post's images/ folder.
    Renames them with a numbered prefix and outputs ready-to-paste Markdown image tags.

.EXAMPLE
    .\Add-Screenshots.ps1
    .\Add-Screenshots.ps1 -PostFolder "2026-03-15-pfsense-proxmox-setup"
    .\Add-Screenshots.ps1 -ScreenpressoPath "D:\Screenshots"

.PARAMETER PostFolder
    Name of the post folder inside content/posts/. Leave blank to pick from a list.

.PARAMETER ScreenpressoPath
    Path to your Screenpresso output folder. Defaults to %USERPROFILE%\Pictures\Screenpresso.

.PARAMETER RecentCount
    How many recent screenshots to list (default: 20).
#>

param(
    [string]$PostFolder      = "",
    [string]$ScreenpressoPath = "",
    [int]   $RecentCount     = 20
)

$BlogRoot = Split-Path $PSScriptRoot -Parent
$PostsDir = Join-Path $BlogRoot "content\posts"

# --- Resolve Screenpresso folder ---
if (-not $ScreenpressoPath) {
    $ScreenpressoPath = Join-Path $env:USERPROFILE "Pictures\Screenpresso"
}
if (-not (Test-Path $ScreenpressoPath)) {
    Write-Host "Screenpresso folder not found: $ScreenpressoPath" -ForegroundColor Red
    $ScreenpressoPath = Read-Host "Enter the full path to your screenshots folder"
    if (-not (Test-Path $ScreenpressoPath)) {
        Write-Host "Path not found. Exiting." -ForegroundColor Red; exit 1
    }
}

# --- Pick post ---
if (-not $PostFolder) {
    $Posts = Get-ChildItem $PostsDir -Directory | Sort-Object Name -Descending
    if ($Posts.Count -eq 0) { Write-Host "No posts found in $PostsDir" -ForegroundColor Red; exit 1 }

    Write-Host ""
    Write-Host "=== Select Post ===" -ForegroundColor Green
    for ($i = 0; $i -lt [Math]::Min($Posts.Count, 15); $i++) {
        Write-Host "  [$($i+1)] $($Posts[$i].Name)"
    }
    Write-Host ""
    $Choice = Read-Host "Enter number (default: 1 - most recent)"
    if (-not $Choice.Trim()) { $Choice = "1" }
    $PostFolder = $Posts[[int]$Choice - 1].Name
}

$ImagesDir = Join-Path $PostsDir "$PostFolder\images"
if (-not (Test-Path $ImagesDir)) {
    New-Item -ItemType Directory -Path $ImagesDir -Force | Out-Null
}

# --- Find next image number ---
$Existing   = Get-ChildItem $ImagesDir -Filter "*.png" | Sort-Object Name
$NextNum    = $Existing.Count + 1

# --- List recent Screenpresso screenshots ---
$Screenshots = Get-ChildItem $ScreenpressoPath -Filter "*.png" |
               Sort-Object LastWriteTime -Descending |
               Select-Object -First $RecentCount

if ($Screenshots.Count -eq 0) {
    Write-Host "No PNG files found in: $ScreenpressoPath" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "=== Recent Screenshots (newest first) ===" -ForegroundColor Green
for ($i = 0; $i -lt $Screenshots.Count; $i++) {
    $ts = $Screenshots[$i].LastWriteTime.ToString("yyyy-MM-dd HH:mm")
    Write-Host "  [$($i+1)] $ts  $($Screenshots[$i].Name)"
}

Write-Host ""
$Selection = Read-Host "Enter numbers to copy, space or comma-separated (e.g. 1 2 3)"
$Indices   = $Selection -split "[\s,]+" | Where-Object { $_ -match "^\d+$" } | ForEach-Object { [int]$_ - 1 }

if ($Indices.Count -eq 0) { Write-Host "Nothing selected. Exiting."; exit 0 }

Write-Host ""
Write-Host "=== Describe Each Screenshot ===" -ForegroundColor Green
Write-Host "(used for the filename and image alt text)"
Write-Host ""

$MarkdownTags = @()

foreach ($Idx in $Indices) {
    if ($Idx -lt 0 -or $Idx -ge $Screenshots.Count) { continue }
    $Src  = $Screenshots[$Idx].FullName
    $Desc = Read-Host "Description for '$($Screenshots[$Idx].Name)' (e.g. 'proxmox-iso-upload')"
    if (-not $Desc.Trim()) { $Desc = "screenshot-$NextNum" }

    $SafeDesc = $Desc.ToLower() -replace "[^a-z0-9\s-]", "" -replace "\s+", "-" -replace "-+", "-"
    $DestName = "{0:D2}-{1}.png" -f $NextNum, $SafeDesc
    $DestPath = Join-Path $ImagesDir $DestName

    Copy-Item -Path $Src -Destination $DestPath -Force
    Write-Host "  Copied -> images/$DestName" -ForegroundColor Cyan

    $AltText = $Desc -replace "-", " "
    $MarkdownTags += "![$AltText](images/$DestName)"
    $NextNum++
}

Write-Host ""
Write-Host "=== Paste these into your index.md ===" -ForegroundColor Green
Write-Host ""
foreach ($Tag in $MarkdownTags) {
    Write-Host $Tag -ForegroundColor Yellow
}
Write-Host ""
