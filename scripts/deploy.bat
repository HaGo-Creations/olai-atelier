@echo off
:: scripts/deploy.bat
:: Commits all changes, pushes to GitHub main, and pushes
:: the backend/ subtree to the Hugging Face Space.
::
:: Usage:
::   scripts\deploy.bat "your commit message"
::   scripts\deploy.bat           (prompts for message)
::
:: Requirements:
::   git, huggingface-cli (pip install huggingface_hub[cli])
::   HF token set via:  huggingface-cli login
::        OR:           set HF_TOKEN=hf_xxxx

setlocal EnableDelayedExpansion

:: ── Commit message ────────────────────────────────────────────────────────
set "MSG=%~1"
if "%MSG%"=="" (
    set /p MSG="Commit message: "
)
if "%MSG%"=="" set "MSG=Update"

:: ── Config ────────────────────────────────────────────────────────────────
set "GITHUB_REMOTE=origin"
set "GITHUB_BRANCH=main"
set "HF_SPACE=hago-creations/gemma-educator"
set "HF_REMOTE=https://huggingface.co/spaces/%HF_SPACE%"

echo.
echo ============================================================
echo  Deploying: %MSG%
echo ============================================================
echo.

:: ── Step 1: Stage and commit everything ──────────────────────────────────
echo [1/4] Staging all changes...
git add -A
git status --short
echo.
git diff --cached --quiet
if %errorlevel%==0 (
    echo   Nothing to commit — working tree clean.
) else (
    git commit -m "%MSG%"
    if errorlevel 1 ( echo   Commit failed. & pause & exit /b 1 )
    echo   Committed.
)

:: ── Step 2: Merge worktree branch into main ───────────────────────────────
echo.
echo [2/4] Merging to %GITHUB_BRANCH%...
set "CURRENT_BRANCH="
for /f %%b in ('git rev-parse --abbrev-ref HEAD') do set "CURRENT_BRANCH=%%b"

if "%CURRENT_BRANCH%"=="%GITHUB_BRANCH%" (
    echo   Already on %GITHUB_BRANCH%.
) else (
    git checkout %GITHUB_BRANCH%
    if errorlevel 1 ( echo   Checkout failed. & pause & exit /b 1 )
    git merge --no-ff "%CURRENT_BRANCH%" -m "Merge %CURRENT_BRANCH% into %GITHUB_BRANCH%"
    if errorlevel 1 ( echo   Merge failed. & pause & exit /b 1 )
    echo   Merged %CURRENT_BRANCH% into %GITHUB_BRANCH%.
)

:: ── Step 3: Push to GitHub ────────────────────────────────────────────────
echo.
echo [3/4] Pushing to GitHub (%GITHUB_REMOTE%/%GITHUB_BRANCH%)...
git push %GITHUB_REMOTE% %GITHUB_BRANCH%
if errorlevel 1 ( echo   GitHub push failed. & pause & exit /b 1 )
echo   GitHub push successful.
echo   GitHub Actions will now build and deploy the Flutter web app.

:: ── Step 4: Push backend to Hugging Face Space ───────────────────────────
echo.
echo [4/4] Pushing backend/ to Hugging Face Space...

:: Add the HF remote if it doesn't exist
git remote get-url hf >nul 2>&1
if errorlevel 1 (
    git remote add hf %HF_REMOTE%
    echo   Added HF remote: %HF_REMOTE%
)

:: Push only the backend/ subdirectory to HF Space main branch
git subtree push --prefix=backend hf main
if errorlevel 1 (
    echo.
    echo   Subtree push failed. Trying force-split approach...
    git push hf `git subtree split --prefix=backend %GITHUB_BRANCH%`:main --force
    if errorlevel 1 ( echo   HF push failed. Check HF_TOKEN / login. & pause & exit /b 1 )
)
echo   Hugging Face push successful.

echo.
echo ============================================================
echo  Deployment complete.
echo  GitHub  : https://github.com/HaGo-Creations/gemma4-edtech-ai-assistant
echo  HF Space: https://huggingface.co/spaces/%HF_SPACE%
echo  Live app: https://HaGo-Creations.github.io/gemma4-edtech-ai-assistant
echo ============================================================
echo.
pause
