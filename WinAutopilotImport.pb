
;- Compiler
EnableExplicit

;- Variables
Global Event = #Null, Quit = #False
Global Button_ExportAsFile = #Null,
       Hyperlink_ExportFolder = #Null,
       Text_Serial = #Null,
       Hyperlink_SerialNumber = #Null


;- PowerShell Scripts
; None

;- Forms
XIncludeFile "Forms/MainWindow.pbf"

;- Functions
Procedure Clipboard_SerialNumber(EventType)
  Define SerialNumber.s = GetGadgetText(Hyperlink_SerialNumber)
  SetClipboardText(SerialNumber)
EndProcedure

Procedure BIOS_ReadSerialNumber(Parameter)
  ; wmic bios get serialnumber
  
  Define Compiler = #Null
  Define Output$ = ""
  Define Exitcode$ = ""
  Define PSExitcode.i = 1

  Compiler = RunProgram("powershell.exe", 
                        "-NoProfile -NoLogo -WindowStyle Hidden -Command "+Chr(34)+"& {Get-WmiObject win32_bios | foreach { $_.Serialnumber }}"+Chr(34)+" -ExecutionPolicy Bypass", 
                        "", 
                        #PB_Program_Open | #PB_Program_Hide | #PB_Program_Read)
  Output$ = ""
  
  If Compiler
    While ProgramRunning(Compiler)
      If AvailableProgramOutput(Compiler)
        Output$ + ReadProgramString(Compiler) + Chr(13)
      EndIf
    Wend

    PSExitcode = ProgramExitCode(Compiler)
    CloseProgram(Compiler)
  EndIf
  
  If (PSExitcode = 0)
    HideGadget(Text_Serial, #False)
    HideGadget(Hyperlink_SerialNumber, #False)
    SetGadgetText(Hyperlink_SerialNumber, Trim(Output$))
  Else
    MessageRequester("Error", Output$, #PB_MessageRequester_Error | #PB_MessageRequester_Info)
  EndIf
EndProcedure

Procedure Export_HashID_CSV(EventType)
  Define Compiler = #Null
  Define Output$ = ""
  Define Exitcode$ = ""
  Define PSExitcode.i = 1
         
  ;Compiler = RunProgram("powershell.exe", "-NoProfile -NoLogo -File Scripts/ExportAsCsv.ps1 -ExecutionPolicy Bypass", "", #PB_Program_Open | #PB_Program_Read)
  Compiler = RunProgram("powershell.exe", 
                        "-NoProfile -NoLogo -WindowStyle Hidden -File .\Scripts\ExportAs-Csv.ps1 -ExecutionPolicy Bypass", 
                        "", 
                        #PB_Program_Open | #PB_Program_Read)
  Output$ = ""
  
  DisableGadget(Button_ExportAsFile, #True)
  SetGadgetText(Button_ExportAsFile, "Please wait...")
  
  If Compiler
    While ProgramRunning(Compiler)
      If AvailableProgramOutput(Compiler)
        Output$ + ReadProgramString(Compiler) + Chr(13)
      EndIf
    Wend
    Output$ + Chr(13) + Chr(13)
    
    ;Debug ProgramExitCode(Compiler)
    PSExitcode = ProgramExitCode(Compiler)
    Output$ + "Exitcode: " + Str(ProgramExitCode(Compiler))
    
    CloseProgram(Compiler)
  EndIf
  
  ;MessageRequester("Report from PowerShell", Output$, #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
  DisableGadget(Button_ExportAsFile, #False)
  
  If (PSExitcode = 0)
    HideGadget(Hyperlink_ExportFolder, #False)
    HideGadget(Image_Error, #True)
    SetGadgetText(Button_ExportAsFile, "Update Hash ID file")
  Else
    HideGadget(Hyperlink_ExportFolder, #True)
    HideGadget(Image_Error, #False)
    SetGadgetText(Button_ExportAsFile, "Export failed - Retry")
    MessageRequester("Error", Output$, #PB_MessageRequester_Error | #PB_MessageRequester_Info)
  EndIf
  
  ;ShowWindow_(MainWindow, #SW_MAXIMIZE)
EndProcedure

Procedure Open_HashID_ExportFolder(EventType)
  RunProgram("explorer.exe", "C:\HWID", "", #PB_Program_Open)
EndProcedure

Procedure Import_HashID_Intune(EventType)
  Define Compiler = #Null
  Define Output$ = ""
  Define Exitcode$ = ""
  Define PSExitcode.i = 1
         
  ;Compiler = RunProgram("powershell.exe", "-NoProfile -NoLogo -File ImportIntune.ps1 -ExecutionPolicy Bypass", "", #PB_Program_Open | #PB_Program_Read)
  Compiler = RunProgram("powershell.exe", 
                        "-NoProfile -NoLogo -File .\Scripts\Import-Intune.ps1 -ExecutionPolicy Bypass",
                        "")
  Output$ = ""
  ;ShowWindow_(MainWindow, #SW_MAXIMIZE)
  
EndProcedure

;- Initalize Main Window
OpenMainWindow()
SetGadgetText(Text_ComputerName, ComputerName())
SetGadgetText(Text_UserName, UserName())
HideGadget(Image_Error, #True)
HideGadget(Hyperlink_ExportFolder, #True)
HideGadget(Text_Serial, #True)
HideGadget(Hyperlink_SerialNumber, #True)
CreateThread(@BIOS_ReadSerialNumber(), 0)

;- Event Loop
Repeat
  Event = WaitWindowEvent()
  
  Select EventWindow()
    Case MainWindow
      If Event = #PB_Event_CloseWindow
        End
      Else
        MainWindow_Events(Event)
      EndIf
  EndSelect
  
Until Quit = #True

; IDE Options = PureBasic 6.11 LTS (Windows - x64)
; CursorPosition = 24
; Folding = i
; EnableXP
; DPIAware