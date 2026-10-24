@(set "0=%~f0" ') & powershell -nop -c .([scriptblock]::create((type $env:0 -raw))) %* & pause & exit /b ');.{

$MouseSensitivity =  0                ## AveYo: change 1 to 20 or leave at 0 to select in settings ui

if ($MouseSensitivity -eq 0) {
  start ms-settings:mousetouchpad; "AveYo: close Settings to continue ..."; gps -Name SystemSettings -ea 0 | Wait-Process
}
if ($MouseSensitivity -gt 0 -and $MouseSensitivity -le 20) {
"AveYo: using `$MouseSensitivity = $MouseSensitivity from script"
  $c1 = '[DllImport("user32")]public static extern bool SystemParametersInfo(uint a, uint b, uint c, uint d);'
  $cs = add-type -name spi -namespace user32 -memberDefinition $c1 -passThru
  $cs::SystemParametersInfo(0x0071, 0, $MouseSensitivity, 0) |out-null
  sp 'HKCU:\Control Panel\Mouse' MouseSensitivity $MouseSensitivity -force
}
$sensitivity = @{
  1 = 0.03125; 2 = 0.0625; 3 = 0.125; 4 = 0.25; 5 = 0.375; 6 = 0.5;  7 = 0.625; 8 = 0.75; 9 = 0.875; 10 = 1
 11 = 1.25;   12 = 1.5;   13 = 1.75; 14 = 2;   15 = 2.25; 16 = 2.5; 17 = 2.75; 18 = 3;    19 = 3.25; 20 = 3.5
}
[int]$speed = gpv 'HKCU:\Control Panel\Mouse' MouseSensitivity -ea 0
"`nMouse Pointer Speed: $speed -> sensitivity: $($sensitivity[$speed])"
800,1000,1200,1600,2400,3200 |% {"@ {2,4} dpi:`t{0,4} edpi`t{1,4} edpi +EPP" -f ($sensitivity[$speed]*$_), ($speed/10*$_), $_}
} #Press_Enter_if_pasted_in_powershell
