@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ============================================================
:: XDU 自动连网脚本（增强版 v4）
:: 用法：
::   link_XDU.bat            — 手动双击运行
::   link_XDU.bat startup    — 开机时由计划任务触发
::   link_XDU.bat wake       — 睡眠唤醒时由计划任务触发
:: ============================================================

set "CONN_NAME=XDU"
set "MAX_RETRIES=5"
set "RETRY_DELAY=3"
set "LOG_FILE=%~dp0link_XDU.log"

:: ── 参数判断：触发来源 ──
set "TRIGGER_DESC=手动触发"
if /i "%~1"=="startup"  set "TRIGGER_DESC=系统开机触发"
if /i "%~1"=="wake"     set "TRIGGER_DESC=系统唤醒触发"

:: ── 加载 config.bat ──
if exist "%~dp0config.bat" (
    call "%~dp0config.bat"
) else (
    echo [错误] 找不到 config.bat！
    echo   请将 config.bat.example 复制为 config.bat 并填入账号密码
    pause >nul
    exit /b 1
)

:: ── 获取标准化时间戳（不依赖系统区域格式） ──
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value 2^>nul') do set "DT=%%I"

if defined DT (
    set "LOG_DATE=!DT:~0,4!/!DT:~4,2!/!DT:~6,2!"
    set "LOG_TIME=!DT:~8,2!:!DT:~10,2!:!DT:~12,2!"
    set /a START_H=1!DT:~8,2! - 100
    set /a START_M=1!DT:~10,2! - 100
    set /a START_S=1!DT:~12,2! - 100
) else (
    :: 后备方案（基于 date/time 变量）
    set "LOG_DATE=%date:~0,4%/%date:~5,2%/%date:~8,2%"
    set "LOG_TIME=%time:~0,2%:%time:~3,2%:%time:~6,2%"
    set /a START_H=100%time:~0,2% %% 100
    set /a START_M=1%time:~3,2% - 100
    set /a START_S=1%time:~6,2% - 100
)

:: ── 结果变量 ──
set "RESULT_DETAIL="
set "RESULT_STATUS="
set "NEED_PAUSE=0"

:: ── 检查连接状态 ──
rasdial "%CONN_NAME%" 2>&1 | findstr /i "已连接" >nul
if !errorlevel! equ 0 (
    set "RESULT_DETAIL=无需拨号，已处于连接状态"
    set "RESULT_STATUS=已连接"
    goto :write_log
)

set "RETRY_COUNT=0"

:retry
set /a RETRY_COUNT+=1

:: 断开旧连接
rasdial "%CONN_NAME%" /d >nul 2>&1

rasdial "%CONN_NAME%" %ACCOUNT% %PASSWORD%
set "LAST_ERROR=!errorlevel!"

if !LAST_ERROR! equ 0 (
    set "RESULT_DETAIL=第 !RETRY_COUNT! 次拨号成功"
    set "RESULT_STATUS=成功"
    goto :write_log
)

if !LAST_ERROR! equ 691 (
    set "RESULT_DETAIL=错误691（用户名或密码错误），停止重试"
    set "RESULT_STATUS=失败"
    set "NEED_PAUSE=1"
    goto :write_log
)

if !LAST_ERROR! equ 623 (
    set "RESULT_DETAIL=错误623（找不到连接项 %CONN_NAME%），停止重试"
    set "RESULT_STATUS=失败"
    set "NEED_PAUSE=1"
    goto :write_log
)

:: 二次确认（拨号返回非0但实际可能已连上）
rasdial "%CONN_NAME%" 2>&1 | findstr /i "已连接" >nul
if !errorlevel! equ 0 (
    set "RESULT_DETAIL=错误码!LAST_ERROR!，但检测到已连接"
    set "RESULT_STATUS=成功"
    goto :write_log
)

