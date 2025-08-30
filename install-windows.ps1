#!/usr/bin/env pwsh
# MRapids Windows Installer Script
# One-line install: irm https://raw.githubusercontent.com/microrapids/mrapids-releases/main/install-windows.ps1 | iex

param(
    [string]$Version = "latest",
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\mrapids",
    [switch]$AddToPath = $true,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-Host ""
Write-ColorOutput Cyan "  ╭────────────────────────────────────╮"
Write-ColorOutput Cyan "  │   M I C R O   R A P I D S          │"
Write-ColorOutput Cyan "  │   Windows Installer                │"
Write-ColorOutput Cyan "  ╰────────────────────────────────────╯"
Write-Host ""

# Determine version
if ($Version -eq "latest") {
    Write-Host "Fetching latest version..." -ForegroundColor Gray
    try {
        $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/microrapids/mrapids-releases/releases/latest" -Headers @{Accept = "application/vnd.github.v3+json"}
        $Version = $latestRelease.tag_name -replace '^v', ''
        Write-Host "Latest version: v$Version" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to fetch latest version. Please specify a version manually."
        exit 1
    }
}

$downloadUrl = "https://github.com/microrapids/mrapids-releases/releases/download/v$Version/mrapids-windows-x64.zip"

# Create installation directory
Write-Host "Creating installation directory..." -ForegroundColor Gray
if (Test-Path $InstallDir) {
    if ($Force) {
        Write-Host "Removing existing installation..." -ForegroundColor Yellow
        Remove-Item -Path $InstallDir -Recurse -Force
    }
    else {
        Write-Host "Installation directory already exists. Use -Force to overwrite." -ForegroundColor Yellow
        exit 1
    }
}
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

# Download binary
Write-Host "Downloading MRapids v$Version..." -ForegroundColor Gray
$tempZip = Join-Path $env:TEMP "mrapids-$Version.zip"
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing
}
catch {
    Write-Error "Failed to download from: $downloadUrl"
    Write-Host "Please check your internet connection or try a different version." -ForegroundColor Red
    exit 1
}

# Extract binary
Write-Host "Extracting files..." -ForegroundColor Gray
try {
    Expand-Archive -Path $tempZip -DestinationPath $InstallDir -Force
    Remove-Item $tempZip -Force
}
catch {
    Write-Error "Failed to extract archive"
    exit 1
}

# Verify binary exists
$exePath = Join-Path $InstallDir "mrapids.exe"
if (-not (Test-Path $exePath)) {
    Write-Error "Binary not found after extraction. Installation failed."
    exit 1
}

# Add to PATH if requested
if ($AddToPath) {
    Write-Host "Adding to PATH..." -ForegroundColor Gray
    
    $userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    if ($userPath -notlike "*$InstallDir*") {
        $newPath = "$userPath;$InstallDir"
        [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
        $env:Path = "$env:Path;$InstallDir"
        Write-Host "Added to user PATH" -ForegroundColor Green
    }
    else {
        Write-Host "Already in PATH" -ForegroundColor Yellow
    }
}

# Test installation
Write-Host "`nTesting installation..." -ForegroundColor Gray
try {
    $testOutput = & $exePath --version 2>&1
    Write-Host "Version check: $testOutput" -ForegroundColor Green
}
catch {
    Write-Warning "Could not verify installation. You may need to restart your terminal."
}

# Success message
Write-Host ""
Write-ColorOutput Green "╭──────────────────────────────────────────────────╮"
Write-ColorOutput Green "│  ✅ MRapids installed successfully!              │"
Write-ColorOutput Green "│                                                  │"
Write-ColorOutput Green "│  Installation directory: $InstallDir"
Write-ColorOutput Green "│                                                  │"
Write-ColorOutput Green "│  Next steps:                                     │"
Write-ColorOutput Green "│  1. Close and reopen your terminal               │"
Write-ColorOutput Green "│  2. Run: mrapids --help                         │"
Write-ColorOutput Green "│                                                  │"
Write-ColorOutput Green "│  Uninstall:                                      │"
Write-ColorOutput Green "│  Remove-Item -Recurse '$InstallDir'              │"
Write-ColorOutput Green "╰──────────────────────────────────────────────────╯"
Write-Host ""

# Optional: Create Start Menu shortcut
$createShortcut = Read-Host "Create Start Menu shortcut? (Y/N)"
if ($createShortcut -eq 'Y' -or $createShortcut -eq 'y') {
    $startMenuPath = [Environment]::GetFolderPath("StartMenu")
    $shortcutPath = Join-Path $startMenuPath "Programs\MRapids.lnk"
    
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = $exePath
    $Shortcut.Description = "MicroRapids API Runtime"
    $Shortcut.WorkingDirectory = $InstallDir
    $Shortcut.Save()
    
    Write-Host "Start Menu shortcut created" -ForegroundColor Green
}