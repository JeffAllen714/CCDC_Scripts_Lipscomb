# Written by Jordan Elliott of Lipscomb University


# Check if the script is running with administrator privileges
$adminCheck = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

# If not running as admin, request elevation
If (-Not ($adminCheck.IsInRole($adminRole))) {
    Write-Host "This script requires administrator privileges. Please enter your admin password when prompted."
    Start-Process powershell -ArgumentList "-File `"$PSCommandPath`"" -Verb runAs
    Exit
}

Write-Host "Running with administrator privileges..."

# Ensure TLS 1.2 is used for secure web requests
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Detect the active user path
Write-Host "Detecting the active user path..."
try {
    $activeUserPath = [Environment]::GetFolderPath("UserProfile")
    Write-Host "Detected active user path: $activeUserPath"
} catch {
    Write-Host "Error detecting active user path: $_"
    Exit
}

# Detect system architecture and processor type
Write-Host "Detecting system architecture..."
$is64Bit = $env:PROCESSOR_ARCHITECTURE -eq "AMD64"
$isARM64 = $env:PROCESSOR_ARCHITEW6432 -eq "ARM64"

If ($is64Bit) {
    $architecture = "AMD64"
    Write-Host "System architecture: AMD64"
} ElseIf ($isARM64) {
    $architecture = "ARM64"
    Write-Host "System architecture: ARM64"
} Else {
    $architecture = "x86"
    Write-Host "System architecture: x86"
}

# Detect Host OS version
Write-Host "Detecting host OS version..."
try {
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $osVersion = $osInfo.Version
    Write-Host "OS Version detected: $osVersion"
    $majorVersion = $osVersion.Split('.')[0]
    $minorVersion = $osVersion.Split('.')[1]

    If ($majorVersion -eq 6 -and $minorVersion -eq 3) {
        Write-Host "Detected Windows 8.1"
        $osType = "Windows 8.1"
    } ElseIf ($majorVersion -ge 10) {
        Write-Host "Detected Windows 10 or later"
        $osType = "Windows 10/11"
    } Else {
        Write-Host "Unsupported OS version. Exiting..."
        Exit
    }
} catch {
    Write-Host "Error detecting host OS version: $_"
    Exit
}

# Define file names based on system architecture and OS
$clamavFile = Switch ($osType) {
    "Windows 8.1" {
        If ($architecture -eq "AMD64") { "clamav-0.103.12-win-x64-portable.zip" }
        Else { "clamav-0.103.12-win-x86-portable.zip" }
    }
    "Windows 10/11" {
        If ($architecture -eq "AMD64") { "clamav-1.4.1.win.x64.zip" }
        ElseIf ($architecture -eq "ARM64") { "clamav-1.4.1.win.arm64.zip" }
        Else { "clamav-1.4.1.win.win32.zip" }
    }
}

$sevenZipFile = If ($architecture -eq "ARM64") { "7z2409-arm64.exe" } ElseIf ($architecture -eq "AMD64") { "7z2409-x64.exe" } Else { "7z2409.exe" }

# Define user directory for local file storage
$userHomePath = $activeUserPath
$clamavFilePath = Join-Path -Path $userHomePath -ChildPath $clamavFile
$sevenZipFilePath = Join-Path -Path $userHomePath -ChildPath $sevenZipFile

# Define paths for CVD files
$cvdFiles = @("bytecode.cvd", "daily.cvd", "main.cvd")
$cvdPaths = $cvdFiles | ForEach-Object { Join-Path -Path $userHomePath -ChildPath $_ }

# Define download URLs
$clamavZipUrl = Switch ($clamavFile) {
    "clamav-0.103.12-win-x64-portable.zip" { "https://www.clamav.net/downloads/production/clamav-0.103.12-win-x64-portable.zip" }
    "clamav-0.103.12-win-x86-portable.zip" { "https://www.clamav.net/downloads/production/clamav-0.103.12-win-x86-portable.zip" }
    "clamav-1.4.1.win.x64.zip" { "https://www.clamav.net/downloads/production/clamav-1.4.1.win.x64.zip" }
    "clamav-1.4.1.win.arm64.zip" { "https://www.clamav.net/downloads/production/clamav-1.4.1.win.arm64.zip" }
    "clamav-1.4.1.win.win32.zip" { "https://www.clamav.net/downloads/production/clamav-1.4.1.win.win32.zip" }
}
$sevenZipInstallerUrl = Switch ($sevenZipFile) {
    "7z2409-arm64.exe" { "https://www.7-zip.org/a/7z2409-arm64.exe" }
    "7z2409-x64.exe" { "https://www.7-zip.org/a/7z2409-x64.exe" }
    "7z2409.exe" { "https://www.7-zip.org/a/7z2409.exe" }
}

# Check for local files, download if missing
Write-Host "Checking for required files locally..."
If (-Not (Test-Path $clamavFilePath)) {
    Write-Host "Local file $clamavFile not found. Downloading..."
    Invoke-WebRequest -Uri $clamavZipUrl -OutFile $clamavFilePath -ErrorAction Stop
    Write-Host "Downloaded $clamavFile successfully."
} Else {
    Write-Host "$clamavFile found locally. Using local copy."
}

If (-Not (Test-Path $sevenZipFilePath)) {
    Write-Host "Local file $sevenZipFile not found. Downloading..."
    Invoke-WebRequest -Uri $sevenZipInstallerUrl -OutFile $sevenZipFilePath -ErrorAction Stop
    Write-Host "Downloaded $sevenZipFile successfully."
} Else {
    Write-Host "$sevenZipFile found locally. Using local copy."
}

# Define installation variables
$installDir = "C:\Program Files\ClamAV"
$logFile = "$installDir\install-log.txt"

# Ensure installation directory exists
If (-Not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force
}

# Install 7-Zip
Write-Host "Installing 7-Zip..."
Start-Process -FilePath $sevenZipFilePath -ArgumentList "/S" -Wait

# Verify 7-Zip installation
$sevenZipPath = "C:\Program Files\7-Zip\7z.exe"
If (-Not (Test-Path $sevenZipPath)) {
    Write-Host "Error: 7-Zip installation failed or 7z.exe not found."
    Exit
}

# Extract ClamAV files
Write-Host "Extracting ClamAV files..."
Start-Process -FilePath $sevenZipPath -ArgumentList "x `"$clamavFilePath`" -o`"$installDir`" -y" -Wait

# Locate the extracted ClamAV folder dynamically
$extractedFolders = Get-ChildItem -Path $installDir -Directory | Where-Object { $_.Name -like "clamav*" }
If ($extractedFolders.Count -eq 0) {
    Write-Host "Error: No extracted ClamAV folder found in $installDir. Exiting..."
    Exit
}
$clamavBaseDir = Join-Path -Path $installDir -ChildPath $extractedFolders[0].Name

Write-Host "ClamAV base directory: $clamavBaseDir"

# Create the database folder if it doesn't already exist
$databaseDir = Join-Path -Path $clamavBaseDir -ChildPath "database"
If (-Not (Test-Path $databaseDir)) {
    Write-Host "Creating database directory: $databaseDir"
    New-Item -ItemType Directory -Path $databaseDir -Force
} Else {
    Write-Host "Database directory already exists: $databaseDir"
}

# Move CVD files to the database folder
Write-Host "Checking for and moving CVD files to the database directory..."
$cvdPaths | ForEach-Object {
    If (Test-Path $_) {
        $destination = Join-Path -Path $databaseDir -ChildPath (Split-Path -Leaf $_)
        Move-Item -Path $_ -Destination $destination -Force
        Write-Host "Moved $($_) to $databaseDir"
    } Else {
        Write-Host "File $($_) not found in $userHomePath. Skipping..."
    }
}

# Locate and move configuration files
$confExampleDir = Join-Path -Path $clamavBaseDir -ChildPath "conf_examples"
If (-Not (Test-Path $confExampleDir)) {
    Write-Host "Error: Configuration examples folder not found. Exiting..."
    Exit
}

$clamdConfSample = Join-Path -Path $confExampleDir -ChildPath "clamd.conf.sample"
$freshclamConfSample = Join-Path -Path $confExampleDir -ChildPath "freshclam.conf.sample"

If (Test-Path $clamdConfSample) {
    $clamdConfDest = Join-Path -Path $clamavBaseDir -ChildPath "clamd.conf"
    Move-Item -Path $clamdConfSample -Destination $clamdConfDest -Force
    Write-Host "Moved clamd.conf.sample to $clamdConfDest"
} Else {
    Write-Host "Error: clamd.conf.sample not found. Exiting..."
    Exit
}

If (Test-Path $freshclamConfSample) {
    $freshclamConfDest = Join-Path -Path $clamavBaseDir -ChildPath "freshclam.conf"
    Move-Item -Path $freshclamConfSample -Destination $freshclamConfDest -Force
    Write-Host "Moved freshclam.conf.sample to $freshclamConfDest"
} Else {
    Write-Host "Error: freshclam.conf.sample not found. Exiting..."
    Exit
}

# Remove "Example" lines from both configuration files
Write-Host "Modifying configuration files to remove example lines..."
try {
    $clamdLines = Get-Content $clamdConfDest | Where-Object { $_ -notmatch "Example" }
    $clamdLines | Set-Content $clamdConfDest
    Write-Host "Removed example lines from clamd.conf"
} catch {
    Write-Host "Error modifying clamd.conf: $_"
}

try {
    $freshclamLines = Get-Content $freshclamConfDest | Where-Object { $_ -notmatch "Example" }
    $freshclamLines | Set-Content $freshclamConfDest
    Write-Host "Removed example lines from freshclam.conf"
} catch {
    Write-Host "Error modifying freshclam.conf: $_"
}

# Cleanup unnecessary files
Write-Host "Cleaning up unnecessary files..."
If (Test-Path $confExampleDir) {
    Remove-Item -Path $confExampleDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removed conf_examples directory"
}

# Uninstall 7-Zip
$sevenZipUninstallPath = "C:\Program Files\7-Zip\Uninstall.exe"
If (Test-Path $sevenZipUninstallPath) {
    Write-Host "Uninstalling 7-Zip..."
    Start-Process -FilePath $sevenZipUninstallPath -ArgumentList "/S" -NoNewWindow -Wait
    Write-Host "7-Zip uninstalled successfully."
} Else {
    Write-Host "7-Zip uninstall executable not found. It might not have been installed correctly or has already been removed."
}

# Run freshclam to update the database
Write-Host "Running freshclam to update virus definitions..."
try {
    Start-Process -FilePath "$clamavBaseDir\freshclam.exe" -NoNewWindow -Wait
    Write-Host "Virus definitions updated successfully."
} catch {
    Write-Host "Error running freshclam: $_"
}

# Final steps
Write-Host "ClamAV setup completed successfully! All required configurations and updates are in place."

# Prevent the window from closing automatically
Write-Host "Press any key to close the window..."
Pause


