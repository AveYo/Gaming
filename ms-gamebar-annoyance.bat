@(set "0=%~f0" ') & powershell -nop .([scriptblock]::create((type $env:0 -raw))) %* & exit /b ')
# AveYo: fix annoyance after uninstalling Xbox, AveYo 2026.10.01

$id = 'ms-gamebar-annoyance'

#:: Status checkmark
$s6 = [char]0x2713; if (gp Registry::HKCR\ms-gamebar NoOpenWith -ea 0) {$s7 = ''} else {$s7 = $s6; $s6 = ''}

#:: Args / Dialog - skip the prompt by commandline parameters or rename script: ms-gamebar-annoyance apply.bat
$cl = ''; $arg = @{6 = 'apply'; 7 = 'restore'; 2 = 'cancel'} ; $f0 = ($env:0,"$pwd\.pasted")[!$env:0]
foreach ($a in $arg.Values) {if ("$(split-path $f0 -leaf) $env:1" -like "*$a*") {$cl = $a} }
if ($cl -eq '') {
  $choice = (new-object -ComObject Wscript.Shell).Popup("Yes to apply $s6  -  No to restore $s7", 0, $id, 0x1043)
  $cl = $arg[$choice]; $env:1 = $cl; if ($cl -eq 'cancel') {return}
}

#:: Under limited user
$toggle = (1,0)[$cl -eq 'apply']
sp "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" $toggle -type dword -force -ea 0
sp "HKCU:\System\GameConfigStore" "GameDVR_Enabled" $toggle -type dword -force -ea 0

#:: Under admin user
$ps = {
  $f0 = $args[0]; $cl = $args[1]; $id = $args[2]; [Console]::Title = "$id $cl"
  $toggle = (1,0)[$cl -eq 'apply']
  sp "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" $toggle -type dword -force -ea 0
  sp "HKCU:\System\GameConfigStore" "GameDVR_Enabled" $toggle -type dword -force -ea 0
  "ms-gamebar","ms-gamebarservices","ms-gamingoverlay" |foreach {
    if (!(test-path "Registry::HKCR\$_\shell")) {ni "Registry::HKCR\$_\shell" -force >''}
    if (!(test-path "Registry::HKCR\$_\shell\open")) {ni "Registry::HKCR\$_\shell\open" -force >''}
    if (!(test-path "Registry::HKCR\$_\shell\open\command")) {ni "Registry::HKCR\$_\shell\open\command" -force >''}
    sp "Registry::HKCR\$_" "(Default)" "URL:$_" -force
    sp "Registry::HKCR\$_" "URL Protocol" "" -force
    if ($toggle -eq 0) {
      sp "Registry::HKCR\$_" "NoOpenWith" "" -force
      sp "Registry::HKCR\$_\shell\open\command" "(Default)" "`"$env:SystemRoot\System32\systray.exe`"" -force
    } else {
      rp "Registry::HKCR\$_" "NoOpenWith" -force -ea 0
      ri "Registry::HKCR\$_\shell" -rec -force -ea 0
    }
  }
  start ms-gamebar://annoyance # AveYo: test if working
}

#:: Elevate
if ([Security.Principal.WindowsIdentity]::GetCurrent().Groups.Value -notcontains 'S-1-5-32-544') {
  write-host " '$id' Requesting ADMIN rights.. " -fore Black -back Yellow; sleep 2; pushd ~
  sp HKCU:\Volatile*\* $id ".{$ps} '$($f0-replace"'","''")' '$($cl-replace"'","''")' '$id'" -type MultiString -force -ea 0
  start powershell -args "-nop .([scriptblock]::create((gpv registry::HKU\S-1-5-21*\Volatile*\* '$id')))" -verb runas; popd
} else {. $ps $f0 $cl $id }

$Press_Enter_if_pasted_in_powershell

