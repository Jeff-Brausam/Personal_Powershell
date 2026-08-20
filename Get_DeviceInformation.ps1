<#
.SYNOPSIS
    A brief one-line summary of what your script or function does.

.DESCRIPTION
    A slightly more detailed explanation of how it works, what it outputs, 
    or any prerequisites it needs.

.EXAMPLE
    # How to run your command
    Get-MySystemInfo -Detailed
#>
$cpu = Get-CimInstance Win32_Processor
$cs  = Get-CimInstance Win32_ComputerSystem
$os  = Get-CimInstance Win32_OperatingSystem
$bios = Get-CimInstance Win32_BIOS

Write-Host = $bios

$Architecture = switch ([int]$cpu.Architecture) {
    0  { "x86" }
    9  { "x64 (AMD/Intel 64-bit)" }
    12 { "ARM64" }
    default { "Unknown" }
}

$HostInfo = [PSCustomObject]@{
    "Computer Name"   = $env:COMPUTERNAME
    "Manufacturer"    = $cs.Manufacturer
    "Model"           = $cs.Model
    "Operating System"= $os.Caption
    "Serial Number"   = $bios.SerialNumber;
    "Bios Version"    = $bios.Name
    "Processor (CPU)" = $cpu.Name.Trim()
    "Architecture"    = $Architecture
    "Cores / Threads" = "$($cpu.NumberOfCores) Cores / $($cpu.NumberOfLogicalProcessors) Threads"
    "Total RAM (GB)"  = [math]::round($cs.TotalPhysicalMemory / 1GB, 2)
    "Free RAM (GB)"   = [math]::round($os.FreePhysicalMemory / 1MB, 2)
} 

$HostInfo

$Storage = Get-Volume | 
    Where-Object {$_.DriveLetter -match '[A-Z]'} | 
    Select-Object DriveLetter,
    @{Label="DriveName"; expression={$_.FriendlyName}},
    @{label="Type"; expression={
        $phys = Get-Partition -DriveLetter $_.DriveLetter -ErrorAction SilentlyContinue | 
                Get-Disk -ErrorAction SilentlyContinue | 
                Get-PhysicalDisk -ErrorAction SilentlyContinue
        if ($phys.BusType -eq 'USB') { 'USB' } else { $phys.MediaType }
    }},
    @{Label="Size(GB)"; expression={[math]::round($_.Size / 1GB, 2)}},
    @{Label="FreeSpace(GB)"; expression={[math]::round($_.SizeRemaining / 1GB, 2)}},
    @{Label="PercentFree"; expression={[math]::round(($_.SizeRemaining / $_.Size) * 100, 1)}},
    @{Label="BitlockerStatus"; expression={if(((Get-BitLockerVolume -MountPoint $_.DriveLetter).ProtectionStatus)){"On"} else {"Off"}}},
    HealthStatus,
    OperationalStatus 

Write-Host "--- Storage Info ---"

$Storage