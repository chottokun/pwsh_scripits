$moduleDir = $PSScriptRoot
if (-not $moduleDir) { $moduleDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if ($moduleDir) {
    Import-Module (Join-Path $moduleDir "CryptoModule.psm1") -DisableNameChecking -Force
}

function Get-DefaultVaultPath {
    $scriptDir = Split-Path -Parent $PSScriptRoot
    if (-not $scriptDir) {
        $scriptDir = Get-Location
    }
    $dir = Join-Path $scriptDir "data"
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return Join-Path $dir "vault.json"
}

function Test-VaultExists {
    [CmdletBinding()]
    param([string]$Path = (Get-DefaultVaultPath))
    return Test-Path $Path
}

function Save-Vault {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [array]$Entries = @(),
        [Parameter(Mandatory=$true)]
        [string]$MasterPassword,
        [string]$Path = (Get-DefaultVaultPath)
    )
    if ($null -eq $Entries -or $Entries.Count -eq 0) {
        $jsonText = "[]"
    } else {
        $jsonText = $Entries | ConvertTo-Json -Depth 5 -Compress
        if (-not $jsonText -or $jsonText -eq "null") {
            $jsonText = "[]"
        }
    }
    $vaultData = ConvertTo-EncryptedVaultData -JsonText $jsonText -MasterPassword $MasterPassword
    $vaultJson = $vaultData | ConvertTo-Json -Depth 3
    
    $parentDir = Split-Path -Parent $Path
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    # Automatic Backup (.bak) of existing vault file before overwriting
    if (Test-Path $Path) {
        try {
            $bakPath = "$Path.bak"
            Copy-Item -Path $Path -Destination $bakPath -Force -ErrorAction SilentlyContinue
        } catch {}
    }

    Set-Content -Path $Path -Value $vaultJson -Encoding UTF8
}

function Load-Vault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$MasterPassword,
        [string]$Path = (Get-DefaultVaultPath)
    )
    if (-not (Test-Path $Path)) {
        throw "Vault file does not exist at path: $Path"
    }

    $rawJson = Get-Content -Path $Path -Raw -Encoding UTF8
    $vaultObj = $rawJson | ConvertFrom-Json
    
    $hashtable = @{
        version = $vaultObj.version
        salt    = $vaultObj.salt
        data    = $vaultObj.data
    }

    $jsonText = ConvertFrom-EncryptedVaultData -VaultHashtable $hashtable -MasterPassword $MasterPassword
    if ([string]::IsNullOrWhiteSpace($jsonText) -or $jsonText -eq "[]") {
        return @()
    }

    $entries = $jsonText | ConvertFrom-Json
    if ($entries -isnot [array]) {
        $entries = @($entries)
    }
    return $entries
}

function New-VaultEntry {
    [CmdletBinding()]
    param(
        [string]$Title = "",
        [string]$Url = "",
        [string]$Username = "",
        [string]$Password = "",
        [string]$Note = ""
    )
    return [PSCustomObject]@{
        id        = [guid]::NewGuid().ToString()
        title     = $Title
        url       = $Url
        username  = $Username
        password  = $Password
        note      = $Note
        updatedAt = (Get-Date).ToString("o")
    }
}

function Get-ObjectPropertyValue {
    param($obj, [string]$propName)
    if ($null -eq $obj) { return "" }
    try {
        if ($obj.PSObject -and $obj.PSObject.Properties[$propName]) {
            $val = $obj.PSObject.Properties[$propName].Value
            if ($null -ne $val) { return $val.ToString() }
        }
    } catch {}
    try {
        if ($obj -is [hashtable] -and $obj.ContainsKey($propName)) {
            $val = $obj[$propName]
            if ($null -ne $val) { return $val.ToString() }
        }
    } catch {}
    return ""
}

function Search-VaultEntries {
    [CmdletBinding()]
    param(
        [array]$Entries,
        [string]$Keyword
    )
    if ([string]::IsNullOrWhiteSpace($Keyword)) {
        return @($Entries)
    }
    $kw = $Keyword.ToLower()
    $matchedList = [System.Collections.Generic.List[Object]]::new()
    foreach ($entry in $Entries) {
        $t  = (Get-ObjectPropertyValue -obj $entry -propName "title").ToLower()
        $u  = (Get-ObjectPropertyValue -obj $entry -propName "url").ToLower()
        $un = (Get-ObjectPropertyValue -obj $entry -propName "username").ToLower()
        $n  = (Get-ObjectPropertyValue -obj $entry -propName "note").ToLower()

        if ($t.Contains($kw) -or $u.Contains($kw) -or $un.Contains($kw) -or $n.Contains($kw)) {
            $matchedList.Add($entry)
        }
    }
    return @($matchedList.ToArray())
}

Export-ModuleMember -Function Get-DefaultVaultPath, Test-VaultExists, Save-Vault, Load-Vault, New-VaultEntry, Search-VaultEntries
