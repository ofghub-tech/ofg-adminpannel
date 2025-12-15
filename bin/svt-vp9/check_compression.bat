@echo off
setlocal enabledelayedexpansion

:: ========================================================
:: 1. SETUP
:: ========================================================
cd /d "%~dp0"
set "input_folder=E:\OfgHub\admin_dashboard\uploads"
set "output_folder=E:\OfgHub\admin_dashboard\processed"

echo [START] OFG Connects Compression Engine
echo [INFO]  Scanning folder: %input_folder%
echo.

if not exist "%output_folder%" mkdir "%output_folder%"

:: ========================================================
:: 2. MAIN LOOP (Safe Mode)
:: ========================================================
:: We only do ONE thing here: Call the function.
:: This prevents the "unexpected at this time" crash.

for %%F in ("%input_folder%\*.mp4") do (
    call :ProcessVideo "%%F"
)

echo.
echo ========================================================
echo      DONE.
echo ========================================================
pause
exit /b

:: ========================================================
:: 3. THE WORKER FUNCTION (Logic goes here)
:: ========================================================
:ProcessVideo
set "FULL_PATH=%~1"
set "FILENAME=%~n1"

echo --------------------------------------------------------
echo [Processing] %FILENAME%
echo --------------------------------------------------------

:: Clean up temp files
if exist "temp_audio.ogg" del "temp_audio.ogg" >nul 2>nul
if exist "temp_video.webm" del "temp_video.webm" >nul 2>nul

:: STEP 1: EXTRACT AUDIO
echo    [1/3] Extracting Audio...
ffmpeg -y -v error -i "%FULL_PATH%" -vn -c:a libvorbis -q:a 3 "temp_audio.ogg"

:: STEP 2: COMPRESS VIDEO (No Audio)
echo    [2/3] Compressing Video...
ffmpeg -y -v error -stats -i "%FULL_PATH%" -an -vf "scale=-2:720" -c:v libvpx-vp9 -b:v 600k -minrate 300k -maxrate 900k -crf 36 "temp_video.webm"

:: STEP 3: MERGE
echo    [3/3] Merging...

if exist "temp_audio.ogg" (
    :: Force Map: Video(0) + Audio(1)
    ffmpeg -y -v error -i "temp_video.webm" -i "temp_audio.ogg" -map 0:v -map 1:a -c copy "%output_folder%\%FILENAME%_mobile.webm"
    echo    [SUCCESS] Saved with Audio.
) else (
    echo    [WARNING] No Audio found. Saving silent video.
    copy "temp_video.webm" "%output_folder%\%FILENAME%_mobile.webm" >nul
)

exit /b