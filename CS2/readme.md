POTATO SETTINGS TO MINIMIZE INPUT LAG

1. Always match desktop res before launching
![1. Always match desktop res before launching](https://raw.githubusercontent.com/AveYo/Gaming/refs/heads/main/CS2/1.%20Always%20match%20desktop%20res%20before%20launching.png)
2. Explicit res and threads via steam launch options
![2. Explicit res and threads via steam launch options](https://raw.githubusercontent.com/AveYo/Gaming/refs/heads/main/CS2/2.%20Explicit%20res%20and%20threads%20via%20steam%20launch%20options.png))
3. Driver settings to improve texture streaming
![3. Driver settings to improve texture streaming](https://raw.githubusercontent.com/AveYo/Gaming/refs/heads/main/CS2/3.%20Driver%20settings%20to%20improve%20texture%20streaming.png)
4. Cap fps in-game, reflex+boost and low video
![4. Cap fps in-game, reflex+boost and low video](https://raw.githubusercontent.com/AveYo/Gaming/refs/heads/main/CS2/4.%20Cap%20fps%20in-game%2C%20reflex%2Bboost%20and%20low%20video.png)
5. sdl_use_win_mouse_curve.bat
```ps1
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
```
6. win_mouse_sensitivity.bat
```ps1
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
```
5. autoexec.cfg
```cs
con_enable 1; developer 0; fs_report_sync_opens 0; panorama_console_position_and_size 0|62|1552|942;
log_flags Console +donotecho; log_color Console FFFFFFFF; log_color InputService 00FFFFFF; log_color VProf FC52FFFF;
log_flags "Localization System" MaterialSystem SoundSystemLowLevel SndOperators SceneSystem SceneFileCache RenderSystem +donotecho;
log_flags RenderPipelineCsgo AnimResource ResourceSystem Missions SteamNetSockets NetSteamConn Host Server Developer +donotecho;
log_flags Console -donotecho; /// AveYo: less spam in the console

/// AveYo: toggle buffers (along with interp) from console as most valve servers are overwhelmed by cheating bots and vaclive crap
alias lag "rate;cl_net_buffer_ticks;cl_tickpacket_desired_queuelength;cl_interp"
alias { "cl_net_buffer_ticks 2; cl_tickpacket_desired_queuelength 2.24; cl_interp_ratio 2.56; rate 786432; lag" /// 40ms q
alias [ "cl_net_buffer_ticks 1; cl_tickpacket_desired_queuelength 0.96; cl_interp_ratio 1.28; rate 786432; lag" /// 20ms q
alias ] "cl_net_buffer_ticks 0; cl_tickpacket_desired_queuelength 0; cl_interp_ratio 0; rate 786432; lag" /// default
[ // 20ms queue
cl_predict_body_shot_fx 1; cl_predict_head_shot_fx 1; cl_predict_kill_ragdolls 0; /// AveYo: snappiness > fake dinks
//mm_dedicated_search_maxping 40;

/// AveYo: controlling sens via mouse dpi + sdl env + windows mouse pointer speed instead
sensitivity 1;
cl_input_enable_raw_keyboard 1; cl_usercmd_max_per_movemsg 8; /// AveYo: maximizing potential subtick_moves
engine_low_latency_sleep_after_client_tick 0; /// AveYo: misbehaves again after the tamagotchi update

/// AveYo: highly recommended to find the fps_max sweet spot using benchmark.cfg and then benchmark.bat to find the 99% value
//fps_max 192;
fps_max_ui 64; cl_hud_telemetry_frametime_poor 16.67; cl_hud_telemetry_frametime_show 1; engine_no_focus_sleep 80; // alt-tab power
lb_barnlight_shadowmap_scale 0.5; r_particle_shadows_compute 0; cl_ragdoll_limit 1;
alias bb "alias set v2;sv_cheats 1;exec_async benchmark"; /// Benchmark.cfg run once with: BB
alias bx "alias set vx;sv_cheats 1;exec_async benchmark"; /// Can also loop 10 times with: BX
alias b5 "alias set v5;sv_cheats 1;exec_async benchmark"; /// Can also loop  5 times with: B5

alias tm_ "cl_hud_telemetry_serverrecvmargin_graph_show 0;cl_hud_telemetry_net_quality_graph_show 0";
alias tm0 "alias tm tm1;cl_hud_telemetry_frametime_show 0;cl_hud_telemetry_ping_show 0;cl_hud_telemetry_net_misdelivery_show 0;tm_";
alias tm1 "alias tm tm2;cl_hud_telemetry_frametime_show 2;cl_hud_telemetry_ping_show 2;cl_hud_telemetry_net_misdelivery_show 2";
alias tm2 "alias tm tm0;cl_hud_telemetry_serverrecvmargin_graph_show 2;cl_hud_telemetry_net_quality_graph_show 2";
tm0; /// AveYo: telemetry toggle
bind KP_1 tm;
bind KP_MINUS "ignorerad;clutch_mode_toggle";
bind KP_PLUS "status;cl_ticktiming print detail;showconsole";

alias \ hideconsole;
//bind \ toggleconsole;
//bind ` +voicerecord;

//bind F8 "disconnect;cl_showpos 0;sv_cheats 0;exec gamemode_competitive";

execifexists personal
```
