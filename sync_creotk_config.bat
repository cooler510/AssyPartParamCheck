@echo off
chcp 65001 >nul
REM ==========================================================================
REM  双击运行：把本项目 creotk.dat 路径同步写入 Creo 的 config.pro
REM  实际逻辑在同目录的 sync_creotk_config.ps1
REM ==========================================================================
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_creotk_config.ps1"
echo.
pause
