
;- Compiler
EnableExplicit

;- Variables
Global Event = #Null, Quit = #False
Global Button_ExportAsFile = #Null,
       Hyperlink_ExportFolder = #Null,
       Text_Serial = #Null,
       Hyperlink_SerialNumber = #Null

;- Bulk Remote Import variables
Global BulkThread.i        = #Null
Global BulkProgressQueue.s = ""
Global BulkQueueMutex.i    = #Null
Global BulkRunning.i       = #False

Structure BulkThreadParams
  MachineList.s
  Online.i
EndStructure
Global BulkParams.BulkThreadParams


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

;- Bulk Remote Import Procedures

Procedure BulkImport_LoadMachinesFromFile(EventType)
  ; Opens a file dialog and loads machine names from a .txt or .csv into the editor.
  Define FilePath.s
  Define FileNum.i
  Define Line$.s
  Define Content$.s = ""
  Define Count.i = 0

  FilePath = OpenFileRequester("Select machine list", "", "Text files (*.txt)|*.txt|CSV files (*.csv)|*.csv|All files (*.*)|*.*", 0)

  If FilePath = ""
    ProcedureReturn  ; user cancelled
  EndIf

  FileNum = ReadFile(#PB_Any, FilePath)
  If FileNum = 0
    MessageRequester("Error", "Could not open file: " + FilePath, #PB_MessageRequester_Error | #PB_MessageRequester_Info)
    ProcedureReturn
  EndIf

  While Not Eof(FileNum)
    Line$ = ReadString(FileNum)
    ; For CSV files: use first column only
    If FindString(Line$, ",")
      Line$ = StringField(Line$, 1, ",")
    EndIf
    ; Strip double-quotes
    Line$ = Trim(RemoveString(Line$, Chr(34)))
    ; Skip blank lines and common CSV header strings
    If Line$ <> "" And Line$ <> "Device Name" And Line$ <> "ComputerName"
      If Content$ <> ""
        Content$ + #LF$
      EndIf
      Content$ + Line$
      Count + 1
    EndIf
  Wend

  CloseFile(FileNum)
  SetGadgetText(Editor_MachineNames, Content$)
  SetGadgetText(Label_BulkStatus, Str(Count) + " machine(s) loaded from file.")
EndProcedure

Procedure BulkImport_ThreadWorker(ParamPtr)
  ; Background thread: runs BulkRemote-Collect.ps1 and feeds stdout into BulkProgressQueue.
  Protected Params.BulkThreadParams
  Protected Compiler.i = #Null
  Protected Line$.s
  Protected PSExitcode.i = 1
  Protected OnlineFlag.s = ""
  Protected ArgMachines.s

  CopyStructure(ParamPtr, @Params, BulkThreadParams)

  If Params\Online
    OnlineFlag = " -Online"
  EndIf

  ArgMachines = "-MachineList """ + Params\MachineList + """"

  Compiler = RunProgram("powershell.exe",
                        "-NoProfile -NoLogo -WindowStyle Hidden -ExecutionPolicy Bypass" +
                        " -File .\Scripts\BulkRemote-Collect.ps1 " + ArgMachines + OnlineFlag,
                        "",
                        #PB_Program_Open | #PB_Program_Read | #PB_Program_Hide)

  If Compiler
    While ProgramRunning(Compiler)
      If AvailableProgramOutput(Compiler)
        Line$ = ReadProgramString(Compiler)
        LockMutex(BulkQueueMutex)
        If BulkProgressQueue <> ""
          BulkProgressQueue + Chr(10)
        EndIf
        BulkProgressQueue + Line$
        UnlockMutex(BulkQueueMutex)
      EndIf
    Wend
    PSExitcode = ProgramExitCode(Compiler)
    CloseProgram(Compiler)
  EndIf

  ; Append sentinel so the main thread knows the run is complete
  LockMutex(BulkQueueMutex)
  If BulkProgressQueue <> ""
    BulkProgressQueue + Chr(10)
  EndIf
  BulkProgressQueue + "DONE|" + Str(PSExitcode)
  UnlockMutex(BulkQueueMutex)
EndProcedure

Procedure BulkImport_BeginRun(Online.i)
  ; Shared setup called by both button handlers.
  If BulkRunning = #True
    MessageRequester("Busy", "A collection is already running. Please wait.", #PB_MessageRequester_Info)
    ProcedureReturn
  EndIf

  Protected RawText.s = GetGadgetText(Editor_MachineNames)
  If Trim(RawText) = ""
    MessageRequester("No Machines", "Please enter at least one machine name.", #PB_MessageRequester_Info)
    ProcedureReturn
  EndIf

  ; Convert newline-separated list to comma-separated for PowerShell parameter
  Protected MachineCSV.s = ReplaceString(ReplaceString(RawText, #LF$, ","), #CR$, "")
  ; Remove trailing comma
  If Right(MachineCSV, 1) = ","
    MachineCSV = Left(MachineCSV, Len(MachineCSV) - 1)
  EndIf
  ; Collapse double-commas from blank lines
  While FindString(MachineCSV, ",,")
    MachineCSV = ReplaceString(MachineCSV, ",,", ",")
  Wend

  BulkRunning = #True
  LockMutex(BulkQueueMutex)
  BulkProgressQueue = ""
  UnlockMutex(BulkQueueMutex)

  ; Swap editor for ListView
  ClearGadgetItems(ListView_BulkStatus)
  HideGadget(Editor_MachineNames,  #True)
  HideGadget(Button_BrowseMachines, #True)
  HideGadget(Label_MachineNames,   #True)
  HideGadget(ListView_BulkStatus,  #False)

  DisableGadget(Button_BulkCollectSave,  #True)
  DisableGadget(Button_BulkImportIntune, #True)
  SetGadgetText(Label_BulkStatus, "Starting remote collection...")

  BulkParams\MachineList = MachineCSV
  BulkParams\Online      = Online

  BulkThread = CreateThread(@BulkImport_ThreadWorker(), @BulkParams)
EndProcedure

Procedure BulkImport_StartCollection(EventType)
  BulkImport_BeginRun(#False)
EndProcedure

Procedure BulkImport_StartCollectionOnline(EventType)
  BulkImport_BeginRun(#True)
EndProcedure

Procedure BulkImport_FlushProgress()
  ; Called by timer every 250 ms. Drains BulkProgressQueue into the ListView.
  If BulkProgressQueue = ""
    ProcedureReturn
  EndIf

  Protected Snapshot.s
  LockMutex(BulkQueueMutex)
  Snapshot = BulkProgressQueue
  BulkProgressQueue = ""
  UnlockMutex(BulkQueueMutex)

  Protected LineCount.i = CountString(Snapshot, Chr(10)) + 1
  Protected i.i
  Protected Line$.s
  Protected Token1$.s, Token2$.s, Token3$.s, Token4$.s

  For i = 1 To LineCount
    Line$ = StringField(Snapshot, i, Chr(10))
    If Line$ = ""
      Continue
    EndIf

    Token1$ = StringField(Line$, 1, "|")
    Token2$ = StringField(Line$, 2, "|")
    Token3$ = StringField(Line$, 3, "|")
    Token4$ = StringField(Line$, 4, "|")

    Select Token1$
      Case "STATUS"
        Protected MachineName.s = Token2$
        Protected StateStr.s    = Token3$
        Protected Serial.s      = ""
        If StateStr = "OK"
          Serial = Token4$
        EndIf

        ; Find existing ListView row or add a new one
        Protected Found.i = #False
        Protected j.i
        For j = 0 To CountGadgetItems(ListView_BulkStatus) - 1
          If GetGadgetItemText(ListView_BulkStatus, j, 0) = MachineName
            SetGadgetItemText(ListView_BulkStatus, j, StateStr, 1)
            If Serial <> ""
              SetGadgetItemText(ListView_BulkStatus, j, Serial, 2)
            EndIf
            Found = #True
            Break
          EndIf
        Next j

        If Not Found
          AddGadgetItem(ListView_BulkStatus, -1, MachineName + Chr(10) + StateStr + Chr(10) + Serial)
        EndIf

        SetGadgetText(Label_BulkStatus, "Processing: " + MachineName + " — " + StateStr)

      Case "SUMMARY"
        SetGadgetText(Label_BulkStatus, Token2$ + " | " + Token3$ + " | " + Token4$)

      Case "DONE"
        Protected ExitCode.i = Val(Token2$)
        DisableGadget(Button_BulkCollectSave,  #False)
        DisableGadget(Button_BulkImportIntune, #False)

        If ExitCode <> 0
          SetGadgetText(Label_BulkStatus, "Finished with errors (exit " + Str(ExitCode) + ")")
        EndIf

        ; Restore editor so the user can adjust and re-run
        HideGadget(ListView_BulkStatus,   #True)
        HideGadget(Editor_MachineNames,   #False)
        HideGadget(Button_BrowseMachines, #False)
        HideGadget(Label_MachineNames,    #False)

        BulkRunning = #False
    EndSelect
  Next i
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

;- Bulk Remote Import initialization
BulkQueueMutex = CreateMutex()
AddWindowTimer(MainWindow, 1, 250)

;- Event Loop
Repeat
  Event = WaitWindowEvent()

  Select EventWindow()
    Case MainWindow
      Select Event
        Case #PB_Event_CloseWindow
          End
        Case #PB_Event_Timer
          BulkImport_FlushProgress()
        Default
          MainWindow_Events(Event)
      EndSelect
  EndSelect

Until Quit = #True

; IDE Options = PureBasic 6.11 LTS (Windows - x64)
; CursorPosition = 24
; Folding = i
; EnableXP
; DPIAware