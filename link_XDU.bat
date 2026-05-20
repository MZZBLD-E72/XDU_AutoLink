@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ========================================
:: XDU 自动连网脚本（增强版 v3）
:: ========================================

set "CONN_NAME=XDU"
set "MAX_RETRIES=10"
set "RETRY_DELAY=3"
set "LOG_FILE=%~dp0link_XDU.log"

:: ===== 加载账号密码（从独立的 config.bat 读取，不硬编码） =====
if exist "%~dp0config.bat" (
    call "%~dp0config.bat"
) else (
    echo ==============================
    echo   [错误] 找不到 config.bat！
    echo   请将 config.bat.example 复制为 config.bat
    echo   并在其中填入你的账号和密码
    echo ==============================
    pause >nul
    exit /b 1
)

echo ==============================
echo   XDU 自动连网脚本
echo   开始时间：%date% %time%
echo ==============================

echo [%date% %time%] === 开始连网 === >> "%LOG_FILE%"

:: ===== 第一步：检查当前连接状态 =====
echo 正在检查当前网络连接状态...
rasdial "%CONN_NAME%" 2>&1 | findstr /i "已连接" >nul
if !errorlevel! equ 0 (
    echo [信息] "%CONN_NAME%" 已经处于连接状态，跳过拨号
    echo [%date% %time%] 已处于连接状态，跳过拨号 >> "%LOG_FILE%"
    goto :success
)

echo [信息] 当前未连接 "%CONN_NAME%"，准备拨号...

set RETRY_COUNT=0

:retry
set /a RETRY_COUNT+=1

:: 先确保断开旧连接（避免残留）
rasdial "%CONN_NAME%" /d >nul 2>&1

echo [%date% %time%] 第 !RETRY_COUNT! 次尝试连接...
rasdial "%CONN_NAME%" %ACCOUNT% %PASSWORD%
set "LAST_ERROR=!errorlevel!"

:: 错误码说明（常见的）：
::   0   - 成功
::   691 - 用户名或密码错误（无需重试）
::   633 - 调制解调器正在使用中
::   623 - 电话簿项不存在
::   720 - PPP 协议协商失败
::   732 - PPP 协议错误

if !LAST_ERROR! equ 0 (
    echo 连接成功！
    echo [%date% %time%] 连接成功（错误码=0） >> "%LOG_FILE%"
    goto :success
)

if !LAST_ERROR! equ 691 (
    echo [失败] 错误码 691：用户名或密码错误，请检查 config.bat 中的配置
    echo [%date% %time%] 错误691：用户名或密码错误，跳过重试 >> "%LOG_FILE%"
    goto :failed
)

if !LAST_ERROR! equ 623 (
    echo [失败] 错误码 623：找不到连接项 "%CONN_NAME%"
    echo [%date% %time%] 错误623：找不到连接项 "%CONN_NAME%" >> "%LOG_FILE%"
    goto :failed
)

if !LAST_ERROR! equ 633 (
    echo [提示] 错误码 633：调制解调器正在使用中，等待释放...
    echo [%date% %time%] 错误633：调制解调器正在使用中 >> "%LOG_FILE%"
)

:: 有时 rasdial 返回非0但实际已连接，做二次确认
rasdial "%CONN_NAME%" 2>&1 | findstr /i "已连接" >nul
if !errorlevel! equ 0 (
    echo [信息] 虽然返回错误码 !LAST_ERROR!，但检测到已连接，视为成功
    echo [%date% %time%] 返回错误码!LAST_ERROR!但检测到已连接，视为成功 >> "%LOG_FILE%"
    goto :success
)

:: 达到最大重试次数则退出
if !RETRY_COUNT! geq !MAX_RETRIES! (
    echo [失败] 已重试 !MAX_RETRIES! 次，仍无法连接（最近错误码=!LAST_ERROR!），放弃
    echo [%date% %time%] 达到最大重试次数，放弃连接（最近错误码=!LAST_ERROR!） >> "%LOG_FILE%"
    goto :failed
)

echo 连接失败（错误码 !LAST_ERROR!），!RETRY_DELAY! 秒后重试...
timeout /t !RETRY_DELAY! /nobreak >nul
goto retry

:success
echo ==============================
echo   已成功连接到 "%CONN_NAME%"
echo   时间：%date% %time%
echo ==============================
echo [%date% %time%] 连接结束（成功） >> "%LOG_FILE%"

:: 连接成功后自动关闭窗口（开机自启时不会留下黑框）
exit /b 0

:failed
echo ==============================
echo   连接 "%CONN_NAME%" 失败
echo   请检查网络或配置后重试
echo   日志已保存至：%LOG_FILE%
echo ==============================
echo [%date% %time%] 连接结束（失败） >> "%LOG_FILE%"
pause >nul
exit /b 1
