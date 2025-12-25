@echo off
echo ========================================
echo   Installing PaddlePaddle for Windows
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
    echo Activating virtual environment...
    call venv\Scripts\activate.bat
)

echo.
echo Trying to install PaddlePaddle from Baidu mirror...
echo This may take a few minutes...
echo.

REM Try installing from Baidu mirror (Chinese mirror, often faster and more reliable)
python -m pip install paddlepaddle -i https://mirror.baidu.com/pypi/simple

if errorlevel 1 (
    echo.
    echo [WARNING] Failed to install from Baidu mirror
    echo Trying alternative: Tsinghua mirror...
    python -m pip install paddlepaddle -i https://pypi.tuna.tsinghua.edu.cn/simple
)

if errorlevel 1 (
    echo.
    echo [WARNING] Failed to install from Tsinghua mirror
    echo Trying official PyPI (may not work on Windows)...
    python -m pip install paddlepaddle
)

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to install PaddlePaddle from all sources
    echo.
    echo PaddlePaddle may not be available for Windows via pip.
    echo You may need to:
    echo 1. Use PaddleOCR 2.x which may have different dependencies
    echo 2. Install PaddlePaddle from source (complex)
    echo 3. Use a different OCR solution
    echo.
    pause
    exit /b 1
)

echo.
echo [OK] PaddlePaddle installed successfully!
echo.
echo Verifying installation...
python -c "import paddle; print('PaddlePaddle version:', paddle.__version__)"
echo.
pause

