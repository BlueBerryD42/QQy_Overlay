@echo off
echo ========================================
echo   Installing PaddlePaddle
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed
    pause
    exit /b 1
)

REM Activate virtual environment if exists
if exist "venv\" (
    call venv\Scripts\activate.bat
)

echo Installing PaddlePaddle CPU version...
echo This is required for PaddleOCR...
echo.

REM Try installing from PyPI first
python -m pip install paddlepaddle==2.5.2

if errorlevel 1 (
    echo.
    echo [WARNING] Failed to install from PyPI
    echo Trying alternative installation method...
    echo.
    echo You may need to install manually from:
    echo https://www.paddlepaddle.org.cn/install/quick?docurl=/documentation/docs/en/install/pip/windows-pip_en.html
    echo.
    pause
    exit /b 1
)

echo.
echo [OK] PaddlePaddle installed successfully!
echo.
pause

