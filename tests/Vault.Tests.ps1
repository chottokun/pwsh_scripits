# Vault.Tests.ps1 - Critical Data Persistence & Folder-based Storage Test Suite

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) {
        throw "ASSERTION FAILED: $message"
    }
}

function Run-VaultTests {
    $currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $currentDir) { $currentDir = Get-Location }
    $srcDir = Join-Path (Split-Path -Parent $currentDir) "src"
    Import-Module (Join-Path $srcDir "CryptoModule.psm1") -DisableNameChecking -Force -Global
    Import-Module (Join-Path $srcDir "VaultModule.psm1") -DisableNameChecking -Force -Global

    $results = @{ Passed = 0; Failed = 0; Log = @() }

    # Temporary vault file
    $tempFile = [System.IO.Path]::GetTempFileName()
    $masterPass = "TestMasterPassword!2026"

    try {
        # Test 1: Vault Save & Load
        $entry1 = New-VaultEntry -Title "GitHub" -Url "https://github.com" -Username "octocat" -Password "OctoPass123" -Note "Dev Account"
        $entry2 = New-VaultEntry -Title "Google" -Url "https://google.com" -Username "user@gmail.com" -Password "GPass456" -Note "Personal"

        Save-Vault -Entries @($entry1, $entry2) -MasterPassword $masterPass -Path $tempFile

        $loadedEntries = Load-Vault -MasterPassword $masterPass -Path $tempFile
        Assert-True ($loadedEntries.Count -eq 2) "Loaded entry count is 2"
        Assert-True ($loadedEntries[0].title -eq "GitHub") "Entry 1 title matches"
        Assert-True ($loadedEntries[1].password -eq "GPass456") "Entry 2 password matches"

        $results.Passed++
        $results.Log += "[PASS] Test 1: Save & Load Vault data"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 1: Save & Load Vault data - $_"
    }

    # Test 2: Search functionality
    try {
        $found = @(Search-VaultEntries -Entries $loadedEntries -Keyword "git")
        Assert-True ($found.Count -eq 1) "Keyword 'git' matches exactly 1 entry"
        Assert-True ($found[0].title -eq "GitHub") "Matched entry is GitHub"

        $results.Passed++
        $results.Log += "[PASS] Test 2: Search functionality"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 2: Search functionality - $_"
    }

    # Test 3: Special characters & Symbols
    try {
        $complexPass = 'P@ssw0rd!#%^&*()_+-=[]{}|;:,.<>?'
        $unicodeEntry = New-VaultEntry -Title "Portal" -Url "https://portal.internal" -Username "user_test" -Password $complexPass -Note "Complex Password Test"
        Save-Vault -Entries @($unicodeEntry) -MasterPassword $masterPass -Path $tempFile
        $reloaded = Load-Vault -MasterPassword $masterPass -Path $tempFile

        Assert-True ($reloaded[0].password -eq $complexPass) "Complex special symbols in password correctly preserved"

        $results.Passed++
        $results.Log += "[PASS] Test 3: Special characters & symbol handling"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 3: Special characters handling - $_"
    }

    # Test 4: Dynamic entry addition and deletion
    try {
        $entries = @()
        $e1 = New-VaultEntry -Title "Test1" -Password "P1"
        $e2 = New-VaultEntry -Title "Test2" -Password "P2"

        $entries = @($entries) + $e1
        $entries = @($entries) + $e2
        Assert-True ($entries.Count -eq 2) "Dynamic array addition succeeded"

        $deleteId = $e1.id
        $entries = @($entries | Where-Object { $_.id -ne $deleteId })
        Assert-True ($entries.Count -eq 1) "Dynamic array deletion succeeded"
        Assert-True ($entries[0].title -eq "Test2") "Remaining entry is Test2"

        $results.Passed++
        $results.Log += "[PASS] Test 4: Dynamic entry array manipulation"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 4: Dynamic entry array manipulation - $_"
    }

    # Test 5: Critical: Newline, Quotes & JSON-Injection Attack Resistance
    try {
        $trickyNote = 'Line1' + "`r`n" + 'Line2' + "`t" + 'Tabbed "Quoted" {"jsonKey":"jsonValue"}'
        $injectionEntry = New-VaultEntry -Title "Injection<Script>" -Url "http://test.com/'or'1'='1" -Username "user`nname" -Password "P@ss`"word" -Note $trickyNote
        Save-Vault -Entries @($injectionEntry) -MasterPassword $masterPass -Path $tempFile

        $reloadedInj = Load-Vault -MasterPassword $masterPass -Path $tempFile
        Assert-True ($reloadedInj[0].note -eq $trickyNote) "Newlines and JSON injection symbols strictly preserved"
        Assert-True ($reloadedInj[0].url -eq "http://test.com/'or'1'='1") "SQL-like string preserved"

        $results.Passed++
        $results.Log += "[PASS] Test 5: Critical: JSON-injection & control character preservation"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 5: Injection resistance - $_"
    }

    # Test 6: Critical: Folder-relative Storage Path Creation Test
    try {
        $defaultPath = Get-DefaultVaultPath
        Assert-True ($defaultPath.Contains("data")) "Default vault path uses folder-relative data directory"

        $dataDir = Split-Path -Parent $defaultPath
        Assert-True (Test-Path $dataDir) "Data directory exists / auto-created"

        $results.Passed++
        $results.Log += "[PASS] Test 6: Critical: Folder-relative storage path resolution"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 6: Folder-relative path resolution - $_"
    } finally {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-VaultTests
}
