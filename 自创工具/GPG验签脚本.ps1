$minVersion = 7

if ($PSVersionTable.PSVersion.Major -lt $minVersion) {
    Write-Host "请使用 PowerShell 7 或更高版本运行本脚本！" -ForegroundColor Red
    exit
}

$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8



# 定义原件和签名文件的路径
$originalPath = [System.IO.Path]::GetFullPath("I:\A20280827")  # 改为根目录，支持递归搜索
$signaturePath = [System.IO.Path]::GetFullPath("E:\gzgjf250\public-for-courts\完整性校验数据\王贵平的GPG签名文件")
$publicKeyPath = [System.IO.Path]::GetFullPath("F:\签名系统\gpg\6FECA20A_pub1D2E1425.asc")

# 已知公钥指纹（如有，直接填写，否则留空）
$knownFingerprint = "36788E18D1584881F9C3DE39B900C0CD26375457"

# 检查路径是否存在
if (-not (Test-Path $originalPath)) {
    Write-Host "原件路径不存在: $originalPath" -ForegroundColor Red
    exit
}

if (-not (Test-Path $signaturePath)) {
    Write-Host "签名文件路径不存在: $signaturePath" -ForegroundColor Red
    exit
}

if (-not (Test-Path $publicKeyPath)) {
    Write-Host "公钥文件不存在: $publicKeyPath" -ForegroundColor Red
    exit
}

# 导入公钥
Write-Host "正在导入公钥..." -ForegroundColor Yellow
$importResult = & gpg --import $publicKeyPath 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "公钥导入成功" -ForegroundColor Green
} else {
    Write-Host "公钥导入失败: $importResult" -ForegroundColor Red
    exit
}

# 获取导入的公钥指纹，用于后续删除（兜底）
$keyFingerprint = $null
$importOutput = & gpg --list-keys --with-fingerprint 2>&1
if ($LASTEXITCODE -eq 0) {
    # 查找最近导入的公钥指纹
    $lines = $importOutput -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "pub\s+\w+\/(\w+)\s+\d{4}-\d{2}-\d{2}") {
            $keyId = $matches[1]
            # 查找对应的指纹行
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                if ($lines[$j] -match "^\s+(\w{40})$") {
                    $keyFingerprint = $matches[1]
                    break
                }
                if ($lines[$j] -match "^pub\s+") {
                    break
                }
            }
            break
        }
    }
}

if (-not $keyFingerprint) {
    Write-Host "警告: 无法自动提取公钥指纹，将优先使用已知指纹删除公钥" -ForegroundColor Yellow
}

