@(set "0=%~f0" '& set 1=%*) & powershell -nop -c "type -raw -lit $env:0 | powershell -nop -c -" & exit /b ');.{

$APPID = 730; $APPNAME = "cs2"; $INSTALLDIR = "Counter-Strike Global Offensive"; $MOD = "csgo"; $GAMEBIN = "bin\win64"

##  AveYo: detect STEAM
$STEAM = resolve-path (gp "HKCU:\SOFTWARE\Valve\Steam").SteamPath
if (-not (test-path "$STEAM\steam.exe") -or -not (test-path "$STEAM\steamapps\libraryfolders.vdf")) {
  write-host " Steam not found! " -fore Black -back Yellow; sleep 7; return 1
}

##  AveYo: close steam if already running - gracefully first, then forced
if ((gp "HKCU:\Software\Valve\Steam\ActiveProcess" -ea 0).pid -gt 0) {
  start "$STEAM\Steam.exe" -args "-ifrunning -silent +app_mark_validation $APPID 0 +app_stop $APPID -shutdown +quit now" -wait
  sp "HKCU:\Software\Valve\Steam\ActiveProcess" pid 0 -ea 0; $y = $true
}
while (gps -name steam -ea 0) {kill -name 'steamwebhelper','steam' -force -ea 0; del "$STEAM\.crash" -force -ea 0; $y = $true}

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

##  AveYo: clear verify integrity flags after a crash for quicker relaunch
$file = "$STEAMAPPS\appmanifest_$APPID.acf"
if (test-path $file) {
  $vdf = vdf_parse (gc $file -force -ea 0); if ($vdf.count -eq 0) {$vdf = vdf_parse @('"AppState"','{','}')} ; $save = 0
  if ($vdf.Item(0)["StateFlags"] -ne '"4"') { $vdf.Item(0)["StateFlags"]='"4"'; $save++ }
  if ($vdf.Item(0)["FullValidateAfterNextUpdate"]) { $vdf.Item(0)["FullValidateAfterNextUpdate"]='"0"'; $save++ }
  if ($save -gt 0) {set-content $file (vdf_print $vdf) -nonewline}
  vdf_print $vdf
}

##  AveYo: reopen steam
$QUICK = "-silent -quicklogin -forceservice -console -vrdisable -nofriendsui -no-dwrite -nojoy " +
         "-cef-disable-gpu -cef-disable-gpu-sandbox -cef-delaypageload -cef-force-occlusion"
powershell -nop -c "start '$STEAM\Steam.exe' -args '$QUICK -applaunch $APPID'"

}
#_press_Enter_if_pasted_in_powershell
