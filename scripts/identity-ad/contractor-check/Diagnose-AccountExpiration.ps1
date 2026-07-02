# Diagnostic Script - Check What Expiration Data Actually Exists in AD
# Shows exactly what is stored in contractor accounts, so you can pick the right
# reporting method (AccountExpirationDate property vs raw accountExpires attribute).

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TargetOU = "OU=Contractors,DC=ad,DC=example,DC=com"
)

Import-Module ActiveDirectory

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "AD Account Expiration Diagnostic Tool" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

Write-Host "[1] Searching for users in: $TargetOU" -ForegroundColor Yellow
Write-Host ""

# Get first 5 enabled users to examine
$sampleUsers = Get-ADUser -SearchBase $TargetOU -Filter {Enabled -eq $true} -Properties * | Select-Object -First 5

if ($sampleUsers.Count -eq 0) {
    Write-Host "[ERROR] No enabled users found in OU" -ForegroundColor Red
    exit
}

Write-Host "[2] Found $($sampleUsers.Count) sample users. Examining expiration attributes..." -ForegroundColor Green
Write-Host ""

foreach ($user in $sampleUsers) {
    Write-Host "=" * 80 -ForegroundColor Gray
    Write-Host "USER: $($user.Name) ($($user.SamAccountName))" -ForegroundColor White
    Write-Host "-" * 80 -ForegroundColor Gray

    Write-Host "AccountExpirationDate:      " -NoNewline -ForegroundColor Cyan
    Write-Host $user.AccountExpirationDate

    Write-Host "accountExpires (raw):       " -NoNewline -ForegroundColor Cyan
    Write-Host $user.accountExpires

    # Try to convert accountExpires if it exists
    if ($user.accountExpires -and $user.accountExpires -ne 0 -and $user.accountExpires -ne 9223372036854775807) {
        try {
            $converted = [DateTime]::FromFileTime($user.accountExpires)
            Write-Host "accountExpires (converted): " -NoNewline -ForegroundColor Cyan
            Write-Host $converted -ForegroundColor Green
        } catch {
            Write-Host "accountExpires (converted): " -NoNewline -ForegroundColor Cyan
            Write-Host "FAILED TO CONVERT" -ForegroundColor Red
        }
    } else {
        Write-Host "accountExpires (converted): " -NoNewline -ForegroundColor Cyan
        Write-Host "Never expires or not set" -ForegroundColor Yellow
    }

    Write-Host "Description:                " -NoNewline -ForegroundColor Cyan
    Write-Host $user.Description

    Write-Host "WhenCreated:                " -NoNewline -ForegroundColor Cyan
    Write-Host $user.WhenCreated

    Write-Host "Enabled:                    " -NoNewline -ForegroundColor Cyan
    Write-Host $user.Enabled

    Write-Host ""
}

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "SUMMARY & RECOMMENDATIONS" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Count users with vs without expiration dates
$allContractors = Get-ADUser -SearchBase $TargetOU -Filter {Enabled -eq $true} -Properties AccountExpirationDate, accountExpires

$withAccountExpDate = ($allContractors | Where-Object { $_.AccountExpirationDate -ne $null }).Count
$withAccountExpires = ($allContractors | Where-Object { $_.accountExpires -ne $null -and $_.accountExpires -ne 0 -and $_.accountExpires -ne 9223372036854775807 }).Count
$withNoExpiration = $allContractors.Count - [Math]::Max($withAccountExpDate, $withAccountExpires)

Write-Host "Total Enabled Contractors: $($allContractors.Count)" -ForegroundColor White
Write-Host ""
Write-Host "With AccountExpirationDate: $withAccountExpDate" -ForegroundColor $(if ($withAccountExpDate -gt 0) { "Green" } else { "Red" })
Write-Host "With accountExpires (raw):  $withAccountExpires" -ForegroundColor $(if ($withAccountExpires -gt 0) { "Green" } else { "Red" })
Write-Host "With NO expiration set:     $withNoExpiration" -ForegroundColor Yellow
Write-Host ""

if ($withAccountExpDate -eq 0 -and $withAccountExpires -eq 0) {
    Write-Host "[!] FINDING: No contractor accounts have expiration dates set!" -ForegroundColor Red
    Write-Host ""
    Write-Host "POSSIBLE REASONS:" -ForegroundColor Yellow
    Write-Host "  1. Expiration dates are not being set when contractors are created"
    Write-Host "  2. Expiration dates might be tracked in a different attribute (custom attribute)"
    Write-Host "  3. Expiration is managed outside of AD (HR system, Excel, etc.)"
    Write-Host ""
    Write-Host "RECOMMENDATION:" -ForegroundColor Yellow
    Write-Host "  Check if a custom attribute (extensionAttribute1-15) is used for tracking"
    Write-Host "  contractor end dates. The check below examines all extension attributes."
    Write-Host ""
} elseif ($withAccountExpDate -eq 0 -and $withAccountExpires -gt 0) {
    Write-Host "[+] FINDING: accountExpires is populated, but AccountExpirationDate is not" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "RECOMMENDATION:" -ForegroundColor Green
    Write-Host "  Use the Raw Attribute script (Get-ADUserExpirationDates-RawAttribute.ps1)"
    Write-Host ""
} elseif ($withAccountExpDate -gt 0) {
    Write-Host "[+] FINDING: AccountExpirationDate is working properly" -ForegroundColor Green
    Write-Host ""
    Write-Host "RECOMMENDATION:" -ForegroundColor Green
    Write-Host "  Use the standard script (Get-ADUserExpirationDates.ps1)"
    Write-Host "  The issue might be elsewhere - check for filtering or export problems"
    Write-Host ""
}

# Check for custom attributes that might contain expiration data
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "CHECKING FOR CUSTOM ATTRIBUTES (extensionAttribute1-15)" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

$customAttrs = @()
foreach ($i in 1..15) {
    $attrName = "extensionAttribute$i"
    $sampleValue = $sampleUsers[0].$attrName
    if ($sampleValue) {
        Write-Host "extensionAttribute$i : $sampleValue" -ForegroundColor Green
        $customAttrs += $attrName
    }
}

if ($customAttrs.Count -eq 0) {
    Write-Host "No custom extension attributes found in sample users" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "Found populated custom attributes. These might contain contractor end dates." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Diagnostic Complete" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan
