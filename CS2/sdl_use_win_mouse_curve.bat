@(set "0=%~f0" ') & powershell -nop -c .([scriptblock]::create((type $env:0 -raw))) %* & pause & exit /b ');.{

$Undo  = 0                            ## AveYo: set to 1 to remove SDL environment variables

$do = ('enabling','disabling')[$Undo -gt 0]
"`nAveYo: $do SDL raw input with windows mouse speed curve (and acceleration)"
@{
  SDL_MOUSE_RELATIVE_SYSTEM_SCALE = 1
  SDL_MOUSE_RELATIVE_SPEED_SCALE  = 1.0
  SDL_MOUSE_NORMAL_SPEED_SCALE    = 1.0
  SDL_MOUSE_RELATIVE_MODE_CENTER  = 0
  SDL_MOUSE_RELATIVE_WARP_MOTION  = 0
  SDL_WINDOWS_RAW_KEYBOARD = 1                ## optional
  SDL_WINDOWS_DPI_AWARENESS = "permonitorv2"  ## optional
}.getenumerator()|% {foreach ($t in 0,1) {[Environment]::SetEnvironmentVariable($_.name, ($_.value,$null)[$UNDO -gt 0], $t)}}
$STEAM = resolve-path (gpv "HKCU:\SOFTWARE\Valve\Steam" SteamExe) # must relaunch Steam to update SDL vars
start $STEAM -args "-ifrunning -silent +app_stop 730 -shutdown +quit now" -wait; sleep 5
start $STEAM -args "-quicklogin -forceservice -nofriendsui -no-dwrite -nojoy -noshaders -nodirectcomp -cef-disable-gpu"
} $Press_Enter_if_pasted_in_powershell
