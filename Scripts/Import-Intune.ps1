<#
    @Version: 1.0
    @Author: TUGI (contact@tugi.ch)
    @Script: Import-Intune.ps1
    @Description: Directly uploading the hardware hash to an MDM service such as Microsoft Intune can be done on any device, but it's especially useful for a device currently undergoing Windows Setup and OOBE.
    @Hint: This is a community script. There is no guarantee for this. Please check thoroughly before running.
    @Version 1.0: Init
    @Run as: Admin
    @Context: 64 Bit
#>

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$env:Path += ';C:\Program Files\WindowsPowerShell\Scripts'
Install-PackageProvider -Name NuGet -Force;
Install-Script -name Get-WindowsAutopilotInfo -Force
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
Get-WindowsAutopilotInfo -Online