# 显示用于验证的GPG公钥信息
Write-Host "------------------------"
Write-Host "GPG公钥信息：" -ForegroundColor Yellow
$keyInfo = & gpg --with-colons --import-options show-only --import $publicKeyPath 2>&1
if ($LASTEXITCODE -eq 0) {
    $keyId = $null
    $fingerprint = $null
    $uids = @()
    $created = $null
    $expires = $null
    $keyType = $null
    $keyUsage = $null
    $keyLength = $null
    $algoId = $null
    $lines = $keyInfo -split "`n"
    foreach ($line in $lines) {
        $fields = $line -split ':'
        if ($fields[0] -eq 'pub' -and $fields.Count -ge 6) {
            $keyId = $fields[4]
            $timestamp = $fields[5]
            $expiresTimestamp = $fields[6]
            
            # 解析密钥类型和长度 (第3个字段为算法ID，第4个字段为密钥长度)
            if ($fields.Count -ge 4) {
                $algoId = $fields[2]
                $keyLength = $fields[3]
                switch ($algoId) {
                    "1" { $keyType = "RSA" }
                    "17" { $keyType = "DSA" }
                    "19" { $keyType = "ECDSA" }
                    "22" { $keyType = "EdDSA (Ed25519)" }
                    "16" { $keyType = "ElGamal" }
                    "20" { $keyType = "ECDH" }
                    default { $keyType = "RSA" }
                }
                # 如果密钥长度有效，添加到类型描述中
                if ($keyLength -and $keyLength -match '^\d+$') {
                    $keyType = "$keyType ($keyLength位)"
                }
            }
            
            # 解析密钥用途 (第11个字段)
            if ($fields.Count -ge 11) {
                $usage = $fields[10]
                $usageDesc = @()
                if ($usage -match 'e') { $usageDesc += "加密" }
                if ($usage -match 's') { $usageDesc += "签名" }
                if ($usage -match 'c') { $usageDesc += "认证" }
                if ($usage -match 'a') { $usageDesc += "认证" }
                if ($usageDesc.Count -eq 0) { $usageDesc += "签名, 加密" }
                $keyUsage = $usageDesc -join ", "
            } else {
                $keyUsage = "签名, 加密"
            }
            
            try {
                $created = [datetime]::UnixEpoch.AddSeconds([int64]$timestamp).ToLocalTime()
            } catch {}
            
            if ($expiresTimestamp -and $expiresTimestamp -ne "0") {
                try {
                    $expires = [datetime]::UnixEpoch.AddSeconds([int64]$expiresTimestamp).ToLocalTime()
                } catch {}
            }
        }
        if ($fields[0] -eq 'fpr' -and $fields.Count -ge 10) {
            $fingerprint = $fields[9]
        }
        if ($fields[0] -eq 'uid' -and $fields.Count -ge 10) {
            $uids += $fields[9]
        }
    }
    
    # 显示核心密钥信息（按指定顺序）
    # 1. UID显示在第1行
    if ($uids.Count -gt 0) {
        Write-Host "  UID: $($uids[0])" -ForegroundColor Cyan
    }
    
    # 2. 私钥短ID显示在第2行
    if ($keyId -and $keyId.Length -ge 16) {
        $shortKeyId = $keyId.Substring($keyId.Length - 16)
        Write-Host "  私钥短ID: $shortKeyId" -ForegroundColor Cyan
    }
    
    # 3. 密钥类型显示在第3行（修正为4096位RSA）
    Write-Host "  密钥类型: RSA (4096位)" -ForegroundColor Cyan
    
    # 4. 公钥ID（长ID）显示在第4行
    if ($fingerprint) { 
        Write-Host "  公钥ID: $fingerprint" -ForegroundColor Cyan 
    }
    
    # 5. 公钥用途显示在第5行
    Write-Host "  公钥用途: 验证、加密【注：加密文件只有该私钥持有者能解密查看】" -ForegroundColor Cyan
    
    # 6. 创建时间显示在第6行
    if ($created) {
        $createdStr = $created.ToString('yyyy年M月d日 HH:mm:ss')
        Write-Host "  创建时间: $createdStr" -ForegroundColor Cyan
    }
    
    # 7. 过期时间显示在第7行
    if ($expires) {
        $expiresStr = $expires.ToString('yyyy年M月d日 HH:mm:ss')
        Write-Host "  过期时间: $expiresStr" -ForegroundColor Cyan
    } else {
        Write-Host "  过期时间: 永不过期" -ForegroundColor Cyan
    }
} else {
    Write-Host "无法获取公钥详细信息: $keyInfo" -ForegroundColor Red
}

Write-Host "------------------------"

$total = 0
$success = 0
$fail = 0
$failFiles = @()
$notFoundFiles = @()


# 获取所有签名文件（递归）
$signatureFiles = Get-ChildItem -Path $signaturePath -File -Filter "*.sig" -Recurse
Write-Host "找到 $($signatureFiles.Count) 个签名文件（含子目录）" -ForegroundColor Cyan

# 创建原件文件索引（递归，排除签名文件目录）
Write-Host "正在扫描原件文件..." -ForegroundColor Yellow
$originalFiles = @{}
Get-ChildItem -Path $originalPath -File -Recurse | Where-Object { 
    $_.DirectoryName -notlike "*\Sig签名文件*" -and $_.Name -notlike "*.sig"
} | ForEach-Object {
    $originalFiles[$_.Name] = $_.FullName
}

Write-Host "找到 $($originalFiles.Count) 个文件（含子目录）" -ForegroundColor Cyan

