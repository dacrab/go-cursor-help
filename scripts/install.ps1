# Check for admin rights and handle elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-NOT $isAdmin) {
    try {
        Write-Host "`nRequesting administrator privileges..." -ForegroundColor Cyan
        
        # Get PowerShell path
        $pwshPath = if (Get-Command "pwsh" -ErrorAction SilentlyContinue) {
            (Get-Command "pwsh").Source
        } else {
            "powershell.exe"
        }
        
        # Get script path
        $scriptPath = if ($MyInvocation.MyCommand.Path) {
            $MyInvocation.MyCommand.Path
        } else {
            $tmpScript = Join-Path $env:TEMP "cursor_installer_$([Guid]::NewGuid()).ps1"
            $webclient = New-Object System.Net.WebClient
            $repoUrl = $env:GITHUB_REPOSITORY ?? "yuaotian/go-cursor-help"
            $webclient.DownloadFile("https://raw.githubusercontent.com/$repoUrl/master/scripts/install.ps1", $tmpScript)
            $tmpScript
        }
        
        Start-Process $pwshPath -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs -Wait
        
        if (Test-Path $tmpScript) {
            Remove-Item -Path $tmpScript -Force
        }
        exit
    }
    catch {
        Write-Host "`nError: Administrator privileges required" -ForegroundColor Red
        Write-Host "Please run as Administrator:" -ForegroundColor Yellow
        Write-Host "1. Press Win + X" -ForegroundColor White 
        Write-Host "2. Click 'Windows Terminal (Admin)' or 'PowerShell (Admin)'" -ForegroundColor White
        Write-Host "3. Run the installation command again" -ForegroundColor White
        Read-Host "`nPress Enter to exit"
        exit 1
    }
}

# Initialize
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$TmpDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $TmpDir | Out-Null

# Helper Functions
function Cleanup {
    if (Test-Path $TmpDir) {
        Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
    }
}

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

function Set-StoragePermissions {
    $storageJsonPath = "$env:APPDATA\Cursor\User\globalStorage\storage.json"
    $storageDir = Split-Path $storageJsonPath -Parent
    
    if (!(Test-Path $storageDir)) {
        New-Item -ItemType Directory -Path $storageDir -Force | Out-Null
    }
    
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $rights = [System.Security.AccessControl.FileSystemRights]::FullControl
    $type = [System.Security.AccessControl.AccessControlType]::Allow
    
    if (Test-Path $storageJsonPath) {
        $acl = Get-Acl $storageJsonPath
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, $rights, $type)
        $acl.AddAccessRule($rule)
        Set-Acl -Path $storageJsonPath -AclObject $acl -ErrorAction SilentlyContinue
    }
    
    $acl = Get-Acl $storageDir
    $inherit = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, $rights, $inherit, [System.Security.AccessControl.PropagationFlags]::None, $type)
    $acl.AddAccessRule($rule)
    Set-Acl -Path $storageDir -AclObject $acl -ErrorAction SilentlyContinue
}

function Install-CursorModifier {
    Write-Host "Starting installation..." -ForegroundColor Cyan
    
    # Setup
    Set-StoragePermissions
    Get-Process | Where-Object { $_.ProcessName -like "*cursor*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    $arch = Get-SystemArch
    $InstallDir = "$env:ProgramFiles\CursorModifier"
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    
    try {
        # Get repository URL
        $repoUrl = $env:GITHUB_REPOSITORY ?? "yuaotian/go-cursor-help"
        
        # Get latest release
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoUrl/releases/latest"
        $version = $release.tag_name.TrimStart('v')
        Write-Host "Latest version: v$version" -ForegroundColor Cyan
        
        # Find correct asset
        $asset = $release.assets | Where-Object { 
            $_.name -in @(
                "cursor-id-modifier_${version}_windows_x86_64.exe",
                "cursor-id-modifier_${version}_windows_$($arch).exe"
            )
        } | Select-Object -First 1
        
        if (!$asset) {
            throw "No compatible binary found for $arch architecture"
        }
        
        # Install
        $binaryPath = Join-Path $TmpDir "cursor-id-modifier.exe"
        if (!(Get-FileWithProgress -Url $asset.browser_download_url -OutputFile $binaryPath)) {
            throw "Download failed"
        }
        
        Copy-Item -Path $binaryPath -Destination "$InstallDir\cursor-id-modifier.exe" -Force
        
        # Update PATH
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$InstallDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$InstallDir", "Machine")
        }
        
        Write-Host "Installation successful!" -ForegroundColor Green
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
    Read-Host "`nPress Enter to exit"
    exit 1
}
finally {
    Cleanup
    if ($LASTEXITCODE -ne 0) {
        Read-Host "`nPress Enter to exit"
    }
}