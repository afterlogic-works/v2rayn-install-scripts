# Check for administrator privileges and elevate if needed
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Administrator privileges are required. Requesting elevation..."
    Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Write-Host "Script finished. Press any key to exit..."
    [void][System.Console]::ReadKey($true)
    return
}

$ErrorActionPreference = "Stop"

# --- 1. Download and extract from inner folder ---
$zipUrl = "https://github.com/2dust/v2rayN/releases/download/7.12.7/v2rayN-windows-64-desktop.zip"
$zipPath = "$env:TEMP\v2rayN-windows-64-desktop.zip"
$installDir = "C:\Program Files\v2rayN"
$tempExtract = "$env:TEMP\v2rayN-tmp"

Write-Host "Downloading archive..."
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath

Write-Host "Creating installation directory..."
if (-Not (Test-Path $installDir)) {
    New-Item -Path $installDir -ItemType Directory | Out-Null
}

Write-Host "Extracting archive to temporary folder..."
if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempExtract)

$inner = Join-Path $tempExtract "v2rayN-windows-64"
Move-Item -Path (Join-Path $inner "*") -Destination $installDir -Force

Remove-Item $zipPath
Remove-Item $tempExtract -Recurse -Force

# --- 2. Run v2rayN to generate config ---
$exePath = Join-Path $installDir "v2rayN.exe"
Write-Host "Launching v2rayN.exe to generate configuration files..."
Start-Process -FilePath $exePath
Start-Sleep -Seconds 2
Get-Process v2rayN -ErrorAction SilentlyContinue | Stop-Process -Force

# --- 3. Work only with config in program folder ---
$configPath = Join-Path $installDir "guiConfigs\guiNConfig.json"
Write-Host "Config path: $configPath"

if (-not (Test-Path $configPath)) {
    Write-Host "Config file not found at $configPath! Please run v2rayN at least once and restart this script."
    Write-Host "Script finished. Press any key to exit..."
    [void][System.Console]::ReadKey($true)
    return
}

Write-Host "Creating backup of config..."
$backupPath = "$configPath.bak"
Copy-Item $configPath $backupPath -Force

Write-Host "Updating parameters in config by text replace..."

# Заменить любые варианты: "DoubleClick2Activate": false (с пробелами)
$content = Get-Content $configPath -Raw
$content = $content -replace '"DoubleClick2Activate"\s*:\s*false', '"DoubleClick2Activate": true'
$content = $content -replace '"SysProxyType"\s*:\s*0', '"SysProxyType": 2'
Set-Content $configPath $content -Encoding UTF8

# --- 4. Create a desktop shortcut with admin mode ---
$shortcutPath = [System.IO.Path]::Combine([Environment]::GetFolderPath("Desktop"), "v2rayN.lnk")

Write-Host "Creating desktop shortcut..."
$batPath = "$installDir\run-as-admin.bat"
@"
@echo off
powershell -Command "Start-Process -FilePath '$exePath' -WorkingDirectory '$installDir' -Verb RunAs"
"@ | Set-Content -Path $batPath -Encoding ASCII

$wshell = New-Object -ComObject WScript.Shell
$shortcut = $wshell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $batPath
$shortcut.WorkingDirectory = $installDir
$shortcut.WindowStyle = 1

# Set beautiful icon if present, fallback to exe
$iconPath = Join-Path $installDir "v2rayN.ico"
if (Test-Path $iconPath) {
    $shortcut.IconLocation = $iconPath
} else {
    $shortcut.IconLocation = "$exePath,0"
}
$shortcut.Save()

# Add requireAdministrator (manifest file)
$manifest = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
    <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
        <security>
            <requestedPrivileges>
                <requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>
            </requestedPrivileges>
        </security>
    </trustInfo>
</assembly>
"@
$manifestPath = "$exePath.manifest"
Set-Content -Path $manifestPath -Value $manifest -Encoding UTF8

Write-Host "Done!"
Write-Host "Press any key to exit..."
[void][System.Console]::ReadKey($true)
