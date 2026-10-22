@echo off
title Shadhin Jatra - Laravel API Server
color 0A
cd /d "%~dp0"
echo ========================================================
echo        SHADHIN JATRA - LARAVEL API BACKEND SERVER
echo ========================================================
echo.
echo Starting server at http://127.0.0.1:8000 ...
echo (Do not close this window while using the app)
echo.
php artisan serve --host=0.0.0.0 --port=8000
pause
