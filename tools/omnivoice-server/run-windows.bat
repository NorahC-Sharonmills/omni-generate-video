@echo off
setlocal

cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
  echo Creating local Python environment in .venv...
  python -m venv .venv
  if errorlevel 1 exit /b 1
)

call ".venv\Scripts\activate.bat"
if errorlevel 1 exit /b 1

echo Installing Python dependencies...
python -m pip install -r requirements.txt
if errorlevel 1 exit /b 1

echo.
echo Starting OmniVoice-compatible TTS server at http://127.0.0.1:8123
echo Open another terminal to test the pipeline:
echo   cd /d D:\GitHub\omni-generate-video
echo   npm run pipeline -- output/demo-video/script.json
echo.

uvicorn server:app --host 127.0.0.1 --port 8123
