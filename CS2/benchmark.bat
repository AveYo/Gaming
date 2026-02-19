@(set "0=%~f0" '& set 1=%*) & powershell -nop -c "type -raw -lit $env:0 | powershell -nop -c -" & pause & exit /b ');.{

## Benchmark.cfg by AveYo - add the mean median mode at 0.1% 1% P95 P50 marks in the cl_showfps 4 history file
$filename = "prof_de_ancient_night"
function stats($d, $c=0) {
  foreach ($g in ($d | group | sort -Descending count)) { if ($g.count -ge $c) {$c = $g.count; $mode = $g.Name} else {break} }
  $median = if ($d.count % 2) {$d[($d.count/2) - 1]} else {($d[($d.count/2)] + $d[($d.count/2) - 1]) / 2}
  $mean = if ($d) { ($d |measure-object -average).Average.tostring("#.#") }
  write-output ("Mean: {0,-5} Median: {1,-5} Mode: {2,-5}" -f $mean,$median,$mode)
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
  $head = $list = $val = @()
  $f1 = $f |foreach {$h1 = 0} {
    $o = $_; $s = $o.split(',:').trim(); if ($s[0] -eq 'Frame Rate') { $h1++ }
    if ($h1 -lt 2) { if ($h1 -eq 1) { $h1++ } ; $head += $o }
    elseif ($h1 -eq 2 -and $s[1] -ne 0) { for ($i=1; $i -le $s[1]; $i++) { $val += [int]$s[0] } ; $list += $o }
  }
#   [array]::reverse($list); [array]::reverse($val);
  $l = $list.count; $k = $val.count
  $p01 = [math]::ceiling($k * 0.001); $p1  = [math]::ceiling($k * 0.01)
  $p95 = [math]::ceiling($k * 0.05);  $p50 = [math]::ceiling($k * 0.50)

  $f2 = $head |foreach {
    $o = $_; $s = $_.split(',:').trim()
    if ($s[0] -eq 'Total frames') { $o += ", Active : $k"} elseif ($s[0] -eq 'Frame Rate') { $o += ", Stats" } ; $o
  }
  $f2+= $list |foreach {$n = 0} {
    $o = $_; $s = $o.split(',:').trim(); $n += [int]$s[1]
    if ($p01 -gt 0 -and $n -ge $p01) { $o += ", 0.1% $(stats $val[0..$p01])";  $p01 = 0 }
    if ($p1  -gt 0 -and $n -ge $p1)  { $o += ", 1%   $(stats $val[0..$p1])";   $p1  = 0 }
    if ($p95 -gt 0 -and $n -ge $p95) { $o += ", P95  $(stats $val[$p95..$k])"; $p95 = 0 }
    if ($p50 -gt 0 -and $n -ge $p50) { $o += ", P50  $(stats $val[0..$k])";    $p50 = 0 }
    $o
  }
  $f2 | set-content "$GAME\$filename$()_stats.csv" -force; import-csv "$GAME\$filename$()_stats.csv" | Format-Table
} else { echo $GAME\$filename.csv not found, run benchmark.cfg in the game first }

}
#_press_Enter_if_pasted_in_powershell
