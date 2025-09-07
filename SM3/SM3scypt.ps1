$fileList = Get-Content -Path "F:\老司机工具\SM3\filespach.txt" -Encoding UTF8
$successCount = 0
foreach ($line in $fileList) {
    $filePath = $line.Trim('"').Trim()
    if ([string]::IsNullOrWhiteSpace($filePath)) { continue }
    if (Test-Path $filePath) {
        try {
            $hash = & SM3 $filePath
            Write-Host "Path: $filePath"
            Write-Host "SM3: $($hash)"
            $successCount++
        } catch {
            Write-Host "Path: $filePath"
            Write-Host "无法计算哈希"
        }
    } else {
        Write-Host "Path: $filePath"
        Write-Host "文件不存在"
    }
    Write-Host "-----------------------------"
}
Write-Host "成功处理文件数量: $successCount"
Write-Host "全部处理完毕，请将结果记录后退出..."
Write-Host "王贵平设计"
[void][System.Console]::ReadKey($true)