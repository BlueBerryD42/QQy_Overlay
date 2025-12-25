@echo off
echo Starting PaddleOCR Server...
echo.

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Start server
python server.py

