# Win Autopilot Import Tool (WinAutopilotImport)

<!-- ABOUT THE PROJECT -->
Have you ever tried to explain the Windows Autopilot device import process to any customer?
With this application, you can provide your customers with an simple GUI to import their devices into Microsoft Intune to register them with Windows Autopilot.<br/><br/>
![App Screenshot](Screenshot.png)



<!-- GETTING STARTED -->
## Getting Started

### Prerequisites
All dependencies/requirements are automatically installed by the PowerShell scripts.<br>
The scripts are based on the official Microsoft article with some modifications to force any module installation with the **-Force** parameter. https://learn.microsoft.com/en-us/autopilot/add-devices
<br><br>
**It will automatically install the following components**
- PowerShell: NuGet (Package Manager)
- PowerShell: Get-WindowsAutopilotInfo (Module)

### Bulk Remote Import — Additional Prerequisites

The **Bulk Remote Import** feature collects hardware hashes from multiple machines simultaneously using PowerShell Remoting (WinRM).

**On each remote target machine** (run once as Administrator):
```powershell
Enable-PSRemoting -Force
```
This enables WinRM and opens the necessary firewall rules. On domain-joined machines, group policy may already handle this.

**Network requirements:**
- TCP 5985 (HTTP) or 5986 (HTTPS) must be reachable from the machine running WinAutopilotImport to each target machine.
- Domain firewall rules typically allow this automatically between domain-joined machines.

**Account requirements:**
- The account running WinAutopilotImport must have local administrator rights on each remote target machine.
- In a domain environment, a Domain Admin or delegated Intune admin account satisfies this.

**Output:** Merged hardware hash CSV is saved to `C:\HWID\BulkAutopilotHWID.csv`.

### Installation
You can download the latest release via GitHub - No installation is required to use this application.



<!-- USAGE EXAMPLES -->
## Usage
All you need to do is run WinAutopilotImport executable.<br>
Please sign in as an Intune administrator to import the device directly (online).
<br/>

## Modifications
You can find all the commands in the .\Scripts folder that will be executed and report the exit code back to the GUI. If PowerShell scripts returns an exit code other than 0, the application automatically displays the PowerShell error message.

## Compile
The project is based on the PureBasic language, available at: https://www.purebasic.com. 
The project file is included for the PureBasic IDE.



<!-- LICENSE -->
## License
Distributed under the GNU License. See `LICENSE` for more information.<br><br>
This tool is provided "as is" with no warranties. Always test scripts and tools in a safe and recoverable environment before using them on a production environment/device.



<!-- CREDITS -->
## Credits
Get-WindowsAutopilotInfo (by Microsoft) - [Get-WindowsAutopilotInfo](https://www.powershellgallery.com/packages/Get-WindowsAutopilotInfo)



<!-- CONTACT -->
## Contact
TUGI - [contact@tugi.ch](mailto:contact@tugi.ch)<br/>
Project Link: [https://blog.tugi.ch/scripts-and-tools/winautopilotimport](https://blog.tugi.ch/scripts-and-tools/winautopilotimport)
