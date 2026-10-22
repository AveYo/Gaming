@(set "0=%~f0" ') & powershell -nop -c .([scriptblock]::create((type $env:0 -raw))) %* & exit /b ');.{
## SAVE as .bat OR .ps1 / ENTER in powershell

[Console]::Title = "reset_Dota2" ## 2026 v6 modernization
""
"    INSTRUCTIONS:                                                                                   "
" 1. Make sure you launch Dota 2 at least once with the account having troubles,                     "
"    else this script will use the last logged on account                                            "
" 2. Run this script - you might need to right-click it and Run as Administrator                     "
" 3. After launching Dota 2, chose 'Local Save' at the Cloud Sync Conflict prompt then 'Play Anyway' "
" 4. Adjust your settings, then restart Dota 2. Did it stick? Repeat procedure with Cloud On and Off "
""

$APPID      = 570
$APPNAME    = "dota2"
$INSTALLDIR = "dota 2 beta"
$MOD        = "dota"
$GAMEBIN    = "bin\win64"

## AveYo: abort if steam not found
$STEAM = resolve-path (gp "HKCU:\SOFTWARE\Valve\Steam" -ea 0).SteamPath
if (-not (test-path "$STEAM\steam.exe") -or -not (test-path "$STEAM\steamapps\libraryfolders.vdf")) {
  write-host " Steam not found! " -fore Black -back Yellow; sleep 7; return
}

##  AveYo: lean and mean helper functions to process steam vdf files
function vdf_parse {
  param([string[]]$vdf, [ref]$line = ([ref]0), [string]$re = '\A\s*("(?<k>[^"]+)"|(?<b>[\{\}]))\s*(?<v>"(?:\\"|[^"])*")?\Z')
  $obj = [ordered]@{}
  while ($line.Value -lt $vdf.count) {
    if ($vdf[$line.Value] -match $re) {
      if ($matches.k) { $key = $matches.k }
      if ($matches.v) { $obj[$key] = $matches.v }
      elseif ($matches.b -eq '{') { $line.Value++; $obj[$key] = vdf_parse -vdf $vdf -line $line -re $re}
      elseif ($matches.b -eq '}') { break }
    }
    $line.Value++
  }
  return $obj
}
function vdf_print {
  param($vdf, [ref]$indent = ([ref]0), $nested = ([ordered]@{}).gettype())
  if ($vdf -isnot $nested) {return}
  foreach ($key in $vdf.Keys) {
    if ($vdf[$key] -is $nested) {
      $tabs = "${\t}" * $indent.Value
      write-output "$tabs""$key""${\n}$tabs{${\n}"
      $indent.Value++; vdf_print -vdf $vdf[$key] -indent $indent -nested $nested; $indent.Value--
      write-output "$tabs}${\n}"
    } else {
      $tabs = "${\t}" * $indent.Value
      write-output "$tabs""$key""${\t}${\t}$($vdf[$key])${\n}"
    }
  }
}
function vdf_mkdir {
  param($vdf, [string]$path = ''); $s = $path.split('\',2); $key = $s[0]; $recurse = $s[1]
  if ($key -and $vdf.Keys -notcontains $key) { $vdf[$key] = [ordered]@{} }
  if ($recurse) { vdf_mkdir $vdf[$key] $recurse }
}
@{'\t'=9; '\n'=10; '\f'=12; '\r'=13; '\"'=34; '\$'=36}.getenumerator() | foreach {set $_.Name $([char]($_.Value)) -force}

##  detect APP folder
$file = "$STEAM\steamapps\libraryfolders.vdf"
$vdf = vdf_parse (gc $file -force -ea 0); if ($vdf.count -eq 0) {$vdf = vdf_parse @('"libraryfolders"','{','}')}
foreach ($nr in $vdf.Item(0).Keys) {
  if ($vdf.Item(0)[$nr]["apps"] -and $vdf.Item(0)[$nr]["apps"]["$APPID"]) {
    $l = resolve-path $vdf.Item(0)[$nr]["path"].Trim('"'); $i = "$l\steamapps\common\$INSTALLDIR"
    if (test-path "$i\game\$MOD\steam.inf") { $STEAMAPPS = "$l\steamapps"; $GAMEROOT = "$i\game"; $GAME = "$i\game\$MOD" }
  }
}

##  detect active user from registry / loginusers.vdf / latest localconfig.vdf
$file = "$STEAM\config\loginusers.vdf"
$USRID = (gp "HKCU:\Software\Valve\Steam\ActiveProcess" -ea 0).ActiveUser
if ($USRID -lt 1) {
  $vdf = vdf_parse (gc $file -force -ea 0); if ($vdf.count -eq 0) {$vdf = vdf_parse @('"users"','{','}')}
  foreach ($id64 in $vdf.Item(0).Keys) { if ($vdf.Item(0)[$id64]["MostRecent"] -eq '"1"') {
      $id3 = ([long]$id64) - 76561197960265728; $USRID = ($id3--,$id3)[($id3 % 2) -eq 0]
  } }
}
if ($USRID -lt 1) {
  pushd "$STEAM\userdata"
  $lconf = (dir -filter "localconfig.vdf" -Recurse | sort LastWriteTime -Descending | Select -First 1).DirectoryName
  $USRID = split-path (split-path $lconf) -leaf
  popd
}
$USRCLOUD = "$STEAM\userdata\$USRID"
$USRLOCAL = "$STEAM\userdata\$USRID\$APPID\local"
" STEAM = $STEAM`n GAME  = $GAME`n CLOUD = $USRCLOUD"
"`n $APPNAME will start automatically after a while ..."
pushd $GAMEROOT;
timeout /t 10

##  AveYo: close steam and game if already running - gracefully first, then forced
if ((gp "HKCU:\Software\Valve\Steam\ActiveProcess" -ea 0).pid -gt 0) {
  $refresh = "-ifrunning -silent +app_mark_validation $APPID 0 +app_stop $APPID -shutdown +quit now"
  start "$STEAM\Steam.exe" -args $refresh -wait; sleep 5
  sp "HKCU:\Software\Valve\Steam\ActiveProcess" pid 0 -ea 0
}
while (gps -name steam -ea 0) {kill -name 'steamwebhelper','steam',$APPNAME -force -ea 0; del "$STEAM\.crash" -force -ea 0}

##  AveYo: steam cfg
$file = "$STEAM\config\config.vdf"
$vdf = vdf_parse (gc $file -force -ea 0); if ($vdf.count -eq 0) {$vdf = vdf_parse @('"InstallConfigStore"','{','}')}
vdf_mkdir $vdf.Item(0) "Software\Valve\Steam"; $vdf.Item(0)["Software"]["Valve"]["Steam"]["AllowDownloadsDuringGameplay"] = '"1"'
set-content -force -nonewline -lit $file $(vdf_print $vdf) # vdf_print $vdf
$file = "$STEAM\userdata\$USRID\config\localconfig.vdf"
$vdf = vdf_parse (gc $file -force -ea 0); if ($vdf.count -eq 0) {$vdf = vdf_parse @('"UserLocalConfigStore"','{','}')}
vdf_mkdir $vdf.Item(0) "Software\Valve\Steam\Apps\$APPID"
$vdf.Item(0)["Software"]["Valve"]["Steam"]["Apps"]["$APPID"]["cloud"]["last_sync_state"] = '"changeslocally"'
$vdf.Item(0)["Software"]["Valve"]["Steam"]["Apps"]["$APPID"]["DisableUpdatesUntil"] = '"0"'
$vdf.Item(0)["Software"]["Valve"]["Steam"]["Apps"]["$APPID"]["LaunchOptions"] = '"-novid"'
vdf_mkdir $vdf.Item(0) "apps\$APPID"
$vdf.Item(0)["apps"]["$APPID"]["OverlayAppEnable"] = '"0"'
$vdf.Item(0)["apps"]["$APPID"]["UseSteamControllerConfig"] = '"0"'
vdf_mkdir $vdf.Item(0) "friends"; $vdf.Item(0)["friends"]["SignIntoFriends"] = '"0"'
set-content -force -nonewline -lit $file $(vdf_print $vdf) # vdf_print $vdf
$file = "$STEAM\userdata\$USRID\7\remote\sharedconfig.vdf"
$vdf = vdf_parse (gc $file -force -ea 0); if ($vdf.count -eq 0) {$vdf = vdf_parse @('"UserRoamingConfigStore"','{','}')}
vdf_mkdir $vdf.Item(0) "Software\Valve\Steam\Apps\$APPID"
$vdf.Item(0)["Software"]["Valve"]["Steam"]["Apps"]["$APPID"]["cloudenabled"] = '"1"'
set-content -force -nonewline -lit $file $(vdf_print $vdf) # vdf_print $vdf

##  AveYo: clear verify integrity flags after a crash for quicker relaunch
$file = "$STEAMAPPS\appmanifest_$APPID.acf"
if (test-path $file) {
  $vdf = vdf_parse (gc $file -force -ea 0); if ($vdf.count -eq 0) {$vdf = vdf_parse @('"AppState"','{','}')} ; $save = 0
  if ($vdf.Item(0)["StateFlags"] -ne '"4"') { $vdf.Item(0)["StateFlags"]='"4"'; $save++ }
  if ($vdf.Item(0)["FullValidateAfterNextUpdate"]) { $vdf.Item(0)["FullValidateAfterNextUpdate"]='"0"'; $save++ }
  $vdf.Item(0)["AutoUpdateBehavior"]='"1"'; $vdf.Item(0)["AllowOtherDownloadsWhileRunning"]='"1"'
  if ($save -gt 0) {set-content $file $(vdf_print $vdf) -nonewline} #; vdf_print $vdf
} else {
  write-host " $file missing or wrong lib path detected! continuing with a default manifest...`n" -fore Yellow
  $vdf = "`"AppState`"`n{`n`"AppID`" `"$APPID`"`n`"Universe`" `"1`"`n`"installdir`" `"$INSTALLDIR`"`n`"StateFlags`" `"4`"`n}`n"
  if ($GAME) { set-content $file $(vdf_print $vdf) -nonewline }
}

## clear cfg settings keeping autoexec.cfg
$cfg = ''; if (test-path "$GAME\cfg\autoexec.cfg") { $cfg = gc "$GAME\cfg\autoexec.cfg" -raw }
rmdir -recurse "$GAME\cfg" -force -ea 0; mkdir "$GAME\cfg" -force -ea 0 >''
if ($cfg -ne '') { set-content "$GAME\cfg\autoexec.cfg" $cfg -nonewline }
$vcfg = "`"config`"`n{`n`t`"bindings`"`n`t{`n`t`t`t`"\`"`t`t`"toggleconsole`"`n`t}`n}`n"
set-content "$GAME\cfg\user_keys_default.vcfg" $vcfg -nonewline
rmdir -recurse "$GAME\core" -force -ea 0; del "$GAMEROOT\core\cfg\*.json","$GAMEROOT\core\cfg\*.bin" -force -ea 0

## clear cloud settings keeping hero grids, hero builds, control groups, hotkeys
takeown /f "$USRCLOUD" /r /d y >'' 2>''; icacls "$USRCLOUD" /reset /t /q >'' 2>''; attrib -r "$USRCLOUD" /s /d >'' 2>''
del "$USRCLOUD\$APPID\remotecache.vdf" -force -ea 0
pushd "$USRCLOUD\$APPID"
dir -recurse -file -exclude '*.png','*.jpg','dotakeys_personal.lst','control_groups.txt','herobuilds.cfg',
  'hero_grid_config.json'<#,'voice_ban.dt'#> |% { process { set-content $_ '' -nonewline } }

## clear shader and inventory cache
rmdir -recurse "$GAME\shadercache" -force -ea 0; mkdir "$GAME\shadercache" -force -ea 0 >''
rmdir -recurse "$STEAMAPPS\shadercache\$APPID" -force -ea 0
del "$GAME\cache_$(split-path $USRCLOUD -leaf)*.soc" -force -ea 0

##  AveYo: launch game
$quick = "-silent -quicklogin -forceservice -console -vrdisable -nofriendsui -no-dwrite -nojoy " +
         "-cef-disable-gpu -cef-disable-gpu-sandbox -cef-delaypageload -cef-force-occlusion +verifySignaturesBeforeLaunch 0"
powershell -nop -c "start '$STEAM\Steam.exe' -args '$quick -applaunch $APPID -autoconfig -sw -w 1280 -h 720 -refresh 0'"

} #_press_Enter_if_pasted_in_powershell
