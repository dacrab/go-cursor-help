# Check for admin rights and handle elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-NOT $isAdmin) {
    try {
        Write-Host "`nRequesting administrator privileges..." -ForegroundColor Cyan
        $scriptPath = if ($MyInvocation.MyCommand.Path) {
            $MyInvocation.MyCommand.Path
        } else {
            $tmpScript = Join-Path $env:TEMP "cursor_installer_$([Guid]::NewGuid()).ps1"
            $webclient = New-Object System.Net.WebClient
            $webclient.Headers.Add("User-Agent", "PowerShell")
            $webclient.DownloadFile('https://raw.githubusercontent.com/yuaotian/go-cursor-help/master/scripts/install.ps1', $tmpScript)
            $tmpScript
        }
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs -Wait
        if (Test-Path $tmpScript) {
            Remove-Item -Path $tmpScript -Force
        }
        exit
    }
    catch {
        Write-Host "`nError: Administrator privileges required" -ForegroundColor Red
        Write-Host "Please run this script from an Administrator PowerShell window" -ForegroundColor Yellow
        Write-Host "`nTo do this:" -ForegroundColor Cyan
        Write-Host "1. Press Win + X" -ForegroundColor White
        Write-Host "2. Click 'Windows Terminal (Admin)' or 'PowerShell (Admin)'" -ForegroundColor White
        Write-Host "3. Run the installation command again" -ForegroundColor White
        Write-Host "`nPress Enter to exit..."
        $null = Read-Host
        exit 1
    }
}

# Set security protocol
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Setup temp directory and cleanup
$TmpDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $TmpDir | Out-Null

function Cleanup {
    if (Test-Path $TmpDir) {
        Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
    }
}

# Helper functions
function Get-SystemArch {
    if ([Environment]::Is64BitOperatingSystem) { "x86_64" } else { "i386" }
}

function Get-FileWithProgress {
    param ([string]$Url, [string]$OutputFile)
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "PowerShell Script")
        Write-Host "Downloading from: $Url" -ForegroundColor Cyan
        $webClient.DownloadFile($Url, $OutputFile)
        return $true
    }
    catch {
        Write-Host "Failed to download: $_" -ForegroundColor Red
        return $false
    }
}

function Fix-StoragePermissions {
    $storageJsonPath = "$env:APPDATA\Cursor\User\globalStorage\storage.json"
    $storageDir = Split-Path $storageJsonPath -Parent
    
    if (!(Test-Path $storageDir)) {
        New-Item -ItemType Directory -Path $storageDir -Force | Out-Null
    }
    
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $fileSystemRights = [System.Security.AccessControl.FileSystemRights]::FullControl
    $type = [System.Security.AccessControl.AccessControlType]::Allow
    
    if (Test-Path $storageJsonPath) {
        $acl = Get-Acl $storageJsonPath
        $fileSystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, $fileSystemRights, $type)
        $acl.AddAccessRule($fileSystemAccessRule)
        Set-Acl -Path $storageJsonPath -AclObject $acl -ErrorAction SilentlyContinue
    }
    
    $acl = Get-Acl $storageDir
    $inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $propagationFlags = [System.Security.AccessControl.PropagationFlags]::None
    $dirSystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, $fileSystemRights, $inheritanceFlags, $propagationFlags, $type)
    $acl.AddAccessRule($dirSystemAccessRule)
    Set-Acl -Path $storageDir -AclObject $acl -ErrorAction SilentlyContinue
}

function Install-CursorModifier {
    Write-Host "Starting installation..." -ForegroundColor Cyan
    
    # Initial setup
    Fix-StoragePermissions
    Get-Process | Where-Object { $_.ProcessName -like "*cursor*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    $arch = Get-SystemArch
    Write-Host "Detected architecture: $arch" -ForegroundColor Green
    
    $InstallDir = "$env:ProgramFiles\CursorModifier"
    if (!(Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir | Out-Null
    }
    
    # Get latest release
    try {
        $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/yuaotian/go-cursor-help/releases/latest"
        $version = $latestRelease.tag_name.TrimStart('v')
        Write-Host "Found latest release: v$version" -ForegroundColor Cyan
        
        $possibleNames = @(
            "cursor-id-modifier_${version}_windows_x86_64.exe",
            "cursor-id-modifier_${version}_windows_$($arch).exe"
        )
        
        $asset = $null
        foreach ($name in $possibleNames) {
            $asset = $latestRelease.assets | Where-Object { $_.name -eq $name }
            if ($asset) { break }
        }
        
        if (!$asset) {
            Write-Host "`nAvailable assets:" -ForegroundColor Yellow
            $latestRelease.assets | ForEach-Object { Write-Host "- $($_.name)" }
            throw "Could not find appropriate Windows binary for $arch architecture"
        }
        
        # Download and install
        $binaryPath = Join-Path $TmpDir "cursor-id-modifier.exe"
        if (!(Get-FileWithProgress -Url $asset.browser_download_url -OutputFile $binaryPath)) {
            throw "Download failed"
        }
        
        Copy-Item -Path $binaryPath -Destination "$InstallDir\cursor-id-modifier.exe" -Force
        
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$InstallDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$InstallDir", "Machine")
        }
        
        Write-Host "Installation completed successfully!" -ForegroundColor Green
        Write-Host "Running cursor-id-modifier..." -ForegroundColor Cyan
        
        & "$InstallDir\cursor-id-modifier.exe"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to run cursor-id-modifier"
        }
    }
    catch {
        Write-Host "Error: $_" -ForegroundColor Red
        exit 1
    }
}

# Main execution
try {
    Install-CursorModifier
}
catch {
    Write-Host "Installation failed: $_" -ForegroundColor Red
    Cleanup
    Write-Host "`nPress Enter to exit..."
    $null = Read-Host
    exit 1
}
finally {
    Cleanup
    Write-Host "`nPress Enter to exit..." -ForegroundColor Green
    $null = Read-Host
}