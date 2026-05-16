@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ========================================
:: XDU 自动连网 - 开机自启管理工具
:: ========================================
:: 用法：双击运行，按菜单选择即可
:: ========================================

set "SCRIPT_PATH=%~dp0link_XDU.bat"
set "AUTOSTART_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "AUTOSTART_NAME=XDU_AutoConnect"

title XDU 开机自启管理

:menu
cls
echo ========================================
echo     XDU 自动连网 - 开机自启管理
echo ========================================
echo.
echo  1. 安装 — 开机自动运行 link_XDU.bat
echo  2. 卸载 — 取消开机自启
echo  3. 查看 — 当前开机自启状态
echo  4. 退出
echo.
echo ========================================

set "CHOICE="
set /p CHOICE=请输入选项（1/2/3/4）：

if "%CHOICE%"=="1" goto install
if "%CHOICE%"=="2" goto uninstall
if "%CHOICE%"=="3" goto status
if "%CHOICE%"=="4" exit /b 0

echo 无效输入，请重新选择...
timeout /t 2 /nobreak >nul
goto menu

:install
echo.
echo [操作] 正在安装开机自启...

:: 检查 link_XDU.bat 是否存在
if not exist "%SCRIPT_PATH%" (
    echo [失败] 找不到 %SCRIPT_PATH%
    echo        请将 setup_autostart.bat 与 link_XDU.bat 放在同一目录
    pause >nul
    goto menu
)

:: 写入注册表 Run 键
reg add "%AUTOSTART_KEY%" /v "%AUTOSTART_NAME%" /t REG_SZ /d "%SCRIPT_PATH%" /f >nul

if !errorlevel! equ 0 (
    echo [成功] 开机自启已安装！
    echo        下次开机时会自动运行 link_XDU.bat
    echo.
    echo        当前已添加到系统注册表：
    echo        %AUTOSTART_KEY%\%AUTOSTART_NAME%
) else (
    echo [失败] 安装失败，请以管理员身份运行本脚本
)

pause >nul
goto menu

:uninstall
echo.
echo [操作] 正在卸载开机自启...

reg delete "%AUTOSTART_KEY%" /v "%AUTOSTART_NAME%" /f >nul 2>&1

if !errorlevel! equ 0 (
    echo [成功] 开机自启已卸载！
) else (
    echo [信息] 之前未安装开机自启，无需卸载
)

pause >nul
goto menu

:status
echo.
echo [信息] 正在查询开机自启状态...

reg query "%AUTOSTART_KEY%" /v "%AUTOSTART_NAME%" >nul 2>&1

if !errorlevel! equ 0 (
    echo [状态] ✅ 已安装开机自启
    for /f "tokens=2*" %%a in ('reg query "%AUTOSTART_KEY%" /v "%AUTOSTART_NAME%" 2^>nul ^| findstr "%AUTOSTART_NAME%"') do (
        echo [路径] %%b
    )
) else (
    echo [状态] ❌ 未安装开机自启
)

pause >nul
goto menu
