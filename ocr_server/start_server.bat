@echo off
echo ========================================
echo   PaddleOCR Server Setup
echo ========================================
echo.

REM Check if Python 3.12 is available
py -3.12 --version >nul 2>&1
if errorlevel 1 (
    REM Try regular python command
    python --version >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Python is not installed or not in PATH
        echo.
        echo Please install Python 3.12 from https://www.python.org/
        echo Make sure to check "Add Python to PATH" during installation
        echo.
        pause
        exit /b 1
    )
    REM Check if it's Python 3.12
    python -c "import sys; v=sys.version_info; exit(0 if (v.major==3 and v.minor==12) else 1)" >nul 2>&1
    if errorlevel 1 (
        echo [WARNING] Python 3.12 not found. Found:
        python --version
        echo.
        echo PaddlePaddle works best with Python 3.12
        echo If virtual environment already exists, it will be used
        echo.
        echo Press any key to continue anyway, or Ctrl+C to cancel...
        pause >nul
        echo.
    ) else (
        echo [OK] Python 3.12 found
        python --version
        echo.
    )
) else (
    echo [OK] Python 3.12 found
    py -3.12 --version
    echo.
)

REM Check if virtual environment exists
if not exist "venv\" (
    echo [1/5] Creating virtual environment with Python 3.12...
    REM Try py -3.12 first, then fallback to python
    py -3.12 -m venv venv
    if errorlevel 1 (
        echo Trying with 'python' command...
        python -m venv venv
        if errorlevel 1 (
            echo [ERROR] Failed to create virtual environment
            echo Please ensure Python 3.12 is installed and accessible
            echo You can install it from: https://www.python.org/
            echo.
            echo Or use: py -3.12 -m venv venv
            pause
            exit /b 1
        )
    )
    echo [OK] Virtual environment created
) else (
    echo [OK] Virtual environment already exists
    echo Checking Python version in virtual environment...
    venv\Scripts\python.exe --version
)
echo.

REM Activate virtual environment
echo [2/5] Activating virtual environment...
call venv\Scripts\activate.bat
if errorlevel 1 (
    echo [ERROR] Failed to activate virtual environment
    pause
    exit /b 1
)
echo [OK] Virtual environment activated
echo.

REM Upgrade pip first (with progress)
echo [3/5] Upgrading pip...
python -m pip install --upgrade pip
if errorlevel 1 (
    echo [WARNING] Failed to upgrade pip, continuing anyway...
)
echo.

REM Install PaddlePaddle and PaddleOCR
echo [4/5] Installing PaddlePaddle and PaddleOCR...
echo This is required for OCR to work...
echo Installing from PyPI...
python -m pip install --default-timeout=100 paddlepaddle paddleocr
if errorlevel 1 (
    echo [WARNING] Failed to install PaddlePaddle/PaddleOCR
    echo Trying from PaddlePaddle official source...
    python -m pip install --default-timeout=100 paddlepaddle==3.2.0 -i https://www.paddlepaddle.org.cn/packages/stable/cpu/
)

REM Install other dependencies
echo.
echo [5/5] Installing other dependencies...
echo This may take several minutes on first run (downloading ~200MB)...
echo Please be patient...
echo.

REM Try installing with progress bar and increased timeout
REM Use the activated venv's pip
python -m pip install --default-timeout=100 -r requirements.txt

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to install dependencies
    echo.
    echo Troubleshooting:
    echo 1. Check your internet connection
    echo 2. Try running manually: pip install -r requirements.txt
    echo 3. If in China/Vietnam, try using mirror:
    echo    pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
    echo.
    pause
    exit /b 1
)

echo.
echo [OK] All dependencies installed successfully!
echo.

REM Check if port 8000 is already in use
echo Checking if port 8000 is available...
netstat -ano | findstr :8000 | findstr LISTENING >nul 2>&1
if not errorlevel 1 (
    echo [WARNING] Port 8000 is already in use!
    echo.
    echo Options:
    echo 1. Stop the existing server: stop_server.bat
    echo 2. Or wait a moment and try again
    echo.
    echo Attempting to find and stop the process...
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8000 ^| findstr LISTENING') do (
        echo Stopping process %%a...
        taskkill /F /PID %%a >nul 2>&1
        if errorlevel 1 (
            echo [ERROR] Failed to stop process %%a
            echo Please run stop_server.bat or stop the process manually
            pause
            exit /b 1
        ) else (
            echo [OK] Process stopped
            timeout /t 2 /nobreak >nul
        )
    )
)

REM Start server
echo ========================================
echo   Starting PaddleOCR Server
echo ========================================
echo Server will be available at: http://127.0.0.1:8000
echo Press Ctrl+C to stop the server
echo.
python server.py

