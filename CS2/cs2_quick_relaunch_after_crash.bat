@(set "0=%~f0" '& set 1=%*) & powershell -nop -c "type -raw -lit $env:0 | powershell -nop -c -" & exit /b ');.{

$APPID = 730; $APPNAME = "cs2"; $INSTALLDIR = "Counter-Strike Global Offensive"; $MOD = "csgo"; $GAMEBIN = "bin\win64"

##  AveYo: detect STEAM
$STEAM = resolve-path (gp "HKCU:\SOFTWARE\Valve\Steam").SteamPath
if (-not (test-path "$STEAM\steam.exe") -or -not (test-path "$STEAM\steamapps\libraryfolders.vdf")) {
  write-host " Steam not found! " -fore Black -back Yellow; sleep 7; return 1
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

##  AveYo: detect APP folder
$file = "$STEAM\steamapps\libraryfolders.vdf"
$vdf = vdf_parse (gc $file -force -ea 0); if ($vdf.count -eq 0) {$vdf = vdf_parse @('"libraryfolders"','{','}')}
foreach ($nr in $vdf.Item(0).Keys) {
  if ($vdf.Item(0)[$nr]["apps"] -and $vdf.Item(0)[$nr]["apps"]["$APPID"]) {
    $l = resolve-path $vdf.Item(0)[$nr]["path"].Trim('"'); $i = "$l\steamapps\common\$INSTALLDIR"
    if (test-path "$i\game\$MOD\steam.inf") { $STEAMAPPS = "$l\steamapps"; $GAMEROOT = "$i\game"; $GAME = "$i\game\$MOD" }
  }
}

##  AveYo: detect active user from registry / loginusers.vdf / latest localconfig.vdf
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

##  AveYo: close steam if already running - gracefully first, then forced
if ((gp "HKCU:\Software\Valve\Steam\ActiveProcess" -ea 0).pid -gt 0) {
  $refresh = "-ifrunning -silent +app_mark_validation $APPID 0 +app_stop $APPID +http_cache_clearall -shutdown +quit now"
  start "$STEAM\Steam.exe" -args $refresh -wait
  sp "HKCU:\Software\Valve\Steam\ActiveProcess" pid 0 -ea 0
}
while (gps -name steam -ea 0) {kill -name 'steamwebhelper','steam' -force -ea 0; del "$STEAM\.crash" -force -ea 0}

##  AveYo: steam cfg
$file = "$STEAM\config\config.vdf"
$vdf = vdf_parse (gc $file -force -ea 0); if ($vdf.count -eq 0) {$vdf = vdf_parse @('"InstallConfigStore"','{','}')}
vdf_mkdir $vdf.Item(0) "Software\Valve\Steam"; $vdf.Item(0)["Software"]["Valve"]["Steam"]["AllowDownloadsDuringGameplay"] = '"1"'
set-content -force -nonewline -lit $file $(vdf_print $vdf)
vdf_print $vdf
$file = "$STEAM\userdata\$USRID\config\localconfig.vdf"
$vdf = vdf_parse (gc $file -force -ea 0); if ($vdf.count -eq 0) {$vdf = vdf_parse @('"UserLocalConfigStore"','{','}')}
vdf_mkdir $vdf.Item(0) "Software\Valve\Steam\Apps\$APPID"
$vdf.Item(0)["Software"]["Valve"]["Steam"]["Apps"]["$APPID"]["cloud"]["last_sync_state"] = '"synchronized"'
$vdf.Item(0)["Software"]["Valve"]["Steam"]["Apps"]["$APPID"]["DisableUpdatesUntil"] = '"0"'
$vdf.Item(0)["Software"]["Valve"]["Steam"]["Apps"]["$APPID"]["LaunchOptions"] = '""'
vdf_mkdir $vdf.Item(0) "apps\$APPID"
$vdf.Item(0)["apps"]["$APPID"]["OverlayAppEnable"] = '"0"'
$vdf.Item(0)["apps"]["$APPID"]["UseSteamControllerConfig"] = '"0"'
vdf_mkdir $vdf.Item(0) "friends"; $vdf.Item(0)["friends"]["SignIntoFriends"] = '"0"'
set-content -force -nonewline -lit $file $(vdf_print $vdf)
vdf_print $vdf
$file = "$STEAM\userdata\$USRID\7\remote\sharedconfig.vdf"
$vdf = vdf_parse (gc $file -force -ea 0); if ($vdf.count -eq 0) {$vdf = vdf_parse @('"UserRoamingConfigStore"','{','}')}
vdf_mkdir $vdf.Item(0) "Software\Valve\Steam\Apps\$APPID"
$vdf.Item(0)["Software"]["Valve"]["Steam"]["Apps"]["$APPID"]["cloudenabled"] = '"0"'
set-content -force -nonewline -lit $file $(vdf_print $vdf)
vdf_print $vdf

##  AveYo: clear verify integrity flags after a crash for quicker relaunch
$file = "$STEAMAPPS\appmanifest_$APPID.acf"
if (test-path $file) {
  $vdf = vdf_parse (gc $file -force -ea 0); if ($vdf.count -eq 0) {$vdf = vdf_parse @('"AppState"','{','}')} ; $save = 0
  if ($vdf.Item(0)["StateFlags"] -ne '"4"') { $vdf.Item(0)["StateFlags"]='"4"'; $save++ }
  if ($vdf.Item(0)["FullValidateAfterNextUpdate"]) { $vdf.Item(0)["FullValidateAfterNextUpdate"]='"0"'; $save++ }
  $vdf.Item(0)["AutoUpdateBehavior"]='"1"'; $vdf.Item(0)["AllowOtherDownloadsWhileRunning"]='"1"'
  if ($save -gt 0) {set-content $file $(vdf_print $vdf) -nonewline}
  vdf_print $vdf
}

##  AveYo: reopen steam
$QUICK = "-silent -quicklogin -forceservice -console -vrdisable -nofriendsui -no-dwrite -nojoy " +
         "-cef-disable-gpu -cef-disable-gpu-sandbox -cef-delaypageload -cef-force-occlusion +verifySignaturesBeforeLaunch 0"
powershell -nop -c "start '$STEAM\Steam.exe' -args '$QUICK -applaunch $APPID -w 1024 -h 768 -refresh 0'"

}
#_press_Enter_if_pasted_in_powershell
