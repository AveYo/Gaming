@(set "0=%~f0" '& set 1=%*) & powershell -nop -c "type -raw -lit $env:0 | powershell -nop -c -" & pause & exit /b ');.{

## Benchmark.cfg by AveYo - calculate the mean median mode values for the fps history file
$filename = "prof_de_ancient_night"
function stats($d) {
  foreach ($g in ($d | group | sort -Descending count)) { if ($g.count -ge $j) {$j = $g.count; $mode = $g.Name} else {break} }
  $median = if ($d.count % 2) {$d[($d.count/2) - 1]} else {($d[($d.count/2)] + $d[($d.count/2) - 1]) / 2}
  $mean = ($d |measure-object -average).Average.tostring("#.#"); "Mean: $mean  Median: $median  Mode: $mode"
}

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

##  AveYo: detect APP folder
$file = "$STEAM\steamapps\libraryfolders.vdf"
$vdf = vdf_parse (gc $file -force -ea 0); if ($vdf.count -eq 0) {$vdf = vdf_parse @('"libraryfolders"','{','}')}
foreach ($nr in $vdf.Item(0).Keys) {
  if ($vdf.Item(0)[$nr]["apps"] -and $vdf.Item(0)[$nr]["apps"]["$APPID"]) {
    $l = resolve-path $vdf.Item(0)[$nr]["path"].Trim('"'); $i = "$l\steamapps\common\$INSTALLDIR"
    if (test-path "$i\game\$MOD\steam.inf") { $STEAMAPPS = "$l\steamapps"; $GAMEROOT = "$i\game"; $GAME = "$i\game\$MOD" }
  }
}

if (test-path "$GAME\$filename.csv") {
  $f = gc "$GAME\$filename.csv"
  $l = $f.count; $a = @(); $b1 = $b2 = $t = $n = 0; $p01 = $p1 = $p5 = $p50 = $p95 = $p99 = !1
  $f1 = $f |% { $s = $_.split(',:').trim(); if ($s[0] -eq 'Frame Rate') { $b1++ }
    if ($b1 -lt 2) { if ($b1 -eq 1) { $b1++ } } elseif ($b1 -eq 2 -and $s[1] -ne 0) { $t += [int]$s[1] }
  }
  $c = $t; $z = 0
  $f2 = $f |% {
    $s = $_.split(',:').trim(); $o = $_
    if ($s[0] -eq 'Total frames') { $o += ", Active : $t"} elseif ($s[0] -eq 'Frame Rate') { $b2++; $o += ", Low Stats" }
    if ($b2 -lt 2) { if ($b2 -eq 1) { $b2++ } ; $o } elseif ($b2 -eq 2 -and $s[1] -ne 0) {
      $n += [int]$s[1]; for ($i=1; $i -le $s[1]; $i++) { $a += [int]$s[0]; $c-- }
      $k = [math]::ceiling($t * 0.001); if (!$p01  -and $n -ge $k) { $p01  = !0; $o += ", 0.1%  $(stats $a[0..$k])" }
      $k = [math]::ceiling($t * 0.010); if (!$p1   -and $n -ge $k) { $p1   = !0; $o += ", 1%    $(stats $a[0..$k])" }
      $k = [math]::ceiling($t * 0.050); if (!$p5   -and $n -ge $k) { $p5   = !0; $o += ", 5%    $(stats $a[0..$k])" }
      $k = [math]::ceiling($t * 0.500); if (!$p50  -and $n -ge $k) { $p50  = !0; $o += ", 50%   $(stats $a[0..$k])" }
      $k = [math]::ceiling($t * 0.950); if (!$p95  -and $n -ge $k) { $p95  = !0; $o += ", 95%   $(stats $a[0..$k])" }
      $k = [math]::ceiling($t * 0.990); if (!$p99  -and $n -ge $k) { $p99  = !0; $o += ", 99%   $(stats $a[0..$k])" }
      if ($c -le 0) { $o += ", 100%  $(stats $a[0..$t])" } ; $o
    }
  }
  $f2 | set-content "$GAME\$filename.csv" -force; import-csv "$GAME\$filename.csv" | Format-Table
} else { echo $GAME\$filename.csv not found, run benchmark.cfg in the game first }

}
#_press_Enter_if_pasted_in_powershell
