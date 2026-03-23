<#
.SYNOPSIS
    Rotates a Key Vault secret that is near expiry.
.DESCRIPTION
    Triggered by a Key Vault expiry warning alert. Generates a new
    cryptographically random secret value, creates a new version in
    Key Vault, and disables the old version.
.NOTES
    Auth: Automation Account system-assigned managed identity
    Runtime: PowerShell 7.2+
    Requires: Key Vault Secrets Officer role on the target vault
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

$resourceId = $payload.data.essentials.alertTargetIDs[0]

# Parse Key Vault info from resource ID
# Expected: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{name}
$parts          = $resourceId -split '/'
$subscriptionId = $parts[2]
$vaultName      = $parts[-1]

# Secret name from alert custom properties or description
$secretName = $payload.data.essentials.description -replace '.*secret:\s*', '' -replace '\s.*', ''
if ([string]::IsNullOrWhiteSpace($secretName)) {
    $secretName = $payload.data.alertContext.condition.allOf[0].dimensions |
        Where-Object { $_.name -eq 'SecretName' } |
        Select-Object -ExpandProperty value -First 1
}

if ([string]::IsNullOrWhiteSpace($secretName)) {
    Write-Error "Unable to determine secret name from alert payload."
    exit 1
}

Write-Output "=== Rotate-Secret ==="
Write-Output "Vault: $vaultName | Secret: $secretName"

# ---------- Authenticate ----------
try {
    Connect-AzAccount -Identity | Out-Null
    Set-AzContext -SubscriptionId $subscriptionId | Out-Null
    Write-Output "Authenticated via managed identity."
} catch {
    Write-Error "Failed to authenticate: $_"
    exit 1
}

# ---------- Generate new secret ----------
try {
    # Get current secret to preserve tags and content type
    $currentSecret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $secretName
    $contentType = $currentSecret.ContentType
    $tags = $currentSecret.Tags

    # Generate 64-character cryptographically random secret
    $bytes = [byte[]]::new(48)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $newSecretValue = [Convert]::ToBase64String($bytes)
    $secureValue = ConvertTo-SecureString -String $newSecretValue -AsPlainText -Force

    # Set new secret version with 90-day expiry
    $expiry = (Get-Date).AddDays(90)
    $setParams = @{
        VaultName   = $vaultName
        Name        = $secretName
        SecretValue = $secureValue
        Expires     = $expiry
        ContentType = $contentType
        Tag         = $tags
    }
    $newVersion = Set-AzKeyVaultSecret @setParams

    Write-Output "New secret version created: $($newVersion.Version)"
    Write-Output "Expires: $expiry"

    # Disable the old version
    if ($currentSecret.Version -ne $newVersion.Version) {
        Update-AzKeyVaultSecret -VaultName $vaultName -Name $secretName `
            -Version $currentSecret.Version -Enable $false | Out-Null
        Write-Output "Previous version $($currentSecret.Version) disabled."
    }

    Write-Output "Remediation completed successfully."
} catch {
    Write-Error "Secret rotation failed: $_"
    exit 1
}
