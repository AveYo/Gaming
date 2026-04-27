@(set "0=%~f0" '& set 1=%*) & powershell -nop -c .([scriptblock]::create((type -raw $env:0))) $env:1 & exit /b ');.{

$title = "DmpChk"
$about = "read crash .dmp .mdmp on double-click - AveYo, 2026.04.27"

### associate .dmp and .mdmp with this script
$file = "$env:APPDATA\AveYo\$title.ps1"; $open = "powershell -nop -nol -ep remotesigned -file ""$file"" ~\? ""%1"""
".dmp",".mdmp" |foreach {
  ni "HKCU:\Software\Classes\$_\shell\open\command" -force >''
  sp "HKCU:\Software\Classes\$_\shell\open\command" "(Default)" $open
}

### directly pasted into powershell? then save on disk
$file = "$env:APPDATA\AveYo\$title.ps1"; $file_lines = if (test-path -lit $file) {(gc -lit $file) -ne ''} else {'file'}
$env0 = if ($env:0 -and (test-path -lit $env:0)) {gc -lit $env:0} else {'env0'} ; $env0_lines = $env0 -ne ''
$text = "@(set ""0=%~f0"" '${0=%~f0}');.{$($MyInvocation.MyCommand.Definition)} `@args`n#_press_Enter_if_pasted_in_powershell"
$text = $text -split '\r?\n'; $text_lines = $text -ne ''; mkdir $(split-path $file) -ea 0 >''
if (diff $text_lines $env0_lines) { if (diff $file_lines $text_lines) { $text | set-content -force $file} }
else { if (diff $file_lines $env0_lines) {$env0 | set-content -force -lit $file} }

### main
$f0 = ($env:0,"$($args[0])")[!$env:0]; $cl = ($env:1,"$($args[1])")[!$env:1]; $ps = {
[Console]::Title = $title; $about; if ($f0) {pushd -lit $(split-path $f0)} else {pushd -lit ~}

### the c# typefinition at the end of the script gets pre-compiled rather than let powershell do it slowly every launch
$library1 = "DmpChk"; $version1 = "2026.3.15.0"; $about1 = "read crash dump files"; $path1 = "$env:APPDATA\AveYo\$library1.dll"
if ((gi $path1 -force -ea 0).VersionInfo.FileVersion -ne $version1) { del $path1 -force -ea 0 } ; if (-not (test-path $path1)) {
  mkdir "$env:APPDATA\AveYo" -ea 0 >'' 2>''; pushd $env:APPDATA\AveYo; " one-time initialization of $library1 library..."
  set-content "$env:APPDATA\AveYo\$library1.cs" $(($MyInvocation.MyCommand.Definition -split '<#[:]LIBRARY1[:].*')[1])
  $clr = $PSVersionTable.PSVersion.Major; if ($clr -gt 4) { $clr = 4 }; $framework = "$env:SystemRoot\Microsoft.NET\Framework"
  $csc = (dir $framework -filter "csc.exe" -Recurse |where {$_.PSPath -like "*v${clr}.*"}).FullName
  start $csc -args "/unsafe /out:$library1.dll /target:library /platform:anycpu /optimize /nologo $library1.cs" -nonew -wait; popd
}
try {Import-Module $path1} catch {del $path1 -force -ea 0; " ERROR importing $library1, run script again! "; timeout -1; return}

### open dump file
if ($cl -and (test-path -lit $cl)) { [AveYo.DmpChk]::Open($cl) }
else { write-host -fore 0 -back 14 " double-click a .dmp or .mdmp file to read "; sleep 5 }

### done, script closes
[Console]::Title = ""
return

<#:LIBRARY1: start <# ------------------------------------------------------------------------------ switch syntax highlight to C#
/// DmpChk by AveYo
using System; using System.Text; using System.IO; using System.Threading;
using System.Runtime.InteropServices; using System.Diagnostics; using System.Reflection;
[assembly:AssemblyVersion("2026.3.15.0")] [assembly: AssemblyTitle("AveYo")]
namespace AveYo
{
  public static class DmpChk {
    public static void Open(string[] args) {
      using (UserDebugger debugger = new UserDebugger()) {
        string dmpFile = args.Length == 0 ? "crash.dmp" : args[0];
        if (!File.Exists(dmpFile)) throw new FileNotFoundException(dmpFile);
        string dmpCmd1 = @".effmach;vertarget;.echo DmpChk by AveYo;|;.lastevent;.cxr;.exr -1;.ecxr;kb;~* kp;.echo;lmv;.dumpdebug";
        string dmpCmd2 = @".foreach(y {s -a 0 L?0FFFFFFFFFFF ""STEAMID=""}){da ${y};.break}";
        string dmpExec = String.Format(@".logopen ""{0}.txt"";{1};{2};.logclose;qd", dmpFile, dmpCmd1, dmpCmd2);
        try {
          if (debugger.OpenFile(dmpFile) == false) { Console.WriteLine("Failed to open"); return; }
          int hr = debugger.WaitForEvent();

          while (true) {
            DEBUG_STATUS status;
            hr = debugger.GetExecutionStatus(out status);
            if (hr != (int)HResult.S_OK) { break; }

            if (status == DEBUG_STATUS.NO_DEBUGGEE) { break; }

            if (status == DEBUG_STATUS.GO || status == DEBUG_STATUS.STEP_BRANCH ||
                  status == DEBUG_STATUS.STEP_INTO || status == DEBUG_STATUS.STEP_OVER) {
                hr = debugger.WaitForEvent();
                continue;
            }

            //if (debugger.StateChanged) { Console.WriteLine(); debugger.StateChanged = false; }
            Console.Write("");
            Console.ForegroundColor = ConsoleColor.Gray;
            debugger.OutputCallbacks();
            //string dmpExec = Console.ReadLine();
            debugger.Execute(DEBUG_OUTCTL.THIS_CLIENT, dmpExec, DEBUG_EXECUTE.DEFAULT);
          }
        }
        finally { try { debugger.Detach(); } catch { } ; Console.ReadKey(); }
      }
    }
  }

  /// based on github.com/microsoft/DbgShell/tree/master/ClrMemDiag/Debugger

  public class UserDebugger: IDebugOutputCallbacks, IDisposable
  {
    //[DefaultDllImportSearchPaths(DllImportSearchPath.System32)] // not on ps 2.0
    [DllImport("dbgeng")]
    internal static extern int DebugCreate(ref Guid InterfaceId, [MarshalAs(UnmanagedType.IUnknown)] out object Interface);

    IDebugClient _client;
    IDebugControl _control;

    //bool _StateChanged; // ps 2.0
    //public bool StateChanged { get { return _StateChanged;} set { this._StateChanged = value; } }

    public delegate void ExceptionOccurredDelegate(ExceptionInfo exInfo);
    public ExceptionOccurredDelegate ExceptionOccurred;

    public UserDebugger() {
      Guid guid = new Guid("27fe5639-8407-4f47-8364-ee118fb08ac8");
      object obj = null;

      //_StateChanged = false; // ps 2.0

      int hr = DebugCreate(ref guid, out obj);

      if (hr < 0) { Console.WriteLine("SourceFix: Unable to acquire client interface"); return; }

      _client = obj as IDebugClient;
      _control = _client as IDebugControl;
      //OutputCallbacks();
    }

    public void OutputCallbacks() {
      _client.SetOutputCallbacks(this);
    }

    public bool OpenFile(string dumpFile) {
      int hr = _client.OpenDumpFile(dumpFile);
      return hr >= 0;
    }

    public int GetExecutionStatus(out DEBUG_STATUS status) {
      return _control.GetExecutionStatus(out status);
    }

    public void OutputCurrentState(DEBUG_OUTCTL outputControl, DEBUG_CURRENT flags) {
      _control.OutputCurrentState(outputControl, flags);
    }

    public int Execute(DEBUG_OUTCTL outputControl, string command, DEBUG_EXECUTE flags) {
      return _control.Execute(DEBUG_OUTCTL.THIS_CLIENT, command, DEBUG_EXECUTE.NOT_LOGGED);
    }

    public int WaitForEvent() {
      return WaitForEvent(DEBUG_WAIT.DEFAULT, Timeout.Infinite); // ps 2.0
    }

    public int WaitForEvent(DEBUG_WAIT flag, int timeout) {
      unchecked { return _control.WaitForEvent(flag, (uint)timeout); }
    }

    public void SetInterrupt() {
      SetInterrupt(DEBUG_INTERRUPT.ACTIVE); // ps 2.0
    }

    public void SetInterrupt(DEBUG_INTERRUPT flag) {
      _control.SetInterrupt(flag);
    }

    public void Detach() {
      _client.DetachProcesses();
    }

    public void Dispose() {
      if (_control != null) { Marshal. ReleaseComObject(_control); _control = null; }
      if (_client  != null) { Marshal. ReleaseComObject(_client);  _client  = null; }
    }

    public int Output([In] DEBUG_OUTPUT Mask, [In, MarshalAs(UnmanagedType.LPWStr)] string Text) {
      int skip = 0;
      switch (Mask) {
        case DEBUG_OUTPUT.DEBUGGEE:
          Console.ForegroundColor = ConsoleColor.Gray; skip = 0;
          break;
        case DEBUG_OUTPUT.PROMPT:
          Console.ForegroundColor = ConsoleColor.Magenta; skip = 0;
          break;
        case DEBUG_OUTPUT.ERROR:
          Console.ForegroundColor = ConsoleColor.Red; skip = 1;
          break;
        case DEBUG_OUTPUT.EXTENSION_WARNING:
        case DEBUG_OUTPUT.WARNING:
          Console.ForegroundColor = ConsoleColor.Yellow; skip = 1;
          break;
        case DEBUG_OUTPUT.SYMBOLS:
          Console.ForegroundColor = ConsoleColor.Cyan; skip = 0;
          break;
        default:
          Console.ForegroundColor = ConsoleColor.White; skip = 0;
          break;
      }
      if (skip == 0) Console.Write(Text);
      return 0;
    }
  }

  [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("5bd9d474-5975-423a-b88b-65a8e7110e65")]
  public interface IDebugBreakpoint {
    [PreserveSig]
    int GetId([Out] out UInt32 Id);

    [PreserveSig]
    int GetType([Out] out DEBUG_BREAKPOINT_TYPE BreakType, [Out] out UInt32 ProcType);

    //FIX ME!!! Should try and get an enum for this
    [PreserveSig]
    int GetAdder([Out, MarshalAs(UnmanagedType.Interface)] out IDebugClient Adder);

    [PreserveSig]
    int GetFlags([Out] out DEBUG_BREAKPOINT_FLAG Flags);

    [PreserveSig]
    int AddFlags([In] DEBUG_BREAKPOINT_FLAG Flags);

    [PreserveSig]
    int RemoveFlags([In] DEBUG_BREAKPOINT_FLAG Flags);

    [PreserveSig]
    int SetFlags([In] DEBUG_BREAKPOINT_FLAG Flags);

    [PreserveSig]
    int GetOffset([Out] out UInt64 Offset);

    [PreserveSig]
    int SetOffset([In] UInt64 Offset);

    [PreserveSig]
    int GetDataParameters([Out] out UInt32 Size, [Out] out DEBUG_BREAKPOINT_ACCESS_TYPE AccessType);

    [PreserveSig]
    int SetDataParameters([In] UInt32 Size, [In] DEBUG_BREAKPOINT_ACCESS_TYPE AccessType);

    [PreserveSig]
    int GetPassCount([Out] out UInt32 Count);

    [PreserveSig]
    int SetPassCount([In] UInt32 Count);

    [PreserveSig]
    int GetCurrentPassCount([Out] out UInt32 Count);

    [PreserveSig]
    int GetMatchThreadId([Out] out UInt32 Id);

    [PreserveSig]
    int SetMatchThreadId([In] UInt32 Thread);

    [PreserveSig]
    int GetCommand([Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Buffer, [In] Int32 BufferSize,
          [Out] out UInt32 CommandSize);

    [PreserveSig]
    int SetCommand([In, MarshalAs(UnmanagedType.LPStr)] string Command);

    [PreserveSig]
    int GetOffsetExpression([Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Buffer, [In] Int32 BufferSize,
          [Out] out UInt32 ExpressionSize);

    [PreserveSig]
    int SetOffsetExpression([In, MarshalAs(UnmanagedType.LPStr)] string Expression);

    [PreserveSig]
    int GetParameters([Out] out DEBUG_BREAKPOINT_PARAMETERS Params);
  }

  [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("27fe5639-8407-4f47-8364-ee118fb08ac8")]
  public interface IDebugClient {
    [PreserveSig]
    int AttachKernel([In] DEBUG_ATTACH Flags, [In, MarshalAs(UnmanagedType.LPStr)] string ConnectOptions);

    [PreserveSig]
    int GetKernelConnectionOptions([Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Buffer, [In] Int32 BufferSize,
          [Out] out UInt32 OptionsSize);

    [PreserveSig]
    int SetKernelConnectionOptions([In, MarshalAs(UnmanagedType.LPStr)] string Options);

    [PreserveSig]
    int StartProcessServer([In] DEBUG_CLASS Flags, [In, MarshalAs(UnmanagedType.LPStr)] string Options, [In] IntPtr Reserved);

    [PreserveSig]
    int ConnectProcessServer([In, MarshalAs(UnmanagedType.LPStr)] string RemoteOptions, [Out] out UInt64 Server);

    [PreserveSig]
    int DisconnectProcessServer([In] UInt64 Server);

    [PreserveSig]
    int GetRunningProcessSystemIds([In] UInt64 Server, [Out, MarshalAs(UnmanagedType.LPArray)] UInt32[] Ids, [In] UInt32 Count,
          [Out] out UInt32 ActualCount);

    [PreserveSig]
    int GetRunningProcessSystemIdByExecutableName([In] UInt64 Server, [In, MarshalAs(UnmanagedType.LPStr)] string ExeName,
          [In] DEBUG_GET_PROC Flags, [Out] out UInt32 Id);

    [PreserveSig]
    int GetRunningProcessDescription([In] UInt64 Server, [In] UInt32 SystemId, [In] DEBUG_PROC_DESC Flags,
          [Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder ExeName, [In] Int32 ExeNameSize, [Out] out UInt32 ActualExeNameSize,
          [Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Description, [In] Int32 DescriptionSize,
          [Out] out UInt32 ActualDescriptionSize);

    [PreserveSig]
    int AttachProcess([In] UInt64 Server, [In] UInt32 ProcessID, [In] DEBUG_ATTACH AttachFlags);

    [PreserveSig]
    int CreateProcess([In] UInt64 Server, [In, MarshalAs(UnmanagedType.LPStr)] string CommandLine,
          [In] DEBUG_CREATE_PROCESS Flags);

    [PreserveSig]
    int CreateProcessAndAttach([In] UInt64 Server, [In, MarshalAs(UnmanagedType.LPStr)] string CommandLine,
          [In] DEBUG_CREATE_PROCESS Flags, [In] UInt32 ProcessId, [In] DEBUG_ATTACH AttachFlags);

    [PreserveSig]
    int GetProcessOptions([Out] out DEBUG_PROCESS Options);

    [PreserveSig]
    int AddProcessOptions([In] DEBUG_PROCESS Options);

    [PreserveSig]
    int RemoveProcessOptions([In] DEBUG_PROCESS Options);

    [PreserveSig]
    int SetProcessOptions([In] DEBUG_PROCESS Options);

    [PreserveSig]
    int OpenDumpFile([In, MarshalAs(UnmanagedType.LPStr)] string DumpFile);

    [PreserveSig]
    int WriteDumpFile([In, MarshalAs(UnmanagedType.LPStr)] string DumpFile, [In] DEBUG_DUMP Qualifier);

    [PreserveSig]
    int ConnectSession([In] DEBUG_CONNECT_SESSION Flags, [In] UInt32 HistoryLimit);

    [PreserveSig]
    int StartServer([In, MarshalAs(UnmanagedType.LPStr)] string Options);

    [PreserveSig]
    int OutputServer([In] DEBUG_OUTCTL OutputControl, [In, MarshalAs(UnmanagedType.LPStr)] string Machine,
          [In] DEBUG_SERVERS Flags);

    [PreserveSig]
    int TerminateProcesses();

    [PreserveSig]
    int DetachProcesses();

    [PreserveSig]
    int EndSession([In] DEBUG_END Flags);

    [PreserveSig]
    int GetExitCode([Out] out UInt32 Code);

    [PreserveSig]
    int DispatchCallbacks([In] UInt32 Timeout);

    [PreserveSig]
    int ExitDispatch([In, MarshalAs(UnmanagedType.Interface)] IDebugClient Client);

    [PreserveSig]
    int CreateClient([Out, MarshalAs(UnmanagedType.Interface)] out IDebugClient Client);

    [PreserveSig]
    int GetInputCallbacks([Out, MarshalAs(UnmanagedType.Interface)] out IDebugInputCallbacks Callbacks);

    [PreserveSig]
    int SetInputCallbacks([In, MarshalAs(UnmanagedType.Interface)] IDebugInputCallbacks Callbacks);

    /* GetOutputCallbacks could a conversion thunk from the debugger engine so we can't specify a specific interface */

    [PreserveSig]
    int GetOutputCallbacks([Out] out IDebugOutputCallbacks Callbacks);

    /* We may have to pass a debugger engine conversion thunk back in so we can't specify a specific interface */

    [PreserveSig]
    int SetOutputCallbacks([In] IDebugOutputCallbacks Callbacks);

    [PreserveSig]
    int GetOutputMask([Out] out DEBUG_OUTPUT Mask);

    [PreserveSig]
    int SetOutputMask([In] DEBUG_OUTPUT Mask);

    [PreserveSig]
    int GetOtherOutputMask([In, MarshalAs(UnmanagedType.Interface)] IDebugClient Client, [Out] out DEBUG_OUTPUT Mask);

    [PreserveSig]
    int SetOtherOutputMask([In, MarshalAs(UnmanagedType.Interface)] IDebugClient Client, [In] DEBUG_OUTPUT Mask);

    [PreserveSig]
    int GetOutputWidth([Out] out UInt32 Columns);

    [PreserveSig]
    int SetOutputWidth([In] UInt32 Columns);

    [PreserveSig]
    int GetOutputLinePrefix([Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Buffer, [In] Int32 BufferSize,
          [Out] out UInt32 PrefixSize);

    [PreserveSig]
    int SetOutputLinePrefix([In, MarshalAs(UnmanagedType.LPStr)] string Prefix);

    [PreserveSig]
    int GetIdentity([Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Buffer, [In] Int32 BufferSize,
          [Out] out UInt32 IdentitySize);

    [PreserveSig]
    int OutputIdentity([In] DEBUG_OUTCTL OutputControl, [In] UInt32 Flags, [In, MarshalAs(UnmanagedType.LPStr)] string Format);

    [PreserveSig]
    int FlushCallbacks();
  }

  [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("9f50e42c-f136-499e-9a97-73036c94ed2d")]
  public interface IDebugInputCallbacks {
    [PreserveSig]
    int StartInput([In] UInt32 BufferSize);

    [PreserveSig]
    int EndInput();
  }

  [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("4bf58045-d654-4c40-b0af-683090f356dc")]
  public interface IDebugOutputCallbacks {
    [PreserveSig]
    int Output([In] DEBUG_OUTPUT Mask, [In, MarshalAs(UnmanagedType.LPStr)] string Text);
  }

  [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("4c7fd663-c394-4e26-8ef1-34ad5ed3764c")]
  public interface IDebugOutputCallbacksWide {
    [PreserveSig]
    int Output([In] DEBUG_OUTPUT Mask, [In, MarshalAs(UnmanagedType.LPWStr)] string Text);
  }

  [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("5182e668-105e-416e-ad92-24ef800424ba")]
  public interface IDebugControl {
    [PreserveSig]
    int GetInterrupt();

    [PreserveSig]
    int SetInterrupt([In] DEBUG_INTERRUPT Flags);

    [PreserveSig]
    int GetInterruptTimeout([Out] out UInt32 Seconds);

    [PreserveSig]
    int SetInterruptTimeout([In] UInt32 Seconds);

    [PreserveSig]
    int GetLogFile([Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Buffer, [In] Int32 BufferSize,
          [Out] out UInt32 FileSize, [Out, MarshalAs(UnmanagedType.Bool)] out bool Append);

    [PreserveSig]
    int OpenLogFile([In, MarshalAs(UnmanagedType.LPStr)] string File, [In, MarshalAs(UnmanagedType.Bool)] bool Append);

    [PreserveSig]
    int CloseLogFile();

    [PreserveSig]
    int GetLogMask([Out] out DEBUG_OUTPUT Mask);

    [PreserveSig]
    int SetLogMask([In] DEBUG_OUTPUT Mask);

    [PreserveSig]
    int Input([Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Buffer, [In] Int32 BufferSize, [Out] out UInt32 InputSize);

    [PreserveSig]
    int ReturnInput([In, MarshalAs(UnmanagedType.LPStr)] string Buffer);

    [PreserveSig]
    int Output([In] DEBUG_OUTPUT Mask, [In, MarshalAs(UnmanagedType.LPStr)] string Format);

    [PreserveSig]
    int OutputVaList( /* THIS SHOULD NEVER BE CALLED FROM C# */ [In] DEBUG_OUTPUT Mask,
          [In, MarshalAs(UnmanagedType.LPStr)] string Format, [In] IntPtr va_list_Args);


    [PreserveSig]
    int ControlledOutput([In] DEBUG_OUTCTL OutputControl, [In] DEBUG_OUTPUT Mask,
          [In, MarshalAs(UnmanagedType.LPStr)] string Format);

    [PreserveSig]
    int ControlledOutputVaList( /* THIS SHOULD NEVER BE CALLED FROM C# */ [In] DEBUG_OUTCTL OutputControl, [In] DEBUG_OUTPUT Mask,
          [In, MarshalAs(UnmanagedType.LPStr)] string Format, [In] IntPtr va_list_Args);

    [PreserveSig]
    int OutputPrompt([In] DEBUG_OUTCTL OutputControl, [In, MarshalAs(UnmanagedType.LPStr)] string Format);

    [PreserveSig]
    int OutputPromptVaList( /* THIS SHOULD NEVER BE CALLED FROM C# */ [In] DEBUG_OUTCTL OutputControl,
          [In, MarshalAs(UnmanagedType.LPStr)] string Format, [In] IntPtr va_list_Args);

    [PreserveSig]
    int GetPromptText([Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Buffer, [In] Int32 BufferSize,
          [Out] out UInt32 TextSize);

    [PreserveSig]
    int OutputCurrentState([In] DEBUG_OUTCTL OutputControl, [In] DEBUG_CURRENT Flags);

    [PreserveSig]
    int OutputVersionInformation([In] DEBUG_OUTCTL OutputControl);

    [PreserveSig]
    int GetNotifyEventHandle([Out] out UInt64 Handle);

    [PreserveSig]
    int SetNotifyEventHandle([In] UInt64 Handle);

    [PreserveSig]
    int Assemble([In] UInt64 Offset, [In, MarshalAs(UnmanagedType.LPStr)] string Instr, [Out] out UInt64 EndOffset);

    [PreserveSig]
    int Disassemble([In] UInt64 Offset, [In] DEBUG_DISASM Flags, [Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Buffer,
          [In] Int32 BufferSize, [Out] out UInt32 DisassemblySize, [Out] out UInt64 EndOffset);

    [PreserveSig]
    int GetDisassembleEffectiveOffset([Out] out UInt64 Offset);

    [PreserveSig]
    int OutputDisassembly([In] DEBUG_OUTCTL OutputControl, [In] UInt64 Offset, [In] DEBUG_DISASM Flags,
          [Out] out UInt64 EndOffset);

    [PreserveSig]
    int OutputDisassemblyLines([In] DEBUG_OUTCTL OutputControl, [In] UInt32 PreviousLines, [In] UInt32 TotalLines,
          [In] UInt64 Offset, [In] DEBUG_DISASM Flags, [Out] out UInt32 OffsetLine, [Out] out UInt64 StartOffset,
          [Out] out UInt64 EndOffset, [Out, MarshalAs(UnmanagedType.LPArray)] UInt64[] LineOffsets);

    [PreserveSig]
    int GetNearInstruction([In] UInt64 Offset, [In] int Delta, [Out] out UInt64 NearOffset);

    [PreserveSig]
    int GetStackTrace([In] UInt64 FrameOffset, [In] UInt64 StackOffset, [In] UInt64 InstructionOffset,
          [Out, MarshalAs(UnmanagedType.LPArray)] DEBUG_STACK_FRAME[] Frames, [In] Int32 FrameSize,
          [Out] out UInt32 FramesFilled);

    [PreserveSig]
    int GetReturnOffset([Out] out UInt64 Offset);

    [PreserveSig]
    int OutputStackTrace([In] DEBUG_OUTCTL OutputControl, [In, MarshalAs(UnmanagedType.LPArray)] DEBUG_STACK_FRAME[] Frames,
          [In] Int32 FramesSize, [In] DEBUG_STACK Flags);

    [PreserveSig]
    int GetDebuggeeType([Out] out DEBUG_CLASS Class, [Out] out DEBUG_CLASS_QUALIFIER Qualifier);

    [PreserveSig]
    int GetActualProcessorType([Out] out IMAGE_FILE_MACHINE Type);

    [PreserveSig]
    int GetExecutingProcessorType([Out] out IMAGE_FILE_MACHINE Type);

    [PreserveSig]
    int GetNumberPossibleExecutingProcessorTypes([Out] out UInt32 Number);

    [PreserveSig]
    int GetPossibleExecutingProcessorTypes([In] UInt32 Start, [In] UInt32 Count,
          [Out, MarshalAs(UnmanagedType.LPArray)] IMAGE_FILE_MACHINE[] Types);

    [PreserveSig]
    int GetNumberProcessors([Out] out UInt32 Number);

    [PreserveSig]
    int GetSystemVersion([Out] out UInt32 PlatformId, [Out] out UInt32 Major, [Out] out UInt32 Minor,
          [Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder ServicePackString, [In] Int32 ServicePackStringSize,
          [Out] out UInt32 ServicePackStringUsed, [Out] out UInt32 ServicePackNumber,
          [Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder BuildString, [In] Int32 BuildStringSize,
          [Out] out UInt32 BuildStringUsed);

    [PreserveSig]
    int GetPageSize([Out] out UInt32 Size);

    [PreserveSig]
    int IsPointer64Bit();

    [PreserveSig]
    int ReadBugCheckData([Out] out UInt32 Code, [Out] out UInt64 Arg1, [Out] out UInt64 Arg2, [Out] out UInt64 Arg3,
          [Out] out UInt64 Arg4);

    [PreserveSig]
    int GetNumberSupportedProcessorTypes([Out] out UInt32 Number);

    [PreserveSig]
    int GetSupportedProcessorTypes([In] UInt32 Start, [In] UInt32 Count,
          [Out, MarshalAs(UnmanagedType.LPArray)] IMAGE_FILE_MACHINE[] Types);

    [PreserveSig]
    int GetProcessorTypeNames([In] IMAGE_FILE_MACHINE Type, [Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder FullNameBuffer,
          [In] Int32 FullNameBufferSize, [Out] out UInt32 FullNameSize,
          [Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder AbbrevNameBuffer, [In] Int32 AbbrevNameBufferSize,
          [Out] out UInt32 AbbrevNameSize);

    [PreserveSig]
    int GetEffectiveProcessorType([Out] out IMAGE_FILE_MACHINE Type);

    [PreserveSig]
    int SetEffectiveProcessorType([In] IMAGE_FILE_MACHINE Type);

    [PreserveSig]
    int GetExecutionStatus([Out] out DEBUG_STATUS Status);

    [PreserveSig]
    int SetExecutionStatus([In] DEBUG_STATUS Status);

    [PreserveSig]
    int GetCodeLevel([Out] out DEBUG_LEVEL Level);

    [PreserveSig]
    int SetCodeLevel([In] DEBUG_LEVEL Level);

    [PreserveSig]
    int GetEngineOptions([Out] out DEBUG_ENGOPT Options);

    [PreserveSig]
    int AddEngineOptions([In] DEBUG_ENGOPT Options);

    [PreserveSig]
    int RemoveEngineOptions([In] DEBUG_ENGOPT Options);

    [PreserveSig]
    int SetEngineOptions([In] DEBUG_ENGOPT Options);

    [PreserveSig]
    int GetSystemErrorControl([Out] out ERROR_LEVEL OutputLevel, [Out] out ERROR_LEVEL BreakLevel);

    [PreserveSig]
    int SetSystemErrorControl([In] ERROR_LEVEL OutputLevel, [In] ERROR_LEVEL BreakLevel);

    [PreserveSig]
    int GetTextMacro([In] UInt32 Slot, [Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Buffer, [In] Int32 BufferSize,
          [Out] out UInt32 MacroSize);

    [PreserveSig]
    int SetTextMacro([In] UInt32 Slot, [In, MarshalAs(UnmanagedType.LPStr)] string Macro);

    [PreserveSig]
    int GetRadix([Out] out UInt32 Radix);

    [PreserveSig]
    int SetRadix([In] UInt32 Radix);

    [PreserveSig]
    int Evaluate([In, MarshalAs(UnmanagedType.LPStr)] string Expression, [In] DEBUG_VALUE_TYPE DesiredType,
          [Out] out DEBUG_VALUE Value, [Out] out UInt32 RemainderIndex);

    [PreserveSig]
    int CoerceValue([In] DEBUG_VALUE In, [In] DEBUG_VALUE_TYPE OutType, [Out] out DEBUG_VALUE Out);

    [PreserveSig]
    int CoerceValues([In] UInt32 Count, [In, MarshalAs(UnmanagedType.LPArray)] DEBUG_VALUE[] In,
          [In, MarshalAs(UnmanagedType.LPArray)] DEBUG_VALUE_TYPE[] OutType,
          [Out, MarshalAs(UnmanagedType.LPArray)] DEBUG_VALUE[] Out);

    [PreserveSig]
    int Execute([In] DEBUG_OUTCTL OutputControl, [In, MarshalAs(UnmanagedType.LPStr)] string Command, [In] DEBUG_EXECUTE Flags);

    [PreserveSig]
    int ExecuteCommandFile([In] DEBUG_OUTCTL OutputControl, [In, MarshalAs(UnmanagedType.LPStr)] string CommandFile,
          [In] DEBUG_EXECUTE Flags);

    [PreserveSig]
    int GetNumberBreakpoints([Out] out UInt32 Number);

    [PreserveSig]
    int GetBreakpointByIndex([In] UInt32 Index, [Out, MarshalAs(UnmanagedType.Interface)] out IDebugBreakpoint bp);

    [PreserveSig]
    int GetBreakpointById([In] UInt32 Id, [Out, MarshalAs(UnmanagedType.Interface)] out IDebugBreakpoint bp);

    [PreserveSig]
    int GetBreakpointParameters([In] UInt32 Count, [In, MarshalAs(UnmanagedType.LPArray)] UInt32[] Ids,
          [In] UInt32 Start, [Out, MarshalAs(UnmanagedType.LPArray)] DEBUG_BREAKPOINT_PARAMETERS[] Params);

    [PreserveSig]
    int AddBreakpoint([In] DEBUG_BREAKPOINT_TYPE Type, [In] UInt32 DesiredId,
          [Out, MarshalAs(UnmanagedType.Interface)] out IDebugBreakpoint Bp);

    [PreserveSig]
    int RemoveBreakpoint([In, MarshalAs(UnmanagedType.Interface)] IDebugBreakpoint Bp);
    [PreserveSig]
    int AddExtension([In, MarshalAs(UnmanagedType.LPStr)] string Path, [In] UInt32 Flags, [Out] out UInt64 Handle);

    [PreserveSig]
    int RemoveExtension([In] UInt64 Handle);

    [PreserveSig]
    int GetExtensionByPath([In, MarshalAs(UnmanagedType.LPStr)] string Path, [Out] out UInt64 Handle);

    [PreserveSig]
    int CallExtension([In] UInt64 Handle, [In, MarshalAs(UnmanagedType.LPStr)] string Function,
          [In, MarshalAs(UnmanagedType.LPStr)] string Arguments);

    [PreserveSig]
    int GetExtensionFunction([In] UInt64 Handle, [In, MarshalAs(UnmanagedType.LPStr)] string FuncName, [Out] out IntPtr Function);

    [PreserveSig]
    int GetWindbgExtensionApis32([In, Out] ref WINDBG_EXTENSION_APIS Api);

    /* Must be In and Out as the nSize member has to be initialized */

    [PreserveSig]
    int GetWindbgExtensionApis64([In, Out] ref WINDBG_EXTENSION_APIS Api);

    /* Must be In and Out as the nSize member has to be initialized */

    [PreserveSig]
    int GetNumberEventFilters([Out] out UInt32 SpecificEvents, [Out] out UInt32 SpecificExceptions,
          [Out] out UInt32 ArbitraryExceptions);

    [PreserveSig]
    int GetEventFilterText([In] UInt32 Index, [Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Buffer, [In] Int32 BufferSize,
          [Out] out UInt32 TextSize);

    [PreserveSig]
    int GetEventFilterCommand([In] UInt32 Index, [Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Buffer, [In] Int32 BufferSize,
          [Out] out UInt32 CommandSize);

    [PreserveSig]
    int SetEventFilterCommand([In] UInt32 Index, [In, MarshalAs(UnmanagedType.LPStr)] string Command);

    [PreserveSig]
    int GetSpecificFilterParameters([In] UInt32 Start, [In] UInt32 Count,
          [Out, MarshalAs(UnmanagedType.LPArray)] DEBUG_SPECIFIC_FILTER_PARAMETERS[] Params);

    [PreserveSig]
    int SetSpecificFilterParameters([In] UInt32 Start, [In] UInt32 Count,
          [In, MarshalAs(UnmanagedType.LPArray)] DEBUG_SPECIFIC_FILTER_PARAMETERS[] Params);

    [PreserveSig]
    int GetSpecificEventFilterArgument([In] UInt32 Index, [Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Buffer,
          [In] Int32 BufferSize, [Out] out UInt32 ArgumentSize);

    [PreserveSig]
    int SetSpecificEventFilterArgument([In] UInt32 Index, [In, MarshalAs(UnmanagedType.LPStr)] string Argument);

    [PreserveSig]
    int GetExceptionFilterParameters([In] UInt32 Count, [In, MarshalAs(UnmanagedType.LPArray)] UInt32[] Codes,
          [In] UInt32 Start, [Out, MarshalAs(UnmanagedType.LPArray)] DEBUG_EXCEPTION_FILTER_PARAMETERS[] Params);

    [PreserveSig]
    int SetExceptionFilterParameters([In] UInt32 Count,
          [In, MarshalAs(UnmanagedType.LPArray)] DEBUG_EXCEPTION_FILTER_PARAMETERS[] Params);

    [PreserveSig]
    int GetExceptionFilterSecondCommand([In] UInt32 Index, [Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Buffer,
          [In] Int32 BufferSize, [Out] out UInt32 CommandSize);

    [PreserveSig]
    int SetExceptionFilterSecondCommand([In] UInt32 Index, [In, MarshalAs(UnmanagedType.LPStr)] string Command);

    [PreserveSig]
    int WaitForEvent([In] DEBUG_WAIT Flags, [In] UInt32 Timeout);

    [PreserveSig]
    int GetLastEventInformation([Out] out DEBUG_EVENT Type, [Out] out UInt32 ProcessId, [Out] out UInt32 ThreadId,
          [In] IntPtr ExtraInformation, [In] UInt32 ExtraInformationSize, [Out] out UInt32 ExtraInformationUsed,
          [Out, MarshalAs(UnmanagedType.LPStr)] StringBuilder Description, [In] Int32 DescriptionSize,
          [Out] out UInt32 DescriptionUsed);
  }

  [Flags]
  public enum DEBUG_CURRENT : uint {
    DEFAULT = 0xf, SYMBOL = 1, DISASM = 2, REGISTERS = 4, SOURCE_LINE = 8,
  }

  [Flags]
  public enum DEBUG_EVENT : uint {
    NONE = 0, BREAKPOINT = 1, EXCEPTION = 2, CREATE_THREAD = 4, EXIT_THREAD = 8, CREATE_PROCESS = 0x10,
    EXIT_PROCESS = 0x20, LOAD_MODULE = 0x40, UNLOAD_MODULE = 0x80, SYSTEM_ERROR = 0x100, SESSION_STATUS = 0x200,
    CHANGE_DEBUGGEE_STATE = 0x400, CHANGE_ENGINE_STATE = 0x800, CHANGE_SYMBOL_STATE = 0x1000,
  }

  [Flags]
  public enum DEBUG_EXECUTE : uint {
    DEFAULT = 0, ECHO = 1, NOT_LOGGED = 2, NO_REPEAT = 4,
  }

  public enum DEBUG_INTERRUPT : uint {
    ACTIVE = 0, PASSIVE = 1, EXIT = 2,
  }

  [Flags]
  public enum DEBUG_OUTCTL : uint {
    THIS_CLIENT = 0, ALL_CLIENTS = 1, ALL_OTHER_CLIENTS = 2, IGNORE = 3, LOG_ONLY = 4, SEND_MASK = 7,
    NOT_LOGGED = 8, OVERRIDE_MASK = 0x10, DML = 0x20, AMBIENT_DML = 0xfffffffe, AMBIENT_TEXT = 0xffffffff,
  }

  [Flags]
  public enum DEBUG_OUTPUT : uint {
    NORMAL = 1, ERROR = 2, WARNING = 4, VERBOSE = 8, PROMPT = 0x10, PROMPT_REGISTERS = 0x20,
    EXTENSION_WARNING = 0x40, DEBUGGEE = 0x80, DEBUGGEE_PROMPT = 0x100, SYMBOLS = 0x200,
  }

  public enum DEBUG_SESSION : uint {
    ACTIVE = 0, END_SESSION_ACTIVE_TERMINATE = 1, END_SESSION_ACTIVE_DETACH = 2,
    END_SESSION_PASSIVE = 3, END = 4, REBOOT = 5, HIBERNATE = 6, FAILURE = 7,
  }

  public enum DEBUG_STATUS : uint {
    NO_CHANGE = 0, GO = 1, GO_HANDLED = 2, GO_NOT_HANDLED = 3, STEP_OVER = 4, STEP_INTO = 5, BREAK = 6, NO_DEBUGGEE = 7,
    STEP_BRANCH = 8, IGNORE_EVENT = 9, RESTART_REQUESTED = 10, REVERSE_GO = 11, REVERSE_STEP_BRANCH = 12,
    REVERSE_STEP_OVER = 13, REVERSE_STEP_INTO = 14, OUT_OF_SYNC = 15, WAIT_INPUT = 16, TIMEOUT = 17, MASK = 0x1f,
  }

  public enum DEBUG_FILTER_EXEC_OPTION : uint {
    BREAK = 0x00000000, SECOND_CHANCE_BREAK = 0x00000001, OUTPUT = 0x00000002, IGNORE = 0x00000003, REMOVE = 0x00000004,
  }

  public enum DEBUG_FILTER_CONTINUE_OPTION : uint {
    GO_HANDLED = 0x00000000, GO_NOT_HANDLED = 0x00000001,
  }

  [Flags]
  public enum DEBUG_WAIT : uint {
    DEFAULT = 0,
  }

  public enum DEBUG_BREAKPOINT_TYPE : uint {
    CODE = 0, DATA = 1, TIME = 2,
  }

  [Flags]
  public enum DEBUG_BREAKPOINT_FLAG : uint {
    GO_ONLY = 1, DEFERRED = 2, ENABLED = 4, ADDER_ONLY = 8, ONE_SHOT = 0x10,
  }

  [Flags]
  public enum DEBUG_BREAKPOINT_ACCESS_TYPE : uint {
    READ = 1, WRITE = 2, EXECUTE = 4, IO = 8,
  }

  [Flags]
  public enum DEBUG_ATTACH : uint {
    KERNEL_CONNECTION = 0, LOCAL_KERNEL = 1, EXDI_DRIVER = 2, DEFAULT = 0, NONINVASIVE = 1, EXISTING = 2,
    NONINVASIVE_NO_SUSPEND = 4, INVASIVE_NO_INITIAL_BREAK = 8, INVASIVE_RESUME_PROCESS = 0x10, NONINVASIVE_ALLOW_PARTIAL = 0x20,
  }

  public enum DEBUG_CLASS : uint {
    UNINITIALIZED = 0, KERNEL = 1, USER_WINDOWS = 2, IMAGE_FILE = 3,
  }

  [Flags]
  public enum DEBUG_GET_PROC : uint {
    DEFAULT = 0, FULL_MATCH = 1, ONLY_MATCH = 2, SERVICE_NAME = 4,
  }

  [Flags]
  public enum DEBUG_PROC_DESC : uint {
    DEFAULT = 0, NO_PATHS = 1, NO_SERVICES = 2, NO_MTS_PACKAGES = 4,
    NO_COMMAND_LINE = 8, NO_SESSION_ID = 0x10, NO_USER_NAME = 0x20,
  }

  [Flags]
  public enum DEBUG_CREATE_PROCESS : uint {
    DEFAULT = 0, DEBUG_PROCESS = 0x00000001, DEBUG_ONLY_THIS_PROCESS = 0x00000002, CREATE_NEW_CONSOLE = 0x00000010,
    NO_DEBUG_HEAP = 0x00000400, THROUGH_RTL = 0x00010000, CREATE_NO_WINDOW = 0x08000000,
  }

  [Flags]
  public enum DEBUG_ECREATE_PROCESS : uint {
    DEFAULT = 0, INHERIT_HANDLES = 1, USE_VERIFIER_FLAGS = 2, USE_IMPLICIT_COMMAND_LINE = 4,
  }

  [Flags]
  public enum DEBUG_PROCESS : uint {
    DEFAULT = 0, DETACH_ON_EXIT = 1, ONLY_THIS_PROCESS = 2,
  }

  public enum DEBUG_DUMP : uint {
    SMALL = 1024, DEFAULT = 1025, FULL = 1026, IMAGE_FILE = 1027, TRACE_LOG = 1028,
    WINDOWS_CD = 1029, KERNEL_DUMP = 1025, KERNEL_SMALL_DUMP = 1024, KERNEL_FULL_DUMP = 1026,
  }

  [Flags]
  public enum DEBUG_CONNECT_SESSION : uint {
    DEFAULT = 0, NO_VERSION = 1, NO_ANNOUNCE = 2,
  }

  public enum DEBUG_SERVERS : uint {
    DEBUGGER = 1, PROCESS = 2, ALL = 3,
  }

  public enum DEBUG_END : uint  {
    PASSIVE = 0, ACTIVE_TERMINATE = 1, ACTIVE_DETACH = 2, END_REENTRANT = 3, END_DISCONNECT = 4,
  }

  [Flags]
  public enum DEBUG_ASMOPT : uint {
    DEFAULT = 0x00000000, VERBOSE = 0x00000001, NO_CODE_BYTES = 0x00000002,
    IGNORE_OUTPUT_WIDTH = 0x00000004, SOURCE_LINE_NUMBER = 0x00000008,
  }

  public enum DEBUG_CLASS_QUALIFIER : uint {
    KERNEL_CONNECTION = 0, KERNEL_LOCAL = 1, KERNEL_EXDI_DRIVER = 2, KERNEL_IDNA = 3, KERNEL_SMALL_DUMP = 1024,
    KERNEL_DUMP = 1025, KERNEL_FULL_DUMP = 1026, USER_WINDOWS_PROCESS = 0, USER_WINDOWS_PROCESS_SERVER = 1,
    USER_WINDOWS_IDNA = 2, USER_WINDOWS_SMALL_DUMP = 1024, USER_WINDOWS_DUMP = 1026,
  }

  [Flags]
  public enum DEBUG_DISASM : uint {
    EFFECTIVE_ADDRESS = 1, MATCHING_SYMBOLS = 2, SOURCE_LINE_NUMBER = 4, SOURCE_FILE_NAME = 8,
  }

  public enum DEBUG_DUMP_FILE : uint {
    BASE = 0xffffffff, PAGE_FILE_DUMP = 0,
  }

  public enum DEBUG_EINDEX : uint {
    NAME = 0, FROM_START = 0, FROM_END = 1, FROM_CURRENT = 2,
  }

  [Flags]
  public enum DEBUG_ENGOPT : uint {
    NONE = 0, IGNORE_DBGHELP_VERSION = 0x00000001, IGNORE_EXTENSION_VERSIONS = 0x00000002, ALLOW_NETWORK_PATHS = 0x00000004,
    DISALLOW_NETWORK_PATHS = 0x00000008, NETWORK_PATHS = (0x00000004 | 0x00000008), IGNORE_LOADER_EXCEPTIONS = 0x00000010,
    INITIAL_BREAK = 0x00000020, INITIAL_MODULE_BREAK = 0x00000040, FINAL_BREAK = 0x00000080, NO_EXECUTE_REPEAT = 0x00000100,
    FAIL_INCOMPLETE_INFORMATION = 0x00000200, ALLOW_READ_ONLY_BREAKPOINTS = 0x00000400, SYNCHRONIZE_BREAKPOINTS = 0x00000800,
    DISALLOW_SHELL_COMMANDS = 0x00001000, KD_QUIET_MODE = 0x00002000, DISABLE_MANAGED_SUPPORT = 0x00004000,
    DISABLE_MODULE_SYMBOL_LOAD = 0x00008000, DISABLE_EXECUTION_COMMANDS = 0x00010000, DISALLOW_IMAGE_FILE_MAPPING = 0x00020000,
    PREFER_DML = 0x00040000, ALL = 0x0007FFFF,
  }

  public enum DEBUG_EXPR : uint {
    MASM = 0, CPLUSPLUS = 1,
  }

  [Flags]
  public enum DEBUG_FORMAT : uint
  {
    DEFAULT = 0x00000000, CAB_SECONDARY_ALL_IMAGES = 0x10000000, WRITE_CAB = 0x20000000, CAB_SECONDARY_FILES = 0x40000000,
    NO_OVERWRITE = 0x80000000, USER_SMALL_FULL_MEMORY = 0x00000001, USER_SMALL_HANDLE_DATA = 0x00000002,
    USER_SMALL_UNLOADED_MODULES = 0x00000004, USER_SMALL_INDIRECT_MEMORY = 0x00000008, USER_SMALL_DATA_SEGMENTS = 0x00000010,
    USER_SMALL_FILTER_MEMORY = 0x00000020, USER_SMALL_FILTER_PATHS = 0x00000040, USER_SMALL_PROCESS_THREAD_DATA = 0x00000080,
    USER_SMALL_PRIVATE_READ_WRITE_MEMORY = 0x00000100, USER_SMALL_NO_OPTIONAL_DATA = 0x00000200,
    USER_SMALL_FULL_MEMORY_INFO = 0x00000400, USER_SMALL_THREAD_INFO = 0x00000800, USER_SMALL_CODE_SEGMENTS = 0x00001000,
    USER_SMALL_NO_AUXILIARY_STATE = 0x00002000, USER_SMALL_FULL_AUXILIARY_STATE = 0x00004000,
    USER_SMALL_IGNORE_INACCESSIBLE_MEM = 0x08000000,
  }

  public enum DEBUG_LEVEL : uint {
    SOURCE = 0, ASSEMBLY = 1,
  }

  [Flags]
  public enum DEBUG_LOG : uint {
    DEFAULT = 0, APPEND = 1, UNICODE = 2, DML = 4,
  }

  [Flags]
  public enum DEBUG_MANAGED : uint {
    DISABLED = 0, ALLOWED = 1, DLL_LOADED = 2,
  }

  [Flags]
  public enum DEBUG_MANRESET : uint {
    DEFAULT = 0, LOAD_DLL = 1,
  }

  [Flags]
  public enum DEBUG_MANSTR : uint {
    NONE = 0, LOADED_SUPPORT_DLL = 1, LOAD_STATUS = 2,
  }

  [Flags]
  public enum DEBUG_OUT_TEXT_REPL : uint {
    DEFAULT = 0,
  }

  public enum DEBUG_OUTCB : uint {
    TEXT = 0, DML = 1, EXPLICIT_FLUSH = 2,
  }

  [Flags]
  public enum DEBUG_OUTCBF : uint {
    EXPLICIT_FLUSH = 1, DML_HAS_TAGS = 2, DML_HAS_SPECIAL_CHARACTERS = 4,
  }

  [Flags]
  public enum DEBUG_OUTCBI : uint {
    EXPLICIT_FLUSH = 1, TEXT = 2, DML = 4, ANY_FORMAT = 6,
  }

  [Flags]
  public enum DEBUG_STACK : uint {
      ARGUMENTS = 0x1, FUNCTION_INFO = 0x2, SOURCE_LINE = 0x4, FRAME_ADDRESSES = 0x8, COLUMN_NAMES = 0x10,
      NONVOLATILE_REGISTERS = 0x20, FRAME_NUMBERS = 0x40, PARAMETERS = 0x80, FRAME_ADDRESSES_RA_ONLY = 0x100,
      FRAME_MEMORY_USAGE = 0x200, PARAMETERS_NEWLINE = 0x400, DML = 0x800, FRAME_OFFSETS = 0x1000,
  }
  public enum DEBUG_SYSVERSTR : uint {
      SERVICE_PACK = 0, BUILD = 1,
  }
  public enum DEBUG_VALUE_TYPE : uint {
      INVALID = 0, INT8 = 1, INT16 = 2, INT32 = 3, INT64 = 4, FLOAT32 = 5, FLOAT64 = 6, FLOAT80 = 7, FLOAT82 = 8, FLOAT128 = 9,
      VECTOR64 = 10, VECTOR128 = 11, TYPES = 12,
  }
  public enum ERROR_LEVEL {
      ERROR = 1, MINORERROR = 2, WARNING = 3,
  }

  public enum IMAGE_FILE_MACHINE : uint {
    UNKNOWN = 0, I386 = 0x014c, R3000 = 0x0162, R4000 = 0x0166, R10000 = 0x0168, WCEMIPSV2 = 0x0169, ALPHA = 0x0184, SH3 = 0x01a2,
    SH3DSP = 0x01a3, SH3E = 0x01a4, SH4 = 0x01a6, SH5 = 0x01a8, ARM = 0x01c0, THUMB = 0x01c2, THUMB2 = 0x1c4, AM33 = 0x01d3,
    POWERPC = 0x01F0, POWERPCFP = 0x01f1, IA64 = 0x0200, MIPS16 = 0x0266, ALPHA64 = 0x0284, MIPSFPU = 0x0366, MIPSFPU16 = 0x0466,
    AXP64 = 0x0284, TRICORE = 0x0520, CEF = 0x0CEF, EBC = 0x0EBC, AMD64 = 0x8664, M32R = 0x9041, CEE = 0xC0EE,
  }

  public enum HResult : uint {
    S_OK = 0, S_FALSE = 1U, E_PENDING = 0x8000000A, E_UNEXPECTED = 0x8000FFFF, E_FAIL = 0x80004005,
  }

  [StructLayout(LayoutKind.Explicit)]
  public struct I64PARTS32 {
    [FieldOffset(0)]
    public UInt32 LowPart;
    [FieldOffset(4)]
    public UInt32 HighPart;
  }

  [StructLayout(LayoutKind.Explicit)]
  public struct F128PARTS64 {
    [FieldOffset(0)]
    public UInt64 LowPart;
    [FieldOffset(8)]
    public UInt64 HighPart;
  }

  [StructLayout(LayoutKind.Sequential)]
  public struct DEBUG_CREATE_PROCESS_OPTIONS {
    public DEBUG_CREATE_PROCESS CreateFlags;
    public DEBUG_ECREATE_PROCESS EngCreateFlags;
    public uint VerifierFlags;
    public uint Reserved;
  }

  [StructLayout(LayoutKind.Sequential)]
  public struct DEBUG_EXCEPTION_FILTER_PARAMETERS {
    public DEBUG_FILTER_EXEC_OPTION ExecutionOption;
    public DEBUG_FILTER_CONTINUE_OPTION ContinueOption;
    public UInt32 TextSize;
    public UInt32 CommandSize;
    public UInt32 SecondCommandSize;
    public UInt32 ExceptionCode;
  }

  [StructLayout(LayoutKind.Sequential)]
  public struct DEBUG_SPECIFIC_FILTER_PARAMETERS {
    public DEBUG_FILTER_EXEC_OPTION ExecutionOption;
    public DEBUG_FILTER_CONTINUE_OPTION ContinueOption;
    public UInt32 TextSize;
    public UInt32 CommandSize;
    public UInt32 ArgumentSize;
  }

  [StructLayout(LayoutKind.Sequential)]
  public unsafe struct DEBUG_STACK_FRAME {
    public UInt64 InstructionOffset;
    public UInt64 ReturnOffset;
    public UInt64 FrameOffset;
    public UInt64 StackOffset;
    public UInt64 FuncTableEntry;
    public fixed UInt64 Params[4];
    public fixed UInt64 Reserved[6];
    public UInt32 Virtual;
    public UInt32 FrameNumber;
  }

  [StructLayout(LayoutKind.Explicit)]
  public unsafe struct DEBUG_VALUE {
    [FieldOffset(0)]
    public byte I8;
    [FieldOffset(0)]
    public ushort I16;
    [FieldOffset(0)]
    public uint I32;
    [FieldOffset(0)]
    public ulong I64;
    [FieldOffset(8)]
    public uint Nat;
    [FieldOffset(0)]
    public float F32;
    [FieldOffset(0)]
    public double F64;
    [FieldOffset(0)]
    public fixed byte F80Bytes[10];
    [FieldOffset(0)]
    public fixed byte F82Bytes[11];
    [FieldOffset(0)]
    public fixed byte F128Bytes[16];
    [FieldOffset(0)]
    public fixed byte VI8[16];
    [FieldOffset(0)]
    public fixed ushort VI16[8];
    [FieldOffset(0)]
    public fixed uint VI32[4];
    [FieldOffset(0)]
    public fixed ulong VI64[2];
    [FieldOffset(0)]
    public fixed float VF32[4];
    [FieldOffset(0)]
    public fixed double VF64[2];
    [FieldOffset(0)]
    public I64PARTS32 I64Parts32;
    [FieldOffset(0)]
    public F128PARTS64 F128Parts64;
    [FieldOffset(0)]
    public fixed byte RawBytes[24];
    [FieldOffset(24)]
    public UInt32 TailOfRawBytes;
    [FieldOffset(28)]
    public DEBUG_VALUE_TYPE Type;
  }

  [StructLayout(LayoutKind.Sequential)]
  public struct WINDBG_EXTENSION_APIS/*32 or 64; both are defined the same in managed code*/ {
    public UInt32 nSize;
    public IntPtr lpOutputRoutine;
    public IntPtr lpGetExpressionRoutine;
    public IntPtr lpGetSymbolRoutine;
    public IntPtr lpDisasmRoutine;
    public IntPtr lpCheckControlCRoutine;
    public IntPtr lpReadProcessMemoryRoutine;
    public IntPtr lpWriteProcessMemoryRoutine;
    public IntPtr lpGetThreadContextRoutine;
    public IntPtr lpSetThreadContextRoutine;
    public IntPtr lpIoctlRoutine;
    public IntPtr lpStackTraceRoutine;
  }

  [StructLayout(LayoutKind.Sequential)]
  public struct DEBUG_BREAKPOINT_PARAMETERS {
    public UInt64 Offset;
    public UInt32 Id;
    public DEBUG_BREAKPOINT_TYPE BreakType;
    public UInt32 ProcType;
    public DEBUG_BREAKPOINT_FLAG Flags;
    public UInt32 DataSize;
    public DEBUG_BREAKPOINT_ACCESS_TYPE DataAccessType;
    public UInt32 PassCount;
    public UInt32 CurrentPassCount;
    public UInt32 MatchThread;
    public UInt32 CommandSize;
    public UInt32 OffsetExpressionSize;
  }

  [StructLayout(LayoutKind.Sequential)]
  public unsafe struct EXCEPTION_RECORD64 {
    public UInt32 ExceptionCode;
    public UInt32 ExceptionFlags;
    public UInt64 ExceptionRecord;
    public UInt64 ExceptionAddress;
    public UInt32 NumberParameters;
    public UInt32 __unusedAlignment;
    public fixed UInt64 ExceptionInformation[15]; //EXCEPTION_MAXIMUM_PARAMETERS
  }

  public struct ExceptionInfo {
    public EXCEPTION_RECORD64 Record;
    public bool FirstChance;

    public ExceptionInfo(EXCEPTION_RECORD64 record, uint firstChance) {
      Record = record;
      FirstChance = firstChance != 0;
    }
  }
}
<#:LIBRARY1: end -------------------------------------------------------------------------------------------------------------- #>
};. $ps -title $title -about $about -f0 $f0 -cl $cl } @args
#_press_Enter_if_pasted_in_powershell
