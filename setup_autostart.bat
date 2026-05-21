@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ============================================================
:: XDU 自动连网 - 自启管理工具（计划任务版）
:: 功能：
::   1) 用户登录时触发（link_XDU.bat startup）
::   2) 睡眠唤醒时触发（link_XDU.bat wake）
::   3) 注册表 Run 开机启动（后备）
:: ============================================================

set "SCRIPT_PATH=%~dp0link_XDU.bat"
set "TASK_NAME=XDU_AutoConnect"
set "TASK_STARTUP=XDU_AutoConnect_Startup"
set "TASK_WAKE=XDU_AutoConnect_Wake"
set "RUN_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "RUN_NAME=XDU_AutoConnect"

title XDU 自动连网 - 自启管理（增强版）

:menu
cls
echo ============================================================
echo     XDU 自动连网 - 自启管理（计划任务版）
echo ============================================================
echo.
echo  当前安装状态：
call :check_status
echo.
echo ────────────────────────────
echo  1. 安装（推荐）— 登录时 + 唤醒时自动拨号
echo  2. 仅安装开机触发（无需管理员）
echo  3. 卸载所有自启
echo  4. 查看当前状态
echo  5. 退出
echo.
echo ============================================================

set "CHOICE="
set /p CHOICE=请输入选项（1/2/3/4/5）：

if "%CHOICE%"=="1" goto install_full
if "%CHOICE%"=="2" goto install_simple
if "%CHOICE%"=="3" goto uninstall
if "%CHOICE%"=="4" goto status
if "%CHOICE%"=="5" exit /b 0

echo 无效输入，请重新选择...
timeout /t 2 /nobreak >nul
goto menu

:: ── 完整安装（需管理员权限，含唤醒触发） ──
:install_full
echo.
echo [操作] 正在安装所有自启方式...
if not exist "%SCRIPT_PATH%" (
    echo [失败] 找不到 link_XDU.bat
    pause >nul
    goto menu
)

:: 1) 注册表 Run（后备）
reg add "%RUN_KEY%" /v "%RUN_NAME%" /t REG_SZ /d "%SCRIPT_PATH%" /f >nul
if !errorlevel! equ 0 ( echo [OK] 注册表 Run 已安装 ) else ( echo [--] 注册表 Run 安装失败（非严重） )

:: 2) 用户登录时触发
schtasks /create /tn "%TASK_STARTUP%" /tr "\"%SCRIPT_PATH%\" startup" /sc onlogon /ru "%USERNAME%" /it /f >nul 2>&1
if !errorlevel! equ 0 ( echo [OK] 计划任务（登录触发）已安装 ) else ( echo [--] 计划任务（登录触发）安装失败 )

:: 3) 睡眠唤醒触发（需管理员）
schtasks /create /tn "%TASK_WAKE%" /tr "\"%SCRIPT_PATH%\" wake" /sc onevent /ec System /mo "*[System[EventID=1]]" /ru "%USERNAME%" /f >nul 2>&1
if !errorlevel! equ 0 (
    echo [OK] 计划任务（唤醒触发）已安装
) else (
    echo [信息] 唤醒触发需要管理员权限
    echo         请右键选择「以管理员身份运行」本脚本后再试
)

echo.
echo [完成] 自启安装完毕
pause >nul
goto menu

:: ── 简单安装（无需管理员，仅登录触发） ──
:install_simple
echo.
echo [操作] 正在安装登录触发...
if not exist "%SCRIPT_PATH%" (
    echo [失败] 找不到 link_XDU.bat
    pause >nul
    goto menu
)

:: 1) 注册表 Run
reg add "%RUN_KEY%" /v "%RUN_NAME%" /t REG_SZ /d "%SCRIPT_PATH%" /f >nul
if !errorlevel! equ 0 ( echo [OK] 注册表 Run 已安装 ) else ( echo [--] 注册表 Run 安装失败 )

:: 2) 登录触发
schtasks /create /tn "%TASK_STARTUP%" /tr "\"%SCRIPT_PATH%\" startup" /sc onlogon /ru "%USERNAME%" /it /f >nul 2>&1
if !errorlevel! equ 0 ( echo [OK] 计划任务（登录触发）已安装 ) else ( echo [--] 计划任务（登录触发）安装失败 )

echo.
echo [完成] 登录自启安装完毕
echo   注意：睡眠唤醒后不会自动拨号
echo   如需唤醒自启，请以管理员运行并选选项 1
pause >nul
goto menu

:: ── 完全卸载 ──
:uninstall
echo.
echo [操作] 正在卸载所有自启...

reg delete "%RUN_KEY%" /v "%RUN_NAME%" /f >nul 2>&1
if !errorlevel! equ 0 ( echo [OK] 注册表 Run 已卸载 ) else ( echo [--] 注册表 Run 未安装 )

schtasks /delete /tn "%TASK_STARTUP%" /f >nul 2>&1
if !errorlevel! equ 0 ( echo [OK] 计划任务（登录触发）已卸载 ) else ( echo [--] 计划任务（登录触发）未安装 )

schtasks /delete /tn "%TASK_WAKE%" /f >nul 2>&1
if !errorlevel! equ 0 ( echo [OK] 计划任务（唤醒触发）已卸载 ) else ( echo [--] 计划任务（唤醒触发）未安装 )

echo.
echo [完成] 所有自启已清除
pause >nul
goto menu

:: ── 查看状态 ──
:status
cls
echo ============================================================
echo   XDU 自动连网 - 自启状态详情
echo ============================================================
call :check_status
echo.
echo ── 计划任务状态 ──
schtasks /query /tn "%TASK_STARTUP%" /fo LIST /v 2>nul | findstr /i "任务名 状态 下次运行 任务运行" >nul
if !errorlevel! equ 0 (
    echo.
    schtasks /query /tn "%TASK_STARTUP%" /fo LIST /v 2>nul | findstr /i "任务名 状态 下次运行 任务运行"
) else (
    echo [登录触发] 未安装
)
echo.
schtasks /query /tn "%TASK_WAKE%" /fo LIST /v 2>nul | findstr /i "任务名 状态 下次运行 任务运行" >nul
if !errorlevel! equ 0 (
    schtasks /query /tn "%TASK_WAKE%" /fo LIST /v 2>nul | findstr /i "任务名 状态 下次运行 任务运行"
) else (
    echo [唤醒触发] 未安装
)

echo.
pause >nul
goto menu

:: ── 检查状态（子函数） ──
:check_status
reg query "%RUN_KEY%" /v "%RUN_NAME%" >nul 2>&1
if !errorlevel! equ 0 ( echo   注册表 Run:   ✅ 已安装 ) else ( echo   注册表 Run:   ❌ 未安装 )

schtasks /query /tn "%TASK_STARTUP%" >nul 2>&1
if !errorlevel! equ 0 ( echo   登录触发:     ✅ 已安装 ) else ( echo   登录触发:     ❌ 未安装 )

schtasks /query /tn "%TASK_WAKE%" >nul 2>&1
if !errorlevel! equ 0 ( echo   唤醒触发:     ✅ 已安装 ) else ( echo   唤醒触发:     ❌ 未安装 )
exit /b
