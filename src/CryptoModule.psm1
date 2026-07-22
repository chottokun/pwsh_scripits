# CryptoModule.psm1 - Best-practice Security Core (PBKDF2 + AES-256 + HMAC-SHA256)

Add-Type -AssemblyName System.Security

function New-CryptoSalt {
    [CmdletBinding()]
    param([int]$Length = 32)
    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    return $bytes
}

function Derive-KeyIVAndHmac {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Password,
        [Parameter(Mandatory=$true)]
        [byte[]]$Salt,
        [int]$Iterations = 100000
    )
    # Generate 80 bytes: 32 (AES-256 Key) + 16 (AES IV) + 32 (HMAC Key)
    $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $Salt, $Iterations)
    $aesKey  = $pbkdf2.GetBytes(32)
    $aesIV   = $pbkdf2.GetBytes(16)
    $hmacKey = $pbkdf2.GetBytes(32)
    return @{ AesKey = $aesKey; AesIV = $aesIV; HmacKey = $hmacKey }
}

function Protect-DataWithAes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$PlainText,
        [Parameter(Mandatory=$true)]
        [byte[]]$AesKey,
        [Parameter(Mandatory=$true)]
        [byte[]]$AesIV
    )
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $AesKey
    $aes.IV = $AesIV
    $encryptor = $aes.CreateEncryptor()
    $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
    $cipherBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
    $encryptor.Dispose()
    $aes.Dispose()
    return $cipherBytes
}

function Unprotect-DataWithAes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$CipherBytes,
        [Parameter(Mandatory=$true)]
        [byte[]]$AesKey,
        [Parameter(Mandatory=$true)]
        [byte[]]$AesIV
    )
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $AesKey
    $aes.IV = $AesIV
    $decryptor = $aes.CreateDecryptor()
    $plainBytes = $decryptor.TransformFinalBlock($CipherBytes, 0, $CipherBytes.Length)
    $decryptor.Dispose()
    $aes.Dispose()
    return [System.Text.Encoding]::UTF8.GetString($plainBytes)
}

function Protect-DataWithDpapi {
    [CmdletBinding()]
    param([byte[]]$Data)
    return [System.Security.Cryptography.ProtectedData]::Protect(
        $Data,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
}

function Unprotect-DataWithDpapi {
    [CmdletBinding()]
    param([byte[]]$EncryptedData)
    return [System.Security.Cryptography.ProtectedData]::Unprotect(
        $EncryptedData,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
}

function Get-HmacSignature {
    param([byte[]]$Data, [byte[]]$HmacKey)
    $hmac = New-Object System.Security.Cryptography.HMACSHA256(@(,$HmacKey))
    $sig = $hmac.ComputeHash($Data)
    $hmac.Dispose()
    return $sig
}

function ConvertTo-EncryptedVaultData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$JsonText,
        [Parameter(Mandatory=$true)]
        [string]$MasterPassword,
        [switch]$UseDpapi = $false
    )
    $salt = New-CryptoSalt -Length 32
    $derived = Derive-KeyIVAndHmac -Password $MasterPassword -Salt $salt
    $aesCipher = Protect-DataWithAes -PlainText $JsonText -AesKey $derived.AesKey -AesIV $derived.AesIV

    $targetBytes = $aesCipher
    if ($UseDpapi) {
        $targetBytes = Protect-DataWithDpapi -Data $aesCipher
    }

    # HMAC Signature for tampering detection
    $hmacSig = Get-HmacSignature -Data $targetBytes -HmacKey $derived.HmacKey

    return @{
        version  = "2.0"
        useDpapi = [bool]$UseDpapi
        salt     = [Convert]::ToBase64String($salt)
        hmac     = [Convert]::ToBase64String($hmacSig)
        data     = [Convert]::ToBase64String($targetBytes)
    }
}

function ConvertFrom-EncryptedVaultData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$VaultHashtable,
        [Parameter(Mandatory=$true)]
        [string]$MasterPassword
    )
    if (-not $VaultHashtable.salt -or -not $VaultHashtable.data) {
        throw "Vault data format is invalid."
    }

    $salt = [Convert]::FromBase64String($VaultHashtable.salt)
    $rawBytes = [Convert]::FromBase64String($VaultHashtable.data)
    $derived = Derive-KeyIVAndHmac -Password $MasterPassword -Salt $salt

    # 1. HMAC Verification (if present)
    if ($VaultHashtable.hmac) {
        $expectedHmac = [Convert]::FromBase64String($VaultHashtable.hmac)
        $actualHmac = Get-HmacSignature -Data $rawBytes -HmacKey $derived.HmacKey
        
        $match = $true
        if ($expectedHmac.Length -ne $actualHmac.Length) {
            $match = $false
        } else {
            for ($i = 0; $i -lt $expectedHmac.Length; $i++) {
                if ($expectedHmac[$i] -ne $actualHmac[$i]) {
                    $match = $false
                    break
                }
            }
        }
        if (-not $match) {
            throw "Integrity check failed: Data has been tampered with or incorrect Master Password used."
        }
    }

    # 2. DPAPI Unprotect if enabled
    $aesCipher = $rawBytes
    if ($VaultHashtable.useDpapi -eq $true -or $VaultHashtable.version -eq "1.0") {
        $aesCipher = Unprotect-DataWithDpapi -EncryptedData $rawBytes
    }

    # 3. AES Decryption
    $jsonText = Unprotect-DataWithAes -CipherBytes $aesCipher -AesKey $derived.AesKey -AesIV $derived.AesIV
    return $jsonText
}

Export-ModuleMember -Function ConvertTo-EncryptedVaultData, ConvertFrom-EncryptedVaultData, New-CryptoSalt, Derive-KeyIVAndHmac, Protect-DataWithAes, Unprotect-DataWithAes, Protect-DataWithDpapi, Unprotect-DataWithDpapi
