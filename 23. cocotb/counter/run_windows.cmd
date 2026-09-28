@echo off
"%~dp0..\.venv-win\Scripts\python.exe" "%~dp0run.py"
exit /b %errorlevel%
