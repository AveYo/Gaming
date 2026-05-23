 
@echo off & title CS2 crash files export || by AveYo, 2023.10.19
echo  Exporting CS2 crash files, grouped by date
 
:: detect STEAM path
for /f "tokens=2*" %%R in ('reg query HKCU\SOFTWARE\Valve\Steam /v SteamPath 2^>nul') do set "steam_reg=%%S"
for %%S in ("%steam_reg%") do set "STEAM=%%~fS"
 
:: detect CS2 path
set CS2=& set lib=& for /f usebackq^ delims^=^"^ tokens^=4 %%s in (`findstr /c:":\\" "%STEAM%\steamapps\libraryfolders.vdf"`) do (
  if exist "%%s\steamapps\appmanifest_730.acf" (
    if exist "%%s\steamapps\common\Counter-Strike Global Offensive\game\core\pak01_dir.vpk" set "lib=%%s"))
if defined lib set "STEAMAPPS=%lib:\\=\%\steamapps" & set "CS2=%lib:\\=\%\steamapps\common\Counter-Strike Global Offensive"
 
:: prepare OUT path
set "OUT=%~dp0CS2_crashes" & set id=tbd
if exist "%OUT%\*.zip" echo;& echo  Previously exported files are in: %OUT%
mkdir "%OUT%" >nul 2>nul  
setlocal enabledelayedexpansion
 
:: export CS2 mdmp files from Steam - Library - CS2 - Properties - Installed files - Browse > game\bin\win64
pushd "%CS2%\game\bin\win64"
echo;& echo  %CD% :
for /f "tokens=1-9 delims=_" %%A in ('dir *.mdmp /a:-D/b/oD') do if %%B_%%C neq !id! (
  set "id=%%B_%%C" & set "dmp=*!id!*.mdmp" & set "zip=%OUT%\cs2_crash_!id:_=!.zip" & echo  - !zip!
  powershell -nop -c Compress-Archive $env:dmp $env:zip -CompressionLevel Optimal -Update
  if exist "!zip!" del /f /q !dmp! >nul 2>nul
)
 
:: export CS2 dmp files from Steam\dumps
pushd "%STEAM%\dumps"
echo;& echo  %CD% :
for /f "tokens=1-9 delims=_" %%A in ('dir *cs2.exe*.dmp /a:-D/b/oD') do set C=%%C& set C=!C:~0,8!& if !C! neq !id! (
  set "id=!C!" & set "dmp=*cs2.exe*!id!*.dmp" & set "zip=%OUT%\cs2_crash_!id!.zip" & echo  - !zip!
  powershell -nop -c Compress-Archive $env:dmp $env:zip -CompressionLevel Optimal -Update
  if exist "!zip!" del /f /q !dmp! >nul 2>nul
)
 
:: done
endlocal
timeout /t -1 & exit /b
 
