<#
    @Version: 1.0
    @Author: TUGI (contact@tugi.ch) - extended for bulk remote import
    @Script: BulkRemote-Collect.ps1
    @Description: Collects Windows Autopilot hardware hashes from multiple remote
                  machines via PowerShell Remoting (WinRM / Invoke-Command), merges
                  all results into a single CSV, and optionally uploads to Intune.
    @Hint: This is a community script. There is no guarantee for this.
           Please test thoroughly before running in production.
    @Version 1.0: Init
    @Run as: Admin (WinRM requires admin on remote machines)
    @Context: 64 Bit
    @Parameters:
        -MachineList  Comma-separated list of machine names, e.g. "PC01,PC02,PC03"
        -Online       Switch. When present, uploads the merged CSV to Intune via
                      Get-WindowsAutopilotInfo -Online after collection.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$MachineList,

    [Parameter(Mandatory = $false)]
    [switch]$Online
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---- Bootstrap local dependencies ----------------------------------------
$env:Path += ';C:\Program Files\WindowsPowerShell\Scripts'
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force

# Ensure NuGet and Get-WindowsAutopilotInfo are available locally
# (needed for the -Online merge step at the end)
Install-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue | Out-Null
Install-Script -Name Get-WindowsAutopilotInfo -Force -ErrorAction SilentlyContinue | Out-Null

# ---- Parse machine list ---------------------------------------------------
$machines = @($MachineList -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })

if ($machines.Count -eq 0) {
    Write-Output "ERROR: No machine names provided."
    exit 1
}

# ---- Output directory -----------------------------------------------------
$outputDir = 'C:\HWID'
New-Item -Type Directory -Path $outputDir -Force | Out-Null
$mergedCsv = Join-Path $outputDir 'BulkAutopilotHWID.csv'

# Remove any previous merged file so we start clean
if (Test-Path $mergedCsv) { Remove-Item $mergedCsv -Force }

# ---- Collection scriptblock run on each remote machine -------------------
# Uses inline CIM queries so no module pre-installation is required remotely.
$collectBlock = {
    try {
        $serial = (Get-CimInstance -Namespace root/cimv2 `
                       -ClassName Win32_BIOS -ErrorAction Stop).SerialNumber

        $hash = (Get-CimInstance -Namespace root/cimv2/mdm/dmmap `
                     -ClassName MDM_DevDetail_Ext01 `
                     -Filter "InstanceID='Ext' AND ParentID='./DevDetail'" `
                     -ErrorAction Stop).DeviceHardwareData

        $cs = Get-CimInstance -Namespace root/cimv2 `
                  -ClassName Win32_ComputerSystem -ErrorAction Stop

        [PSCustomObject]@{
            'Device Serial Number' = $serial
            'Windows Product ID'   = ''
            'Hardware Hash'        = $hash
            'Manufacturer'         = $cs.Manufacturer
            'Model'                = $cs.Model
        }
    }
    catch {
        throw $_
    }
}

# ---- Per-machine remote collection ----------------------------------------
$csvHeader    = $false
$successCount = 0
$errorCount   = 0

foreach ($machine in $machines) {

    Write-Output "STATUS|$machine|Connecting..."

    try {
        $result = Invoke-Command -ComputerName $machine `
                                 -ScriptBlock $collectBlock `
                                 -ErrorAction Stop

        if (-not $csvHeader) {
            $result | Export-Csv -Path $mergedCsv -NoTypeInformation -Encoding UTF8
            $csvHeader = $true
        } else {
            $result | Export-Csv -Path $mergedCsv -NoTypeInformation -Encoding UTF8 -Append
        }

        $serial = $result.'Device Serial Number'
        Write-Output "STATUS|$machine|OK|$serial"
        $successCount++
    }
    catch {
        $errMsg = $_.Exception.Message -replace '\r?\n', ' '
        Write-Output "STATUS|$machine|ERROR|$errMsg"
        $errorCount++
        # Continue to next machine — do NOT abort
    }
}

# ---- Summary line ---------------------------------------------------------
Write-Output "SUMMARY|Total=$($machines.Count)|OK=$successCount|Error=$errorCount|CSV=$mergedCsv"

# ---- Optional: push merged CSV to Intune ----------------------------------
if ($Online) {
    if ($successCount -gt 0) {
        Write-Output "STATUS|INTUNE|Uploading to Intune..."
        try {
            & Get-WindowsAutopilotInfo -Online -ErrorAction Stop
            Write-Output "STATUS|INTUNE|OK|Upload complete"
        }
        catch {
            $errMsg = $_.Exception.Message -replace '\r?\n', ' '
            Write-Output "STATUS|INTUNE|ERROR|$errMsg"
            exit 2
        }
    } else {
        Write-Output "STATUS|INTUNE|SKIPPED|No successful collections to upload"
    }
}

exit 0