:: 达到最大重试次数
if !RETRY_COUNT! geq !MAX_RETRIES! (
    set "RESULT_DETAIL=重试 !MAX_RETRIES! 次均失败（最近错误码=!LAST_ERROR!），放弃"
    set "RESULT_STATUS=失败"
    set "NEED_PAUSE=1"
    goto :write_log
)

timeout /t !RETRY_DELAY! /nobreak >nul
goto retry

:: ── 写入日志（最新在最前） ──
:write_log
:: 计算耗时
if defined DT (
    set /a END_H=1!DT:~8,2! - 100
    set /a END_M=1!DT:~10,2! - 100
    set /a END_S=1!DT:~12,2! - 100
) else (
    set /a END_H=100%time:~0,2% %% 100
    set /a END_M=1%time:~3,2% - 100
    set /a END_S=1%time:~6,2% - 100
)
set /a ELAPSED= (END_H*3600+END_M*60+END_S) - (START_H*3600+START_M*60+START_S)
if !ELAPSED! lss 0 set /a ELAPSED+=86400

:: 写新日志（最新在最前）：先建临时文件，新内容 + 旧内容
set "TEMP_LOG=%TEMP%\link_XDU_tmp.log"

(
    echo ============================================================
    echo  [%LOG_DATE% %LOG_TIME%] ^> !TRIGGER_DESC!
    echo   检查状态 ... !RESULT_DETAIL!
    echo   └── [!RESULT_STATUS!] 耗时 !ELAPSED! 秒
    echo.
    type "%LOG_FILE%" 2>nul
) > "%TEMP_LOG%"

move /y "%TEMP_LOG%" "%LOG_FILE%" >nul

:: ── 清理 7 天前的日志 ──
set "PS_SCRIPT=%TEMP%\link_XDU_clean.ps1"
echo $f = '%LOG_FILE%'; > "%PS_SCRIPT%"
echo $cutoff = (Get-Date).AddDays(-7); >> "%PS_SCRIPT%"
echo $lines = Get-Content $f -Encoding Default; >> "%PS_SCRIPT%"
echo $out = @(); $keep = $true; >> "%PS_SCRIPT%"
echo foreach ($line in $lines) { >> "%PS_SCRIPT%"
echo   if ($line -match '^={5,}') { $keep = $false } >> "%PS_SCRIPT%"
echo   if ($line -match '^\[\d{4}/\d{2}/\d{2}') { >> "%PS_SCRIPT%"
echo     $d = $matches[0] -replace '\[','' -replace '\].*',''; >> "%PS_SCRIPT%"
echo     try { $keep = [DateTime]::ParseExact($d,'yyyy/MM/dd',$null) -ge $cutoff } catch { $keep = $true } >> "%PS_SCRIPT%"
echo   } >> "%PS_SCRIPT%"
echo   if ($keep) { $out += $line } >> "%PS_SCRIPT%"
echo } >> "%PS_SCRIPT%"
echo Set-Content $f -Value $out -Encoding Default >> "%PS_SCRIPT%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" >nul 2>&1
del "%PS_SCRIPT%" >nul 2>&1
 
:: ── 联网成功后自动发送 IP 地址（受 config.bat 中 SEND_IP 控制） ──
if not "!RESULT_STATUS!"=="失败" (
    if "!SEND_IP!"=="1" (
        if exist "C:\Users\TZR\Desktop\IPsend\IPsend.bat" (
            echo.
            echo [信息] 正在发送 IP 地址...
            start "" /MIN "C:\Users\TZR\Desktop\IPsend\IPsend.bat"
            echo [信息] IP 地址发送中...
            echo [%LOG_DATE% %LOG_TIME%] 已触发 IP 地址发送 >> "%LOG_FILE%"
        )
    )
)


:: ── 退出 ──
if !NEED_PAUSE! equ 1 (
    echo ==============================
    echo   连接失败
    echo   日志已保存至：%LOG_FILE%
    echo ==============================
    pause >nul
    exit /b 1
)
exit /b 0
