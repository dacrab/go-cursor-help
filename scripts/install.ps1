# Check for admin rights and handle elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-NOT $isAdmin) {
    try {
        Write-Host "`nRequesting administrator privileges..." -ForegroundColor Cyan
        $pwshPath = "powershell.exe"
        if (Get-Command "pwsh" -ErrorAction SilentlyContinue) {
            $pwshPath = (Get-Command "pwsh").Source
        }
        Start-Process -FilePath $pwshPath -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Wait
        exit
    }
    catch {
        Write-Host "`nError: Administrator privileges required. Please run as administrator." -ForegroundColor Red
        Write-Host "Press enter to exit..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        exit 1
    }
}

# Set TLS to 1.2 and create temp dir
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$TmpDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $TmpDir | Out-Null

# Cleanup function and error handler
function Cleanup { if (Test-Path $TmpDir) { Remove-Item -Recurse -Force $TmpDir } }
trap { 
    Write-Host "Error: $_" -ForegroundColor Red
    Cleanup
    Write-Host "Press enter to exit..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

# Main installation function
function Install-CursorModifier {
    Write-Host "Starting installation..." -ForegroundColor Cyan
    
    # Only support x64 as Cursor only ships x64 builds for Windows
    if (-not [Environment]::Is64BitOperatingSystem) {
        Write-Host "Error: This tool only supports 64-bit Windows (x64)" -ForegroundColor Red
        exit 1
    }
    
    # Setup paths and directories
    $InstallDir = "$env:ProgramFiles\CursorModifier"
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    
    # Get latest release info
    try {
        $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/yuaotian/go-cursor-help/releases/latest"
        $version = $latestRelease.tag_name.TrimStart('v')
        $asset = $latestRelease.assets | Where-Object { 
            $_.name -eq "cursor-id-modifier_${version}_windows_x86_64.exe"
        } | Select-Object -First 1
        
        if (!$asset) {
            throw "No compatible binary found for Windows x64"
        }
        
        # Download and install
        $binaryPath = Join-Path $TmpDir "cursor-id-modifier.exe"
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "PowerShell Script")
        $webClient.DownloadFile($asset.browser_download_url, $binaryPath)
        
        Copy-Item -Path $binaryPath -Destination "$InstallDir\cursor-id-modifier.exe" -Force
        
        # Update PATH
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$InstallDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$InstallDir", "Machine")
        }
        
        # Run the program
        Write-Host "Installation completed successfully!" -ForegroundColor Green
        Write-Host "Running cursor-id-modifier..." -ForegroundColor Cyan
        & "$InstallDir\cursor-id-modifier.exe"
        if ($LASTEXITCODE -ne 0) { throw "Program execution failed" }
    }
    catch {
        Write-Host "Installation failed: $_" -ForegroundColor Red
        exit 1
    }
}

# Run installation and cleanup
try {
    Install-CursorModifier
}
finally {
    Cleanup
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Press enter to exit..." -ForegroundColor Red
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
}