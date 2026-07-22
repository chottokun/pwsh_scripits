# RunAllTests.ps1 - 全自動テストスイートランナー

$currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $currentDir "Crypto.Tests.ps1")
. (Join-Path $currentDir "Vault.Tests.ps1")
. (Join-Path $currentDir "Utils.Tests.ps1")
. (Join-Path $currentDir "GUI.Tests.ps1")
. (Join-Path $currentDir "Logger.Tests.ps1")
. (Join-Path $currentDir "GUI_FullButtons.Tests.ps1")
. (Join-Path $currentDir "GUI_CriticalUserOperations.Tests.ps1")
. (Join-Path $currentDir "GUI_JP.Tests.ps1")

Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host " Running SimplePASS Automated Test Suite " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor DarkGray

$cryptoRes        = Run-CryptoTests
$vaultRes         = Run-VaultTests
$utilsRes         = Run-UtilsTests
$guiRes           = Run-GuiTests
$loggerRes        = Run-LoggerTests
$guiButtonRes     = Run-GuiFullButtonsTests
$guiUserOpsRes    = Run-GuiCriticalUserOperationsTests
$guiJpRes         = Run-GuiJpTests

$totalPassed = 0
if ($cryptoRes -and $cryptoRes.Passed) { $totalPassed += $cryptoRes.Passed }
if ($vaultRes -and $vaultRes.Passed) { $totalPassed += $vaultRes.Passed }
if ($utilsRes -and $utilsRes.Passed) { $totalPassed += $utilsRes.Passed }
if ($guiRes -and $guiRes.Passed) { $totalPassed += $guiRes.Passed }
if ($loggerRes -and $loggerRes.Passed) { $totalPassed += $loggerRes.Passed }
if ($guiButtonRes -and $guiButtonRes.Passed) { $totalPassed += $guiButtonRes.Passed }
if ($guiUserOpsRes -and $guiUserOpsRes.Passed) { $totalPassed += $guiUserOpsRes.Passed }
if ($guiJpRes -and $guiJpRes.Passed) { $totalPassed += $guiJpRes.Passed }

$totalFailed = 0
if ($cryptoRes -and $cryptoRes.Failed) { $totalFailed += $cryptoRes.Failed }
if ($vaultRes -and $vaultRes.Failed) { $totalFailed += $vaultRes.Failed }
if ($utilsRes -and $utilsRes.Failed) { $totalFailed += $utilsRes.Failed }
if ($guiRes -and $guiRes.Failed) { $totalFailed += $guiRes.Failed }
if ($loggerRes -and $loggerRes.Failed) { $totalFailed += $loggerRes.Failed }
if ($guiButtonRes -and $guiButtonRes.Failed) { $totalFailed += $guiButtonRes.Failed }
if ($guiUserOpsRes -and $guiUserOpsRes.Failed) { $totalFailed += $guiUserOpsRes.Failed }
if ($guiJpRes -and $guiJpRes.Failed) { $totalFailed += $guiJpRes.Failed }

$allLogs = @()
if ($cryptoRes -and $cryptoRes.Log) { $allLogs += $cryptoRes.Log }
if ($vaultRes -and $vaultRes.Log) { $allLogs += $vaultRes.Log }
if ($utilsRes -and $utilsRes.Log) { $allLogs += $utilsRes.Log }
if ($guiRes -and $guiRes.Log) { $allLogs += $guiRes.Log }
if ($loggerRes -and $loggerRes.Log) { $allLogs += $loggerRes.Log }
if ($guiButtonRes -and $guiButtonRes.Log) { $allLogs += $guiButtonRes.Log }
if ($guiUserOpsRes -and $guiUserOpsRes.Log) { $allLogs += $guiUserOpsRes.Log }
if ($guiJpRes -and $guiJpRes.Log) { $allLogs += $guiJpRes.Log }

Write-Host "`n--- Execution Logs ---" -ForegroundColor Yellow
foreach ($log in $allLogs) {
    if ($log -and $log.StartsWith("[PASS]")) {
        Write-Host $log -ForegroundColor Green
    } elseif ($log) {
        Write-Host $log -ForegroundColor Red
    }
}

$summaryColor = if ($totalFailed -eq 0) { "Green" } else { "Red" }
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " SUMMARY: Passed: $totalPassed | Failed: $totalFailed " -ForegroundColor $summaryColor
Write-Host "==========================================" -ForegroundColor Cyan

if ($totalFailed -gt 0) {
    exit 1
} else {
    exit 0
}
