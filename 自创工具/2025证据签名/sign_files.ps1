param(
    [string]$sourceDir,
    [string]$targetDir,
    [string]$gpgKey
)

Write-Host "Starting recursive file signing..."
$fileCount = 0

Get-ChildItem -Path $sourceDir -Recurse -File | ForEach-Object {
    $fileCount++
    $file = $_
    $relativePath = $file.FullName.Substring($sourceDir.Length + 1)
    $relativeDir = Split-Path $relativePath -Parent
    
    Write-Host "Checking file: $($file.FullName)"
    
    if ($file.Extension -ne '.sig') {
        Write-Host "Relative path: $relativePath"
        Write-Host "Relative directory: $relativeDir"
        
        # Create target directory structure
        if ($relativeDir) {
            $targetSubDir = Join-Path $targetDir $relativeDir
            if (!(Test-Path $targetSubDir)) {
                Write-Host "Creating directory: $targetSubDir"
                New-Item -ItemType Directory -Path $targetSubDir -Force | Out-Null
            }
            $sigOutputPath = Join-Path $targetSubDir "$($file.Name).sig"
        } else {
            $sigOutputPath = Join-Path $targetDir "$($file.Name).sig"
        }
        
        Write-Host "Signature output path: $sigOutputPath"
        Write-Host "Signing: $($file.Name) (path: $relativePath)"
        
        # Execute GPG signing
        $gpgArgs = @(
            '--local-user', $gpgKey,
            '--digest-algo', 'SHA256',
            '--s2k-digest-algo', 'SHA256',
            '--personal-digest-preferences', 'SHA256',
            '--detach-sign',
            '--armor',
            '-o', $sigOutputPath,
            $file.FullName
        )
        
        $result = & gpg @gpgArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Signing successful: $($file.Name)"
        } else {
            Write-Host "Signing failed: $($file.Name)"
            Write-Host $result
        }
    }
}

Write-Host "Total files checked: $fileCount" 