@echo off
setlocal

set "REPO_ROOT=%~dp0"
set "PROFILE_DIR=%REPO_ROOT%.chrome-profile"
set "BROWSER_EXE="

if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
    set "BROWSER_EXE=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
) else if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" (
    set "BROWSER_EXE=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
) else if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" (
    set "BROWSER_EXE=%LocalAppData%\Google\Chrome\Application\chrome.exe"
) else if exist "%ProgramFiles%\Chromium\Application\chrome.exe" (
    set "BROWSER_EXE=%ProgramFiles%\Chromium\Application\chrome.exe"
) else if exist "%LocalAppData%\Chromium\Application\chrome.exe" (
    set "BROWSER_EXE=%LocalAppData%\Chromium\Application\chrome.exe"
)

if not defined BROWSER_EXE (
    echo [ERROR] Chrome or Chromium was not found.
    echo Install Chrome/Chromium, then run this file again.
    exit /b 1
)

if not exist "%PROFILE_DIR%" (
    mkdir "%PROFILE_DIR%"
    if errorlevel 1 (
        echo [ERROR] Could not create profile directory:
        echo %PROFILE_DIR%
        exit /b 1
    )
)

echo Browser: %BROWSER_EXE%
echo Profile: %PROFILE_DIR%
echo.
echo Opening the dedicated repository Chrome profile...

start "" "%BROWSER_EXE%" --user-data-dir="%PROFILE_DIR%" --profile-directory="Default" --no-first-run

endlocal
