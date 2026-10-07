@echo off
title Golden Kids School - Full Stack Server (Live + WhatsApp Backend)
echo ========================================================
echo   Golden Kids School - Full Stack Server
echo   Node.js Backend with Meta WhatsApp Cloud API active
echo   URL: http://localhost:8000/
echo ========================================================
start "" "http://localhost:8000/"
node "%~dp0server.js" 8000
pause

