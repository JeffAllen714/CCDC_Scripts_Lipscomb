# Written by Jordan Elliott of Lipscomb University

# Ensure the script is run as an administrator
$adminCheck = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

if (-Not ($adminCheck.IsInRole($adminRole))) {
    Write-Host "This script requires administrator privileges. Please re-run as administrator."
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

Write-Host "Running with administrator privileges..."

# Define potential directories where clamscan.exe might exist
$baseDir = "C:\Program Files\ClamAV"
$possibleDirs = @(
    "clamav-0.103.12-win-x64-portable",
    "clamav-0.103.12-win-x86-portable",
    "clamav-1.4.1.win.arm64",
    "clamav-1.4.1.win.win32",
    "clamav-1.4.1.win.x64"
)

# Check for clamscan.exe in the possible directories
$clamScanPath = $null
foreach ($dir in $possibleDirs) {
    $fullPath = Join-Path -Path $baseDir -ChildPath $dir
    $exePath = Join-Path -Path $fullPath -ChildPath "clamscan.exe"

    if (Test-Path $exePath) {
        $clamScanPath = $exePath
        Write-Host "Found clamscan.exe in $fullPath."
        break
    }
}

if (-Not $clamScanPath) {
    Write-Host "Error: clamscan.exe not found in any expected directories under $baseDir."
    Exit
}

# Define target directories for scanning (smaller to larger)
$targetDirectories = @(
    "C:\Windows\Temp",
    "C:\Users\$env:USERNAME\AppData\Local\Temp",
    "C:\Users\$env:USERNAME\Downloads",
    "C:\Users\$env:USERNAME\Documents",
    "C:\Users\Public\Downloads",
    "C:\Users\Public\Documents",
    "C:\inetpub\ftproot",
    "C:\inetpub\wwwroot",
    "C:\ProgramData",
    "C:\Program Files (x86)",
    "C:\Program Files",
    "C:\Windows\SysWOW64",
    "C:\Windows\System32"
)

# Scan each directory
foreach ($targetDir in $targetDirectories) {
    if (Test-Path $targetDir) {
        Write-Host "Starting ClamAV scan on $targetDir..."
        Start-Process -FilePath $clamScanPath -ArgumentList "--remove --log=clamd $targetDir" -NoNewWindow -Wait
        Write-Host "Scan complete for $targetDir. Log file 'clamd' saved in the ClamAV directory."
    } else {
        Write-Host "Directory not found: $targetDir. Skipping."
    }
}

Write-Host "All scans completed."
