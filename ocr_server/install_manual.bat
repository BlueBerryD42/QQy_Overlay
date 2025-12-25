@echo off
echo ========================================
echo   Manual Installation Guide
echo ========================================
echo.
echo If automatic installation is stuck, follow these steps:
echo.

echo Step 1: Activate virtual environment
echo   venv\Scripts\activate.bat
echo.

echo Step 2: Upgrade pip
echo   python -m pip install --upgrade pip
echo.

echo Step 3: Install dependencies one by one (to see progress)
echo   pip install fastapi
echo   pip install uvicorn[standard]
echo   pip install python-multipart
echo   pip install pillow
echo   pip install numpy
echo   pip install opencv-python
echo   pip install paddleocr
echo.

echo Step 4: Start server
echo   python server.py
echo.

echo ========================================
echo   Alternative: Use Chinese Mirror (Faster)
echo ========================================
echo If you're in China/Vietnam, use this for faster download:
echo.
echo   pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
echo.
pause

