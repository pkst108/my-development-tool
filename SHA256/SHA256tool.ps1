$fileList = Get-Content -Path "F:\SHA256\FilePath.txt" -Encoding UTF8
$successCount = 0
foreach ($line in $fileList) {
    $filePath = $line.Trim('"').Trim()
    if ([string]::IsNullOrWhiteSpace($filePath)) { continue }
    if (Test-Path $filePath) {
        try {
            $hash = Get-FileHash -Path $filePath -Algorithm SHA256
            Write-Host "Path: $filePath"
            Write-Host "SHA256: $($hash.Hash)"
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