@echo off
:: scripts/dev_local.bat
:: One-command local development startup for Windows.
:: Starts the backend against a local Ollama instance.
:: The Flutter frontend must be started separately (see step 4).

setlocal EnableDelayedExpansion

echo.
echo ╔═══════════════════════════════════════════════════╗
echo ║       Gemma Educator Agent — Local Dev            ║
echo ╚═══════════════════════════════════════════════════╝
echo.

:: ── 1. Check Ollama ────────────────────────────────────────────────────────
echo [1/4] Checking Ollama...
where ollama >nul 2>&1
if errorlevel 1 (
    echo   ERROR: Ollama not found.
    echo   Install it from https://ollama.com then re-run this script.
    pause & exit /b 1
)
echo   Ollama found.

:: ── 2. Check / create backend env ─────────────────────────────────────────
echo [2/4] Checking backend\.env...
if not exist "backend\.env" (
    if exist "backend\.env.example" (
        copy "backend\.env.example" "backend\.env" >nul
        echo   Created backend\.env from template.
        echo   IMPORTANT: Edit backend\.env and set OLLAMA_MODEL to match 'ollama list'.
        notepad "backend\.env"
    ) else (
        echo   WARNING: backend\.env.example not found. Create backend\.env manually.
    )
) else (
    echo   backend\.env already exists.
)

:: ── 3. Read OLLAMA_MODEL from env file ────────────────────────────────────
set "OLLAMA_MODEL=gemma4:4b"
for /f "tokens=1,2 delims==" %%a in (backend\.env) do (
    if "%%a"=="OLLAMA_MODEL" set "OLLAMA_MODEL=%%b"
)
echo [3/4] Using Ollama model: %OLLAMA_MODEL%
echo   Checking if model is available...
ollama list | findstr /I "%OLLAMA_MODEL%" >nul 2>&1
if errorlevel 1 (
    echo   Model not found locally. Pulling %OLLAMA_MODEL%...
    echo   This may take several minutes on first run.
    ollama pull %OLLAMA_MODEL%
    if errorlevel 1 (
        echo   ERROR: Could not pull model. Check model name in backend\.env.
        pause & exit /b 1
    )
)
echo   Model ready.

:: ── 4. Start backend ───────────────────────────────────────────────────────
echo [4/4] Starting backend on http://localhost:7860 ...
echo   (Press Ctrl+C in this window to stop the backend)
echo.
echo ─────────────────────────────────────────────────────
echo  Next step: open a NEW terminal and run:
echo.
echo    cd frontend
echo    flutter run -d web-server --web-port 8080
echo.
echo  Then open http://localhost:8080 in your browser.
echo ─────────────────────────────────────────────────────
echo.

cd backend
pip install -r requirements.txt -q
uvicorn main:app --reload --port 7860
