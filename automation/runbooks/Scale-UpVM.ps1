<#
.SYNOPSIS
    Scales up an Azure VM to the next SKU tier during sustained high CPU.
.DESCRIPTION
    Triggered when CPU exceeds 95% for 30+ minutes. Identifies the next
    available VM size in the same family and resizes. Requires a brief
    reboot during resize.
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

Write-Output "=== Scale-UpVM ==="
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

# ---------- Size upgrade map (common D-series progression) ----------
$sizeUpgradeMap = @{
    'Standard_D2s_v5'  = 'Standard_D4s_v5'
    'Standard_D4s_v5'  = 'Standard_D8s_v5'
    'Standard_D8s_v5'  = 'Standard_D16s_v5'
    'Standard_D2s_v4'  = 'Standard_D4s_v4'
    'Standard_D4s_v4'  = 'Standard_D8s_v4'
    'Standard_D8s_v4'  = 'Standard_D16s_v4'
    'Standard_D2s_v3'  = 'Standard_D4s_v3'
    'Standard_D4s_v3'  = 'Standard_D8s_v3'
    'Standard_D8s_v3'  = 'Standard_D16s_v3'
    'Standard_B2s'     = 'Standard_B4ms'
    'Standard_B4ms'    = 'Standard_B8ms'
    'Standard_B2ms'    = 'Standard_B4ms'
}

try {
    $vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
    $currentSize = $vm.HardwareProfile.VmSize
    Write-Output "Current size: $currentSize"

    # Find next size
    $targetSize = $sizeUpgradeMap[$currentSize]

    if ([string]::IsNullOrWhiteSpace($targetSize)) {
        Write-Warning "No upgrade path defined for $currentSize. Checking available sizes..."
        # Fall back: find next larger size in the same family available in the region
        $availableSizes = Get-AzVMSize -ResourceGroupName $resourceGroupName -VMName $vmName |
            Sort-Object NumberOfCores
        $currentCores = ($availableSizes | Where-Object { $_.Name -eq $currentSize }).NumberOfCores
        $targetSize = ($availableSizes |
            Where-Object { $_.NumberOfCores -gt $currentCores -and $_.Name -like "$($currentSize.Substring(0, $currentSize.Length - 3))*" } |
            Select-Object -First 1).Name

        if ([string]::IsNullOrWhiteSpace($targetSize)) {
            Write-Error "No suitable upgrade size found for $currentSize."
            exit 1
        }
    }

    # Verify target size is available in the region
    $regionSizes = Get-AzVMSize -Location $vm.Location | Select-Object -ExpandProperty Name
    if ($targetSize -notin $regionSizes) {
        Write-Error "Target size $targetSize is not available in $($vm.Location)."
        exit 1
    }

    Write-Output "Scaling from $currentSize to $targetSize (VM will reboot)..."
    $vm.HardwareProfile.VmSize = $targetSize
    Update-AzVM -ResourceGroupName $resourceGroupName -VM $vm

    Write-Output "VM resized to $targetSize successfully."
    Write-Output "Remediation completed successfully."
} catch {
    Write-Error "Scale-up failed: $_"
    exit 1
}
