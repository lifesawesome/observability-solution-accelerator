<#
.SYNOPSIS
    Restarts a stopped Windows service on an Azure VM or Arc-enabled server.
.DESCRIPTION
    Triggered by an Azure Monitor alert via Action Group webhook. Parses the
    alert payload to identify the target VM and service, then issues a
    Run Command to restart the service. Results are written to output for
    Log Analytics ingestion.
.NOTES
    Auth: Automation Account system-assigned managed identity
    Runtime: PowerShell 7.2+
#>

param(
    [Parameter(Mandatory = $false)]
    [object]$WebhookData
)

# ---------- Parse alert payload ----------
if ($null -eq $WebhookData) {
    Write-Error "No webhook data received. This runbook must be triggered by an Azure Monitor alert."
    exit 1
}

$payload = if ($WebhookData.RequestBody) {
    $WebhookData.RequestBody | ConvertFrom-Json
} else {
    $WebhookData | ConvertFrom-Json
}

$alertContext = $payload.data.alertContext
$resourceId  = $payload.data.essentials.alertTargetIDs[0]

# Extract VM info from resource ID
$parts             = $resourceId -split '/'
$subscriptionId    = $parts[2]
$resourceGroupName = $parts[4]
$vmName            = $parts[-1]

# Service name from alert custom properties or default
$serviceName = $payload.data.essentials.description -replace '.*service:\s*', '' -replace '\s.*', ''
if ([string]::IsNullOrWhiteSpace($serviceName)) {
    $serviceName = $alertContext.SearchResults.tables.rows[0] | Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($serviceName)) {
    Write-Error "Unable to determine service name from alert payload."
    exit 1
}

Write-Output "=== Restart-WindowsService ==="
Write-Output "VM: $vmName | RG: $resourceGroupName | Service: $serviceName"

# ---------- Authenticate ----------
try {
    Connect-AzAccount -Identity | Out-Null
    Set-AzContext -SubscriptionId $subscriptionId | Out-Null
    Write-Output "Authenticated via managed identity."
} catch {
    Write-Error "Failed to authenticate: $_"
    exit 1
}

# ---------- Restart service via Run Command ----------
$script = @"
try {
    `$svc = Get-Service -Name '$serviceName' -ErrorAction Stop
    if (`$svc.Status -ne 'Running') {
        Restart-Service -Name '$serviceName' -Force -ErrorAction Stop
        Start-Sleep -Seconds 10
        `$svc = Get-Service -Name '$serviceName'
        Write-Output "Service '$serviceName' status: `$(`$svc.Status)"
    } else {
        Write-Output "Service '$serviceName' is already running."
    }
} catch {
    Write-Error "Failed to restart service: `$_"
    exit 1
}
"@

try {
    $result = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName `
        -VMName $vmName `
        -CommandId 'RunPowerShellScript' `
        -ScriptString $script

    $output = $result.Value | Where-Object { $_.Code -eq 'ComponentStatus/StdOut/succeeded' } |
        Select-Object -ExpandProperty Message
    $errors = $result.Value | Where-Object { $_.Code -eq 'ComponentStatus/StdErr/succeeded' } |
        Select-Object -ExpandProperty Message

    Write-Output "Run Command output: $output"
    if ($errors) { Write-Warning "Run Command stderr: $errors" }

    Write-Output "Remediation completed successfully."
} catch {
    Write-Error "Run Command failed: $_"
    exit 1
}
