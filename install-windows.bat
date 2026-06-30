@echo off
setlocal EnableExtensions DisableDelayedExpansion

cd /d "%~dp0"

echo ============================================================
echo  Omni Generate Video - Windows setup
echo ============================================================
echo.

if not exist "package.json" (
    echo [ERROR] package.json was not found next to this installer.
    goto :fail
)

where winget.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] winget is required but was not found.
    echo Install or update "App Installer" from Microsoft Store, then run this file again.
    goto :fail
)

call :refresh_path

call :ensure_node
if errorlevel 1 goto :fail

where ffmpeg.exe >nul 2>&1
if errorlevel 1 goto :install_ffmpeg
where ffprobe.exe >nul 2>&1
if errorlevel 1 goto :install_ffmpeg
echo [OK] FFmpeg and ffprobe are available.
goto :ffmpeg_done

:install_ffmpeg
call :winget_install "Gyan.FFmpeg" "FFmpeg"
if errorlevel 1 goto :fail
call :refresh_path
where ffmpeg.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] ffmpeg is still unavailable after installation.
    echo Close this window, open a new terminal, and run this file again.
    goto :fail
)
where ffprobe.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] ffprobe is still unavailable after installation.
    echo Close this window, open a new terminal, and run this file again.
    goto :fail
)
echo [OK] FFmpeg and ffprobe are available.

:ffmpeg_done
call :chrome_available
if not errorlevel 1 (
    echo [OK] Google Chrome is available.
    goto :chrome_done
)
call :winget_install "Google.Chrome" "Google Chrome"
if errorlevel 1 goto :fail

:chrome_done
if not exist ".env.local" (
    echo [CREATE] .env.local
    >".env.local" echo TTS_PROVIDER=omnivoice
    >>".env.local" echo OMNIVOICE_ENDPOINT=http://127.0.0.1:8123
    >>".env.local" echo TTS_CONCURRENCY=1
) else (
    echo [OK] Keeping the existing .env.local file.
)

echo [INSTALL] Project npm dependencies...
call npm install
if errorlevel 1 goto :fail

echo [CHECK] TypeScript...
call npm run typecheck
if errorlevel 1 goto :fail

echo [CHECK] Unit tests...
call npm test
if errorlevel 1 goto :fail

echo.
echo ============================================================
echo  Setup completed successfully.
echo ============================================================
echo.
echo IMPORTANT: OmniVoice is an external service and is not included in
echo this repository. Start a compatible server at http://127.0.0.1:8123
echo before running the video pipeline.
echo.
echo Run a video with:
echo   npm run pipeline -- output\YOUR-RUN\script.json
echo.
pause
exit /b 0

:ensure_node
call :check_node
if not errorlevel 1 (
    call :check_npm
    if not errorlevel 1 (
        echo [OK] Node.js 22 or newer and npm are available.
        exit /b 0
    )
)

echo [INSTALL] Node.js LTS 22 or newer...
winget list --id "OpenJS.NodeJS.LTS" --exact --accept-source-agreements >nul 2>&1
if "%errorlevel%"=="0" (
    winget upgrade --id "OpenJS.NodeJS.LTS" --exact --silent --accept-package-agreements --accept-source-agreements
) else (
    winget install --id "OpenJS.NodeJS.LTS" --exact --silent --accept-package-agreements --accept-source-agreements
)
if not "%errorlevel%"=="0" (
    echo [ERROR] Could not install or upgrade Node.js.
    exit /b 1
)
call :refresh_path

call :check_node
if errorlevel 1 (
    echo [ERROR] This project requires Node.js 22 or newer.
    node --version 2>nul
    exit /b 1
)
call :check_npm
if errorlevel 1 (
    echo [ERROR] npm was not found after installing Node.js.
    exit /b 1
)
echo [OK] Node.js and npm are available.
exit /b 0

:check_node
where node.exe >nul 2>&1
if errorlevel 1 exit /b 1
set "NODE_MAJOR="
for /f "tokens=1 delims=." %%V in ('node --version 2^>nul') do set "NODE_MAJOR=%%V"
set "NODE_MAJOR=%NODE_MAJOR:v=%"
if not defined NODE_MAJOR exit /b 1
for /f "delims=0123456789" %%A in ("%NODE_MAJOR%") do exit /b 1
if %NODE_MAJOR% LSS 22 exit /b 1
exit /b 0

:check_npm
where npm.cmd >nul 2>&1
if not errorlevel 1 exit /b 0
where npm.exe >nul 2>&1
if not errorlevel 1 exit /b 0
exit /b 1

:winget_install
winget list --id "%~1" --exact --accept-source-agreements >nul 2>&1
if "%errorlevel%"=="0" (
    echo [OK] %~2 is already installed.
    exit /b 0
)
echo [INSTALL] %~2...
winget install --id "%~1" --exact --silent --accept-package-agreements --accept-source-agreements
if not "%errorlevel%"=="0" (
    echo [ERROR] Could not install %~2.
    exit /b 1
)
exit /b 0

:chrome_available
where chrome.exe >nul 2>&1
if not errorlevel 1 exit /b 0
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" exit /b 0
if defined ProgramFiles(x86) if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" exit /b 0
if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" exit /b 0
exit /b 1

:refresh_path
for /f "usebackq delims=" %%P in (`powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"`) do set "PATH=%%P"
exit /b 0

:fail
echo.
echo Setup did not complete. Review the error above, then run this file again.
pause
exit /b 1
