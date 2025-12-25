@echo off
echo Restarting PaddleOCR Server...
echo.

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Start server with updated code
python server.py

