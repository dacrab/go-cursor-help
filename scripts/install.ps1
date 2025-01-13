# Check for admin rights and elevate if needed
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-NOT $isAdmin) {
    try {
        Write-Host "Requesting administrator privileges..." -ForegroundColor Cyan
        $pwshPath = (Get-Command "pwsh" -ErrorAction SilentlyContinue).Source
        if (-not $pwshPath) {
            $pwshPath = "powershell.exe"
        }
        
        Start-Process -FilePath $pwshPath -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs -Wait
        exit $LASTEXITCODE
    }
    catch {
        Write-Host "Error: Administrator privileges required." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# Initialize
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$TmpDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
$InstallDir = "$env:ProgramFiles\CursorModifier"

# Create directories
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

# Cleanup function
function Cleanup {
    if (Test-Path $TmpDir) {
        Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
    }
}

# Error handler
trap {
    Write-Host "Error: $_" -ForegroundColor Red
    Cleanup
    Read-Host "Press Enter to exit"
    exit 1
}

# Main installation
try {
    Write-Host "Starting installation..." -ForegroundColor Cyan
    
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw "This tool only supports 64-bit Windows (x64)"
    }
    
    # Get latest release
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/yuaotian/go-cursor-help/releases/latest"
    $version = $latestRelease.tag_name.TrimStart('v')
    $binaryPrefix = "cursor-id-modifier_Windows_x86_64"
    $binaryName = "${binaryPrefix}_${version}"
    $asset = $latestRelease.assets | Where-Object { $_.name -eq $binaryName } | Select-Object -First 1
    
    if (-not $asset) {
        throw "No compatible binary found for Windows x64"
    }
    
    # Download and install
    $binaryPath = Join-Path $TmpDir "cursor-id-modifier.exe"
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "PowerShell Script")
    $webClient.DownloadFile($asset.browser_download_url, $binaryPath)
    
    Copy-Item -Path $binaryPath -Destination "$InstallDir\cursor-id-modifier.exe" -Force
    
    # Update PATH if needed
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$InstallDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$InstallDir", "Machine")
    }
    
    Write-Host "Installation completed successfully!" -ForegroundColor Green
    Write-Host "Running cursor-id-modifier..." -ForegroundColor Cyan
    
    # Run program
    Start-Process -FilePath "$InstallDir\cursor-id-modifier.exe" -Wait -NoNewWindow
    if ($LASTEXITCODE -ne 0) {
        throw "Program execution failed"
    }
}
catch {
    Write-Host "Installation failed: $_" -ForegroundColor Red
    exit 1
}
finally {
    Cleanup
    if ($LASTEXITCODE -ne 0) {
        Read-Host "Press Enter to exit"
    }
}