$csvFile = "E:\repo_sec\gitee\LPC\LPC_20250827\2025年8月27日所获贵阳市云岩区人民法院档案室正卷卷宗资料SHA256&SM3哈希结果.csv"
$targetDir = "E:\repo_sec\gitee\LPC\LPC_20250827\正卷1"

$files = Get-ChildItem -Path $targetDir -File -Recurse | Where-Object {
    $_.FullName -ne $csvFile
}

function Convert-Size {
    param([long]$bytes)
    if ($bytes -lt 8) {
        return "$bytes Bit"
    }
    elseif ($bytes -lt 1024) {
        return "$bytes B"
    }
    elseif ($bytes -lt 1024*1024) {
        return "{0:N2} KB" -f ($bytes/1024)
    }
    elseif ($bytes -lt 1024*1024*1024) {
        return "{0:N2} MB" -f ($bytes/1024/1024)
    }
    else {
        return "{0:N2} GB" -f ($bytes/1024/1024/1024)
    }
}

$fileList = @()
foreach ($file in $files) {
    # 计算 SHA256
    $hash = Get-FileHash $file.FullName -Algorithm SHA256
    # 计算 SM3（使用内嵌的 C# 实现）
    try {
        # Ensure SM3 type is available (Add-Type done lazily)
        if (-not ([type]::GetType("SM3Lib.SM3"))) {
            # no-op - rely on Add-Type below which will add the type
        }
    } catch {}
    $creationTimeBJ = $file.CreationTimeUtc.AddHours(8)
    $creationTimeStr = $creationTimeBJ.ToString('yyyy年M月d日  HH:mm:ss')
    $lastWriteTimeBJ = $file.LastWriteTimeUtc.AddHours(8)
    $lastWriteTimeStr = $lastWriteTimeBJ.ToString('yyyy年M月d日  HH:mm:ss')
    $verifier = "王贵平"
    $verifyTime = (Get-Date).ToUniversalTime().AddHours(8).ToString('yyyy年M月d日  HH:mm:ss')
    $gpgPublicID = "15977DCF1A61ECA784CCF3F141FFD57D15150144"
    $gpgCreateTime = (Get-Date "2025/8/18 00:00:03").ToString('yyyy年M月d日  HH:mm:ss')
    $gpgPubKeyUrl = "https://keyserver.ubuntu.com/pks/lookup?search=15977DCF1A61ECA784CCF3F141FFD57D15150144&fingerprint=on&op=index"
    # Compute SM3 hash via compiled C# implementation (lazy compile)
    $sm3Hex = ""
    try {
        if (-not ([type]::GetType("SM3Lib.SM3"))) {
            Add-Type -TypeDefinition @'
using System;
using System.IO;
namespace SM3Lib {
    public static class SM3 {
        private static uint Rotl(uint x, int n) { return (x << n) | (x >> (32 - n)); }
        private static uint P0(uint x) { return x ^ Rotl(x, 9) ^ Rotl(x, 17); }
        private static uint P1(uint x) { return x ^ Rotl(x, 15) ^ Rotl(x, 23); }
        private static uint FF(uint x, uint y, uint z, int j) { return j <= 15 ? (x ^ y ^ z) : ((x & y) | (x & z) | (y & z)); }
        private static uint GG(uint x, uint y, uint z, int j) { return j <= 15 ? (x ^ y ^ z) : ((x & y) | (~x & z)); }

        private static readonly uint[] T = new uint[64];
        static SM3() {
            for (int i = 0; i < 16; i++) T[i] = 0x79CC4519u;
            for (int i = 16; i < 64; i++) T[i] = 0x7A879D8Au;
        }

        public static byte[] ComputeHash(byte[] msg) {
            // IV
            uint[] V = new uint[]{0x7380166Fu,0x4914B2B9u,0x172442D7u,0xDA8A0600u,0xA96F30BCu,0x163138AAu,0xE38DEE4Du,0xB0FB0E4Eu};

            byte[] m = Padding(msg);
            int n = m.Length / 64;
            for (int i = 0; i < n; i++) {
                uint[] W = new uint[68];
                uint[] W1 = new uint[64];
                for (int j = 0; j < 16; j++) {
                    int idx = i*64 + j*4;
                    W[j] = (uint)(m[idx]<<24 | m[idx+1]<<16 | m[idx+2]<<8 | m[idx+3]);
                }
                for (int j = 16; j < 68; j++) {
                    uint x = W[j-16] ^ W[j-9] ^ Rotl(W[j-3],15);
                    W[j] = P1(x) ^ Rotl(W[j-13],7) ^ W[j-6];
                }
                for (int j = 0; j < 64; j++) W1[j] = W[j] ^ W[j+4];

                uint A=V[0], B=V[1], C=V[2], D=V[3], E=V[4], F=V[5], G=V[6], H=V[7];
                for (int j = 0; j < 64; j++) {
                    uint SS1 = Rotl((Rotl(A,12) + E + Rotl(T[j], j)) , 7);
                    uint SS2 = SS1 ^ Rotl(A,12);
                    uint TT1 = (FF(A,B,C,j) + D + SS2 + W1[j]);
                    uint TT2 = (GG(E,F,G,j) + H + SS1 + W[j]);
                    D = C; C = Rotl(B,9); B = A; A = TT1;
                    H = G; G = Rotl(F,19); F = E; E = P0(TT2);
                }
                V[0] ^= A; V[1] ^= B; V[2] ^= C; V[3] ^= D; V[4] ^= E; V[5] ^= F; V[6] ^= G; V[7] ^= H;
            }
            byte[] outb = new byte[32];
            for (int i = 0; i < 8; i++) {
                outb[i*4] = (byte)(V[i] >> 24);
                outb[i*4+1] = (byte)(V[i] >> 16);
                outb[i*4+2] = (byte)(V[i] >> 8);
                outb[i*4+3] = (byte)(V[i]);
            }
            return outb;
        }

        private static byte[] Padding(byte[] m) {
            ulong len = (ulong)m.Length * 8UL;
            int k = (56 - (int)(m.Length + 1) % 64 + 64) % 64;
            byte[] padd = new byte[1 + k + 8];
            padd[0] = 0x80;
            for (int i = 0; i < 8; i++) padd[1+k+i] = (byte)((len >> (56 - 8*i)) & 0xFF);
            byte[] outb = new byte[m.Length + padd.Length];
            Buffer.BlockCopy(m, 0, outb, 0, m.Length);
            Buffer.BlockCopy(padd, 0, outb, m.Length, padd.Length);
            return outb;
        }
    }
}
'@ -Language CSharp
        }

        # compute hash bytes and hex
        $bytes = [SM3Lib.SM3]::ComputeHash([System.IO.File]::ReadAllBytes($file.FullName))
        $sm3Hex = ([BitConverter]::ToString($bytes)).Replace('-', '')
    } catch {
        $sm3Hex = "ERROR: $_"
    }

    $fileList += [PSCustomObject]@{
        "序号"         = 0
        "来源"         = "贵阳市云岩区人民法院档案室"
        "来源单位负责人" = "贵阳市云岩区人民法院档案室相关档案负责人"
        "文件名"       = $file.Name
        "操作时间"     = $creationTimeStr
        "创建时间"     = $lastWriteTimeStr
        "创建时间原始" = $lastWriteTimeBJ
        "SHA256哈希值"       = $hash.Hash
        "SM3哈希值"    = $sm3Hex
        "文件大小"     = Convert-Size $file.Length
        "校验人"       = $verifier
        "校验时间"     = $verifyTime
        "校验人GPG公钥ID" = $gpgPublicID
        "校验人GPG密钥创建时间" = $gpgCreateTime
        "获取公钥路径" = $gpgPubKeyUrl
    }
}

$sortedFiles = $fileList | Sort-Object "创建时间原始", "文件名"

$i = 1
$result = foreach ($file in $sortedFiles) {
    $file.序号 = $i
    [PSCustomObject]@{
        "序号"         = $file.序号
        "来源"         = $file.来源
        "来源单位负责人" = $file.来源单位负责人
        "文件名"       = $file.文件名
        "操作时间"     = $file.操作时间
        "创建时间"     = $file.创建时间
        "SHA256哈希值"       = $file.SHA256哈希值
    "SM3哈希值"    = $file."SM3哈希值"
        "文件大小"     = $file.文件大小
        "校验人"       = $file.校验人
        "校验时间"     = $file.校验时间
        "校验人GPG公钥ID" = $file.校验人GPG公钥ID
        "校验人GPG密钥创建时间" = $file.校验人GPG密钥创建时间
        "获取公钥路径" = $file.获取公钥路径
    }
    $i++  # 确保序号递增
}

# 将结果导出为CSV文件
$result | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
Write-Host "CSV文件已生成：$csvFile"