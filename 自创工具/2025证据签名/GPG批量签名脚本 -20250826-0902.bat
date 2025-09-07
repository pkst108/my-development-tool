@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 设置路径变量
set "sourceDir=I:"
set "targetDir=F:\老司机工具\自创工具\2025证据签名\签名文件"
set "gpgKey=15150144"

echo 当前工作目录: %CD%
echo 源文件夹: !sourceDir!
echo 目标文件夹: !targetDir!
echo 使用的密钥ID: !gpgKey!

:: 先检查并创建目标文件夹（如果不存在）
if not exist "!targetDir!" (
    echo 创建目标文件夹...
    mkdir "!targetDir!"
)

:: 检查源文件夹是否存在
if not exist "!sourceDir!" (
    echo 错误：源文件夹不存在：!sourceDir!
    pause
    exit /b 1
)

echo.
echo 开始使用指定密钥进行签名...

:: 设置默认哈希算法为SHA256
echo 设置默认哈希算法为SHA256...
set GPG_DIGEST_ALGO=SHA256

:: 检查密钥是否存在
echo Checking if key exists...
gpg --list-keys !gpgKey!
if !errorlevel! neq 0 (
    echo 错误：密钥 !gpgKey! 不存在
    pause
    exit /b 1
)

:: 使用PowerShell递归遍历文件并签名
echo 开始递归签名文件...
powershell -ExecutionPolicy Bypass -File "%~dp0sign_files.ps1" "!sourceDir!" "!targetDir!" "!gpgKey!"

echo.
echo Signing completed!
echo Signature files saved in: !targetDir!
pause