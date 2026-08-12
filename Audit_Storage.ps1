<#
.SYNOPSIS
    Audit which folders are taking up the most storage space.

.DESCRIPTION
    Audit which folders are taking up the most storage space. Default top 100 and all drives.

.EXAMPLE
    Audit_Storage.ps1
    Audit_Storage -MaxFolders 50 -ExcludedDrives F
    Audit_storage -MaxFolders 25
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    # Max amount of to folders to display.
    [Parameter()]
    [int]$MaxFolders = 100,

    # Add any drive letters you want to skip here (e.g., 'D', 'E')
    [Parameter()]
    [string[]]$ExcludedDrives = @(''),
)

$ExcludedRootFolders = @('Windows', '$Recycle.Bin', 'System Volume Information', 'Recovery', 'Boot', '$WinREAgent')
$AllDrives = (Get-CimInstance Win32_LogicalDisk -Filter "DriveType = 3").DeviceID

$CleanExcluded = $ExcludedDrives | ForEach-Object { $_.TrimEnd(':').ToUpper() }
$Drives = $AllDrives | Where-Object { $CleanExcluded -notcontains $_.TrimEnd(':').ToUpper() }

if (-not $Drives) {
    Write-Warning "No drives to scan."
    return
}

$Results = foreach ($drv in $Drives) {
    $DrivePath = "$drv\"
    Write-Verbose "Scanning drive $DrivePath..." -Verbose

    # Get allowed root-level folders
    $RootFolders = Get-ChildItem -Path $DrivePath -Directory -ErrorAction SilentlyContinue | 
        Where-Object { $ExcludedRootFolders -notcontains $_.Name }

        $FoldersToScan = foreach ($rf in $RootFolders) {
        if ($rf.Name -in @('Program Files', 'Program Files (x86)', 'Users')) {
            Get-ChildItem -Path $rf.FullName -Directory -ErrorAction SilentlyContinue
        } else {
            $rf
        }
    }

    # Calculate the size of the folders
    foreach ($folder in $FoldersToScan) {
        Write-Progress "Calculating size for:" $folder.FullName
        $size = (Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        
        if ($size) {
            [PSCustomObject]@{
                FolderName  = $folder.FullName
                "Size (GB)" = [math]::round(($size / 1GB), 2)
            }
        }
    }
}

$Results | Sort-Object "Size (GB)" -Descending | Select-Object -First $MaxFolders