# 简化路径与变量
$base = 'G:\keys\2'
$homedir = Join-Path $base 'gpg'

# 确保 GPG 可用
if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
	Write-Host '找不到 gpg 可执行文件，请先安装 GnuPG 并将 gpg 加入 PATH。'
	exit 1
}

# 创建所需目录
New-Item -Path $homedir -ItemType Directory -Force | Out-Null

# 生成4096位GPG密钥（密码 5Pz5QMNsQSjWduMbUrSEeDrLP3pytMUSHZ9YvvZDthh7ttVvRjuquFS5dPigEQvFHznht5SjFThDPVyYLiLpV9otnJpzKxMuUAff）
# 在生成前检测密钥是否已存在，避免重复生成
$keyId = 'case20190120@outlook.com'
$listOut = & gpg --homedir $homedir --with-colons --list-keys $keyId 2>$null
if ($listOut -and ($listOut -match '^pub')) {
	Write-Host "检测到已存在的密钥：$keyId，正在删除以重新生成（选 B）。"
	# 先删除私钥再删除公钥（非交互式）
	& gpg --homedir $homedir --batch --yes --pinentry-mode loopback --delete-secret-keys $keyId 2>$null
	& gpg --homedir $homedir --batch --yes --pinentry-mode loopback --delete-keys $keyId 2>$null
}

# 使用 batch 参数文件精确控制主键/子键（Option B：主键 RSA4096 sign,cert；子键 RSA4096 encrypt）
$paramFile = Join-Path $base 'gpg_key_batch.txt'
$batch = @'
Key-Type: RSA
Key-Length: 4096
Key-Usage: sign,cert
Subkey-Type: RSA
Subkey-Length: 4096
Subkey-Usage: encrypt
Name-Real: 王贵平
Name-Email: case20190120@outlook.com
Expire-Date: 0
Passphrase: 5Pz5QMNsQSjWduMbUrSEeDrLP3pytMUSHZ9YvvZDthh7ttVvRjuquFS5dPigEQvFHznht5SjFThDPVyYLiLpV9otnJpzKxMuUAff
%commit
'@

# 写入参数文件（ASCII）并生成密钥
$batch | Out-File -FilePath $paramFile -Encoding ascii
Write-Host "使用 batch 参数文件生成密钥：$paramFile"
& gpg --homedir $homedir --batch --pinentry-mode loopback --passphrase "5Pz5QMNsQSjWduMbUrSEeDrLP3pytMUSHZ9YvvZDthh7ttVvRjuquFS5dPigEQvFHznht5SjFThDPVyYLiLpV9otnJpzKxMuUAff" --generate-key $paramFile
$genExit = $LASTEXITCODE
Remove-Item $paramFile -ErrorAction SilentlyContinue
if ($genExit -ne 0) {
	Write-Host "密钥生成失败（exit $genExit）。请检查 gpg 输出。"
	exit $genExit
} else {
	Write-Host "密钥已根据 Option B 生成。"
}

# 导出公钥（使用 --output 代替 shell 重定向）
 $pubPath = Join-Path $base 'gpg_public.asc'
& gpg --homedir $homedir --batch --pinentry-mode loopback --yes --armor --output $pubPath --export $keyId
if ($LASTEXITCODE -ne 0) {
	Write-Host "公钥导出失败（exit $LASTEXITCODE）。请检查 gpg 输出。"
} else {
	Write-Host "公钥已导出到：$pubPath"
}

# 导出私钥（非交互式导出需要 --batch 和 loopback）
 $privPath = Join-Path $base 'gpg_private.asc'
& gpg --homedir $homedir --batch --pinentry-mode loopback --yes --passphrase "5Pz5QMNsQSjWduMbUrSEeDrLP3pytMUSHZ9YvvZDthh7ttVvRjuquFS5dPigEQvFHznht5SjFThDPVyYLiLpV9otnJpzKxMuUAff" --armor --output $privPath --export-secret-keys $keyId
if ($LASTEXITCODE -ne 0) {
	Write-Host "私钥导出失败（exit $LASTEXITCODE）。请检查 gpg 输出。"
} else {
	Write-Host "私钥已导出到：$privPath"
}

Write-Host "操作完成，目录：$base"