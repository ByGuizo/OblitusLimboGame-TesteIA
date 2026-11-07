@echo off
title Oblitus Limbo - Servidor local
cd /d "%~dp0"
echo ==================================================
echo    OBLITUS LIMBO - Volume I (Demo)
echo    Servidor local: http://localhost:8765
echo    Feche esta janela para encerrar o jogo.
echo ==================================================
start "" cmd /c "ping -n 3 127.0.0.1 >nul && start http://localhost:8765/index.html"
python -m http.server 8765
if errorlevel 1 py -m http.server 8765
pause
