<#
    @Version: 1.0
    @Author: TUGI (contact@tugi.ch)
    @Script: ExportAs-Csv.ps1
    @Description: Saving the hardware hash locally on a device as a CSV file is normally done on devices that already underwent Windows Setup and OOBE.
    @Hint: This is a community script. There is no guarantee for this. Please check thoroughly before running.
    @Version 1.0: Init
    @Run as: Admin
    @Context: 64 Bit
#>

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

New-Item -Type Directory -Path 'C:\HWID'
Set-Location -Path 'C:\HWID'
$env:Path += ';C:\Program Files\WindowsPowerShell\Scripts'
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
Install-PackageProvider -Name NuGet -Force;
Install-Script -Name Get-WindowsAutopilotInfo -Force
Get-WindowsAutopilotInfo -OutputFile AutopilotHWID.csv