# 验证每个签名文件
$signatureFiles | ForEach-Object {
    $signatureFile = $_.FullName
    $signatureFileName = $_.Name
    $originalFileName = $signatureFileName -replace '\.sig$', ''

    if ($originalFiles.ContainsKey($originalFileName)) {
        $originalFile = $originalFiles[$originalFileName]
        $total++
        Write-Host "被验签文件名称: $originalFileName" -ForegroundColor Cyan
        Write-Host "  这是被验签文件路径: $originalFile" -ForegroundColor Gray
        Write-Host "  这是签名文件的路径: $signatureFile" -ForegroundColor Gray

        # 使用 --status-fd 1 捕获签名详细信息
        $verifyOutput = & gpg --status-fd 1 --verify $signatureFile $originalFile 2>&1
        $exitCode = $LASTEXITCODE  # 立即保存退出码，避免被后续命令影响
        $result = $verifyOutput
        $signTime = $null
        $lines = $verifyOutput -split "`n"
        foreach ($line in $lines) {
            if ($line -match '^\[GNUPG:\] VALIDSIG ') {
                $fields = $line -split ' '
                # VALIDSIG格式: VALIDSIG <fingerprint> <timestamp> <expires> <sig-version> <reserved> <pubkey-algo> <hash-algo> <sig-class> <primary-key-fpr>
                if ($fields.Count -ge 9) {
                    # 第5个字段（$fields[4]）为签名时间戳
                    $timestamp = $fields[4]
                    if ($timestamp -match '^[0-9]+$' -and $timestamp -gt 1000000000) {
                        try {
                            $signTime = [datetime]::UnixEpoch.AddSeconds([int64]$timestamp).ToLocalTime()
                        } catch {}
                    }
                }
                break
            }
        }
        if ($exitCode -eq 0) {
            $success++
            Write-Host "验证通过" -ForegroundColor Green
            if ($signTime) {
                $signTimeStr = $signTime.ToString('yyyy年M月d日  HH:mm:ss')
                Write-Host "签名时间：$signTimeStr" -ForegroundColor Yellow
            } else {
                Write-Host "签名时间：未能提取" -ForegroundColor Yellow
            }
        } else {
            $fail++
            $failFiles += $originalFile
            Write-Host "验证失败" -ForegroundColor Red
            # 红色显示gpg输出内容
            $result -split "`n" | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        }
        Write-Host "------------------------"
    } else {
        $notFoundFiles += $originalFileName
        Write-Host "警告: 找不到对应的原件文件: $originalFileName" -ForegroundColor Yellow
        Write-Host "  签名文件: $signatureFile" -ForegroundColor Gray
        Write-Host "------------------------"
    }
}

Write-Host "批量验证完成!" -ForegroundColor Green
Write-Host "------------------------"
Write-Host "总验证文件数: $total"
Write-Host "验证通过数: $success" -ForegroundColor Green
Write-Host "验证失败数: $fail" -ForegroundColor Red
Write-Host "未找到原件数: $($notFoundFiles.Count)" -ForegroundColor Yellow

if ($fail -gt 0) {
    Write-Host "验证失败文件明细:" -ForegroundColor Red
    $failFiles | ForEach-Object { Write-Host $_ -ForegroundColor Red }
}

if ($notFoundFiles.Count -gt 0) {
    Write-Host "未找到原件的签名文件:" -ForegroundColor Yellow
    $notFoundFiles | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
}

# 优先用已知指纹删除公钥，自动提取的指纹为兜底
$deleteFingerprint = if ($knownFingerprint) { $knownFingerprint } else { $keyFingerprint }
if ($deleteFingerprint) {
    Write-Host "------------------------"
    Write-Host "正在删除导入的公钥..." -ForegroundColor Yellow
    # 先尝试删除私钥（如果存在）
    $deleteSecretResult = & gpg --batch --yes --delete-secret-key $deleteFingerprint 2>&1
    # 然后删除公钥
    $deleteResult = & gpg --batch --yes --delete-key $deleteFingerprint 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "公钥删除成功" -ForegroundColor Green
    } else {
        Write-Host "公钥删除失败: $deleteResult" -ForegroundColor Red
        Write-Host "请手动删除公钥: gpg --delete-key $deleteFingerprint" -ForegroundColor Yellow
    }
} else {
    Write-Host "------------------------"
    Write-Host "无法自动删除公钥，请手动清理" -ForegroundColor Yellow
}

# 添加签名算法类型提醒
Write-Host "------------------------"
Write-Host "签名算法类型提醒：" -ForegroundColor Yellow
Write-Host "如需核实签名使用的哈希算法是否为SHA256，可使用以下命令：" -ForegroundColor Cyan
Write-Host "gpg --verify --verbose `"F:\签名系统\签名文件\示例文件.sig`" `"F:\签名系统\原始文件\示例文件`"" -ForegroundColor Green
Write-Host "注意：请将'示例文件'替换为实际的文件名" -ForegroundColor Yellow
Write-Host "------------------------"