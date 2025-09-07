
# 文件列表路径
$fileList = "F:\老司机工具\change_file_time\fixfiles.txt"

Get-Content $fileList | ForEach-Object {
    $parts = $_ -split "`t"  # 使用制表符分割
    if ($parts.Count -eq 2) {
        $fullPath = $parts[0].Trim()
        $datetime = Get-Date $parts[1].Trim()
        
        if (Test-Path $fullPath) {
            Set-ItemProperty -Path $fullPath -Name CreationTime -Value $datetime
            Set-ItemProperty -Path $fullPath -Name LastWriteTime -Value $datetime
            Set-ItemProperty -Path $fullPath -Name LastAccessTime -Value $datetime
            Write-Host "$fullPath 已处理为 $datetime" -ForegroundColor Green
        } else {
            Write-Host "$fullPath 文件不存在，未处理！" -ForegroundColor Red
        }
    } else {
        Write-Host "跳过无效行: $_" -ForegroundColor Yellow
    }
}