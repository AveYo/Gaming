@(set "0=%~f0" '& set 1=%*) & powershell -nop -c "type -raw -lit $env:0 | powershell -nop -c -" & pause & exit /b ');.{

"Counter-Strike 2 persistent settings"

$video = @'
//setting.defaultres                    1280  //  width
//setting.defaultresheight              960   //  height
//setting.refreshrate_numerator         60    //  refresh integer part
//setting.refreshrate_denominator       1     //  refresh fraction part
  setting.fullscreen                    1     //  fullscreen
//setting.coop_fullscreen               0     //  fullscreen windowed
  setting.nowindowborder                1     //  borderless
//setting.fullscreen_min_on_focus_loss  1     //  must be 1 when using fullscreen
//setting.monitor_index                 0     //  monitor
//setting.aspectratiomode               0     //  aspect 4:3 0 | 16:9 1 | 16:10 2
  setting.high_dpi                      1     //  dpi

  Autoconfig                            2     //  custom preset
  setting.mat_vsync                     0     //  enable it in gpu driver instead
//setting.msaa_samples                  2     //  should enable AA when using FSR
  setting.r_csgo_cmaa_enable            0     //  use msaa 2 above instead
  setting.videocfg_shadow_quality       0     //  shadows high 2 | med 1 | low 0
  setting.videocfg_dynamic_shadows      1     //  must have for competitive play
  setting.videocfg_texture_detail       1     //  texture high 2 | med 1 | low 0
  setting.r_texturefilteringquality     2     //  anyso4x 3 | anyso2x 2 | trilinear 1
  setting.shaderquality                 0     //  smooth shadows and lighting but fps--
  setting.videocfg_particle_detail      0     //  smooth smokes and decals but fps--
  setting.videocfg_ao_detail            0     //  shadow oclussion but fps--
//setting.videocfg_hdr_detail           -1    //  HDR quality -1 | performance 8bit noise 3
  setting.videocfg_fsr_detail           0     //  FSR quality 2 | balanced 3 | minecraft 4
//setting.r_low_latency                 2     //  Reflex off 0 | on 1 | on+boost 2
  setting.r_csgo_lowend_objects         1     //  bonus
'@

$autoexec = @'
//r_fullscreen_gamma                    2.2   //  brightness slider - works on windowed too
//r_player_visibility_mode              1     //  kinda useless
  r_drawtracers_firstperson             1     //  tracers
  engine_no_focus_sleep                 0     //  power saving while alt-tab
//cl_input_enable_raw_keyboard          0     //  prevent keyboard issues
  r_show_build_info                     1     //  build info is a must when reporting issues
'@

############################################################################################################################

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
if (-not (test-path "$STEAM\userdata\$USRID\config\localconfig.vdf")) {
  $vdf = vdf_parse (gc $file -force -ea 0); if ($vdf.count -eq 0) {$vdf = vdf_parse @('"users"','{','}')}
  foreach ($id64 in $vdf.Item(0).Keys) { if ($vdf.Item(0)[$id64]["MostRecent"] -eq '"1"') {
      $id3 = ([long]$id64) - 76561197960265728; $USRID = ($id3--,$id3)[($id3 % 2) -eq 0]
  } }
}
if (-not (test-path "$STEAM\userdata\$USRID\config\localconfig.vdf")) {
  pushd "$STEAM\userdata"
  $lconf = (dir -filter "localconfig.vdf" -Recurse | sort LastWriteTime -Descending | Select -First 1).DirectoryName
  $USRID = split-path (split-path $lconf) -leaf
  popd
}

## AveYo: merge video settings
$vid_kv = @{} ; $vid = $video -split '\r?\n' -replace '^//.*','//' |foreach { if ($_ -ne "//") { $_.Trim() } }
$vid |foreach { $l = $_.split(" ",[StringSplitOptions]1); if ($l.count -ge 2) { $vid_kv[$l[0]] = $l[1] } }
$file = "$STEAM\userdata\$USRID\$APPID\local\cfg\cs2_video.txt"
$vdf = vdf_parse (gc $file -force -ea 0); if ($vdf.count -eq 0) {$vdf = vdf_parse @('"video.cfg"','{','"Version" "16"','}')}
foreach ($k in $vid_kv.Keys) { $vdf.Item(0)[$k] = """$($vid_kv[$k])""" }
if (-not (test-path "$file.old")) {copy -force $file "$file.old" -ea 0}
set-content -force -nonewline -lit $file $(vdf_print $vdf)
write-output "`n$file`n================"; write-output $vid

## AveYo: overwrite autoexec after making a backup
$auto = $autoexec -split '\r?\n' -replace '^//.*',"//" |foreach { if ($_ -ne "//") { $_.Trim() } }
$file = "$GAME\cfg\autoexec.cfg"
if (test-path $file) {
  $old = $file -replace "autoexec","autoexec_$(Get-Date -format "dd_MMM_yyyy_HH_mm_ss")"
  write-host -fore red "`nexisting autoexec.cfg saved as $old"; copy -force $file $old -ea 0
}
set-content -force -lit $file $auto
write-output "`n$file`n================"; write-output $auto

} #_press_Enter_if_pasted_in_powershell
