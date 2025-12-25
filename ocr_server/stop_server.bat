@echo off
echo ========================================
echo   Stopping PaddleOCR Server
echo ========================================
echo.

REM Find process using port 8000
echo Checking for processes on port 8000...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8000 ^| findstr LISTENING') do (
    echo Found process %%a using port 8000
    echo Stopping process %%a...
    taskkill /F /PID %%a >nul 2>&1
    if errorlevel 1 (
        echo [WARNING] Failed to stop process %%a
        echo You may need to stop it manually
    ) else (
        echo [OK] Process %%a stopped
    )
)

echo.
echo Checking again...
netstat -ano | findstr :8000
if errorlevel 1 (
    echo [OK] Port 8000 is now free
) else (
    echo [WARNING] Port 8000 is still in use
    echo You may need to stop the process manually
)

echo.
pause

