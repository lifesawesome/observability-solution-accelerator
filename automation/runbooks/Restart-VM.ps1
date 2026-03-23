<#
.SYNOPSIS
    Gracefully restarts an Azure VM after prolonged heartbeat loss.
.DESCRIPTION
    Triggered when heartbeat is lost for >15 minutes. Attempts a graceful
    restart via Restart-AzVM. If the VM is already deallocated, starts it.
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

Write-Output "=== Restart-VM ==="
Write-Output "VM: $vmName | RG: $resourceGroupName | Sub: $subscriptionId"

# ---------- Authenticate ----------
try {
    Connect-AzAccount -Identity | Out-Null
    Set-AzContext -SubscriptionId $subscriptionId | Out-Null
    Write-Output "Authenticated via managed identity."
} catch {
    Write-Error "Failed to authenticate: $_"
    exit 1
}

# ---------- Check VM status ----------
try {
    $vmStatus = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Status
    $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code

    Write-Output "Current power state: $powerState"

    switch ($powerState) {
        'PowerState/deallocated' {
            Write-Output "VM is deallocated. Starting VM..."
            Start-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
            Write-Output "VM started successfully."
        }
        'PowerState/stopped' {
            Write-Output "VM is stopped. Starting VM..."
            Start-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
            Write-Output "VM started successfully."
        }
        'PowerState/running' {
            Write-Output "VM is running but heartbeat lost. Restarting..."
            Restart-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
            Write-Output "VM restarted successfully."
        }
        default {
            Write-Warning "Unexpected power state: $powerState. Attempting restart..."
            Restart-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
            Write-Output "VM restart attempted."
        }
    }

    # Wait and verify heartbeat restoration
    Write-Output "Waiting 60 seconds for heartbeat to restore..."
    Start-Sleep -Seconds 60

    $vmStatus = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Status
    $newState = ($vmStatus.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code
    Write-Output "Post-restart power state: $newState"
    Write-Output "Remediation completed successfully."
} catch {
    Write-Error "VM restart failed: $_"
    exit 1
}
