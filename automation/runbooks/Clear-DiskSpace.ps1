<#
.SYNOPSIS
    Clears disk space on a VM when free space drops below threshold.
.DESCRIPTION
    Triggered by a disk-space-low alert. Connects to the target VM via
    Run Command and removes temp files, compresses old logs, and clears
    Windows Update cache.
.NOTES
    Auth: Automation Account system-assigned managed identity
    Runtime: PowerShell 7.2+
#>

param(
    [Parameter(Mandatory = $false)]
    [object]$WebhookData
)

if ($null -eq $WebhookData) {
    Write-Error "No webhook data received."
    exit 1
}

$payload = if ($WebhookData.RequestBody) {
    $WebhookData.RequestBody | ConvertFrom-Json
} else {
    $WebhookData | ConvertFrom-Json
}

$resourceId        = $payload.data.essentials.alertTargetIDs[0]
$parts             = $resourceId -split '/'
$subscriptionId    = $parts[2]
$resourceGroupName = $parts[4]
$vmName            = $parts[-1]

Write-Output "=== Clear-DiskSpace ==="
Write-Output "VM: $vmName | RG: $resourceGroupName"

# ---------- Authenticate ----------
try {
    Connect-AzAccount -Identity | Out-Null
    Set-AzContext -SubscriptionId $subscriptionId | Out-Null
    Write-Output "Authenticated via managed identity."
} catch {
    Write-Error "Failed to authenticate: $_"
    exit 1
}

# ---------- Cleanup script ----------
$cleanupScript = @'
$freed = 0

# 1. Clear Windows Temp
$tempPaths = @(
    "$env:TEMP",
    "$env:SystemRoot\Temp",
    "$env:SystemRoot\Logs\CBS"
)
foreach ($p in $tempPaths) {
    if (Test-Path $p) {
        $before = (Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $after = (Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $freed += ($before - $after)
    }
}

# 2. Clear Windows Update cache
$wuPath = "$env:SystemRoot\SoftwareDistribution\Download"
if (Test-Path $wuPath) {
    $before = (Get-ChildItem $wuPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    Remove-Item "$wuPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    $after = (Get-ChildItem $wuPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $freed += ($before - $after)
}

# 3. Compress logs older than 14 days
$logPaths = @("C:\inetpub\logs", "C:\Logs")
foreach ($logPath in $logPaths) {
    if (Test-Path $logPath) {
        Get-ChildItem $logPath -Filter "*.log" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-14) -and $_.Extension -ne '.zip' } |
            ForEach-Object {
                Compress-Archive -Path $_.FullName -DestinationPath "$($_.FullName).zip" -Force -ErrorAction SilentlyContinue
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            }
    }
}

# 4. Report disk space after cleanup
$disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"
$freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
$freePct = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1)
$freedMB = [math]::Round($freed / 1MB, 2)

Write-Output "Freed: ${freedMB} MB | C: drive now ${freeGB} GB free (${freePct}%)"
'@

try {
    $result = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName `
        -VMName $vmName `
        -CommandId 'RunPowerShellScript' `
        -ScriptString $cleanupScript

    $output = $result.Value | Where-Object { $_.Code -eq 'ComponentStatus/StdOut/succeeded' } |
        Select-Object -ExpandProperty Message
    Write-Output "Cleanup result: $output"
    Write-Output "Remediation completed successfully."
} catch {
    Write-Error "Run Command failed: $_"
    exit 1
}
