<#
.SYNOPSIS
    Retrieves Active Directory user account expiration dates using raw accountExpires attribute
    
.DESCRIPTION
    This script queries AD users and retrieves their account expiration dates using the 
    raw accountExpires attribute (FileTime format). This is an alternative approach that
    provides direct access to the underlying AD attribute with manual conversion.
    Use this if AccountExpirationDate property doesn't work in your environment.
    
.PARAMETER ExportPath
    Path where the CSV report will be saved. Default: C:\Reports
    
.PARAMETER IncludeDisabled
    Include disabled accounts in the report. Default: $false (only enabled accounts)
    
.PARAMETER SearchBase
    Specific OU to search. If not provided, searches entire domain
    
.EXAMPLE
    .\Get-ADUserExpirationDates-RawAttribute.ps1
    Retrieves all enabled users with their expiration dates
    
.EXAMPLE
    .\Get-ADUserExpirationDates-RawAttribute.ps1 -IncludeDisabled -ExportPath "C:\Temp"
    Retrieves all users (including disabled) and exports to C:\Temp
    
.EXAMPLE
    .\Get-ADUserExpirationDates-RawAttribute.ps1 -SearchBase "OU=Contractors,DC=ad,DC=example,DC=com"
    Retrieves users only from the Contractors OU
    
.NOTES
    Author: Matan Alon
    Created: 2024-12-09
    Version: 1.0
    
    Requirements:
    - Active Directory PowerShell module
    - Read permissions on Active Directory
    
    Technical Notes:
    - Uses raw accountExpires attribute (Integer8/FileTime format)
    - Value of 0 or 9223372036854775807 means "never expires"
    - Manually converts FileTime to DateTime using [DateTime]::FromFileTime()
    
    Security: Read-only operation, no modifications made to AD
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({
        if (!(Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
        $true
    })]
    [string]$ExportPath = "C:\Reports",
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeDisabled,
    
    [Parameter(Mandatory=$false)]
    [string]$SearchBase = "OU=Contractors,DC=ad,DC=example,DC=com"
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Start transcript for logging
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$transcriptPath = Join-Path $ExportPath "Get-ADUserExpirationDates-RawAttribute-Log-$timestamp.txt"
Start-Transcript -Path $transcriptPath

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "AD User Account Expiration Date Report (Raw Attribute Method)" -ForegroundColor Cyan
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

try {
    # Verify AD module is available
    Write-Host "[CHECK] Verifying Active Directory module..." -ForegroundColor Yellow
    if (!(Get-Module -ListAvailable -Name ActiveDirectory)) {
        throw "Active Directory module is not installed. Please install RSAT tools."
    }
    
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "[OK] Active Directory module loaded successfully" -ForegroundColor Green
    Write-Host ""
    
    # Build filter based on parameters
    if ($IncludeDisabled) {
        $filter = "*"
        Write-Host "[INFO] Including both enabled and disabled accounts" -ForegroundColor Cyan
    } else {
        $filter = {Enabled -eq $true}
        Write-Host "[INFO] Including only enabled accounts" -ForegroundColor Cyan
    }
    
    # Build parameters for Get-ADUser
    $adParams = @{
        Filter = $filter
        SearchBase = $SearchBase
        Properties = @(
            'accountExpires',  # Raw attribute name
            'EmailAddress',
            'UserPrincipalName',
            'DistinguishedName',
            'Description',
            'Manager',
            'WhenCreated',
            'Department',
            'Title',
            'LastLogonDate',
            'PasswordLastSet',
            'Enabled'
        )
    }
    
    Write-Host "[INFO] Searching in OU: $SearchBase" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "[QUERY] Retrieving users from Active Directory..." -ForegroundColor Yellow
    Write-Host "[INFO] Using raw 'accountExpires' attribute (FileTime format)" -ForegroundColor Cyan
    
    # Query AD users
    $users = Get-ADUser @adParams
    
    Write-Host "[OK] Retrieved $($users.Count) users" -ForegroundColor Green
    Write-Host ""
    
    # Constants for "never expires" values
    $NEVER_EXPIRES_VALUE_1 = 0
    $NEVER_EXPIRES_VALUE_2 = 9223372036854775807  # Max Int64 value
    
    # Process users and create report
    Write-Host "[PROCESS] Processing user data and converting FileTime values..." -ForegroundColor Yellow
    
    $report = $users | ForEach-Object {
        # Parse DN to extract immediate child OU (matching existing contractor script)
        $dnParts = $_.DistinguishedName -split ','
        $ouParts = $dnParts | Where-Object { $_ -like 'OU=*' }
        $childOU = if ($ouParts.Length -gt 0) { $ouParts[0] -replace '^OU=', '' } else { "N/A" }
        
        # Get user description
        $description = if ($_.Description) { $_.Description } else { "No Description" }
        
        # Get manager name if exists (matching existing contractor script)
        $managerName = "No Manager"
        if ($_.Manager) {
            try {
                $managerUser = Get-ADUser -Identity $_.Manager -Properties DisplayName
                $managerName = if ($managerUser.DisplayName) { $managerUser.DisplayName } else { $managerUser.Name }
            } catch {
                $managerName = "Manager Info Unavailable"
            }
        }
        
        # Convert accountExpires (FileTime) to DateTime
        $expirationDate = $null
        $neverExpires = $false
        
        if ($_.accountExpires -eq $NEVER_EXPIRES_VALUE_1 -or 
            $_.accountExpires -eq $NEVER_EXPIRES_VALUE_2 -or
            $_.accountExpires -eq $null) {
            $neverExpires = $true
            $expirationDate = $null
        } else {
            try {
                # Convert FileTime to DateTime
                $expirationDate = [DateTime]::FromFileTime($_.accountExpires)
            } catch {
                # If conversion fails, treat as never expires
                Write-Warning "Failed to convert accountExpires for $($_.SamAccountName): $($_.accountExpires)"
                $neverExpires = $true
                $expirationDate = $null
            }
        }
        
        # Get account expiration date (matching existing contractor script format)
        $endDate = if ($expirationDate) {
            $expirationDate.ToString("yyyy-MM-dd HH:mm:ss")
        } else {
            "No End Date"
        }
        
        # Get account creation date
        $creationDate = if ($_.WhenCreated) {
            $_.WhenCreated.ToString("yyyy-MM-dd HH:mm:ss")
        } else {
            "Unknown"
        }
        
        # Determine expiration status
        $expirationStatus = if ($neverExpires) {
            "NEVER EXPIRES"
        } elseif ($expirationDate -lt (Get-Date)) {
            "EXPIRED"
        } elseif ($expirationDate -lt (Get-Date).AddDays(30)) {
            "EXPIRING SOON"
        } else {
            "ACTIVE"
        }
        
        # Calculate days until expiration
        $daysUntilExpiration = if ($expirationDate -and !$neverExpires) {
            if ($expirationDate -gt (Get-Date)) {
                [math]::Round(($expirationDate - (Get-Date)).TotalDays, 0)
            } else {
                [math]::Round(((Get-Date) - $expirationDate).TotalDays, 0) * -1  # Negative for expired
            }
        } else {
            $null
        }
        
        [PSCustomObject]@{
            Name = $_.Name
            Email = $_.EmailAddress
            UserPrincipalName = $_.UserPrincipalName
            ChildOU = $childOU
            Description = $description
            Manager = $managerName
            EndDate = $endDate
            CreationDate = $creationDate
            RawAccountExpires = $_.accountExpires  # Include raw value for troubleshooting
            ExpirationStatus = $expirationStatus
            DaysUntilExpiration = $daysUntilExpiration
            Enabled = $_.Enabled
            Department = $_.Department
            Title = $_.Title
            LastLogonDate = $_.LastLogonDate
            PasswordLastSet = $_.PasswordLastSet
            DistinguishedName = $_.DistinguishedName
        }
    }
    
    Write-Host "[OK] Processed $($report.Count) user records" -ForegroundColor Green
    Write-Host ""
    
    # Export to CSV (matching existing contractor naming convention, with RawAttribute suffix for differentiation)
    $csvPath = Join-Path $ExportPath "ContractorsActiveusers-RawAttribute-$(Get-Date -Format 'yyyyMMdd HHmm').csv"
    $report | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "[EXPORT] Report exported to:" -ForegroundColor Green
    Write-Host "         $csvPath" -ForegroundColor White
    Write-Host ""
    
    # Display summary statistics
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "SUMMARY STATISTICS" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    
    $stats = @{
        Total = $report.Count
        NeverExpires = ($report | Where-Object {$_.ExpirationStatus -eq "NEVER EXPIRES"}).Count
        Active = ($report | Where-Object {$_.ExpirationStatus -eq "ACTIVE"}).Count
        ExpiringSoon = ($report | Where-Object {$_.ExpirationStatus -eq "EXPIRING SOON"}).Count
        Expired = ($report | Where-Object {$_.ExpirationStatus -eq "EXPIRED"}).Count
    }
    
    Write-Host "Total Users:              $($stats.Total)" -ForegroundColor White
    Write-Host "Never Expires:            $($stats.NeverExpires)" -ForegroundColor Gray
    Write-Host "Active (>30 days):        $($stats.Active)" -ForegroundColor Green
    Write-Host "Expiring Soon (<30 days): $($stats.ExpiringSoon)" -ForegroundColor Yellow
    Write-Host "Already Expired:          $($stats.Expired)" -ForegroundColor Red
    Write-Host ""
    
    # Technical details
    Write-Host "TECHNICAL DETAILS:" -ForegroundColor Cyan
    Write-Host "- Used raw 'accountExpires' attribute" -ForegroundColor Gray
    Write-Host "- FileTime values converted to DateTime" -ForegroundColor Gray
    Write-Host "- Never expires values: 0 or 9223372036854775807" -ForegroundColor Gray
    Write-Host ""
    
    # Show users expiring soon if any
    if ($stats.ExpiringSoon -gt 0) {
        Write-Host "USERS EXPIRING IN NEXT 30 DAYS:" -ForegroundColor Yellow
        Write-Host "-" * 80 -ForegroundColor Yellow
        $report | Where-Object {$_.ExpirationStatus -eq "EXPIRING SOON"} |
            Sort-Object EndDate |
            Format-Table Name, Email, EndDate, DaysUntilExpiration -AutoSize
    }
    
    # Show expired users if any
    if ($stats.Expired -gt 0) {
        Write-Host "EXPIRED ACCOUNTS:" -ForegroundColor Red
        Write-Host "-" * 80 -ForegroundColor Red
        $report | Where-Object {$_.ExpirationStatus -eq "EXPIRED"} |
            Sort-Object EndDate -Descending |
            Format-Table Name, Email, EndDate, DaysUntilExpiration -AutoSize
    }
    
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
    Write-Host "=" * 80 -ForegroundColor Cyan
    
    # Return the report object
    return $report
}
catch {
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Red
    Write-Host "ERROR OCCURRED" -ForegroundColor Red
    Write-Host "=" * 80 -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host ""
    
    if ($_.Exception.Message -like "*Access is denied*") {
        Write-Host "SOLUTION: Run PowerShell as administrator or verify you have read permissions to Active Directory" -ForegroundColor Yellow
    } elseif ($_.Exception.Message -like "*Cannot find an object*") {
        Write-Host "SOLUTION: Verify the SearchBase OU path is correct" -ForegroundColor Yellow
    }
    
    exit 1
}
finally {
    Stop-Transcript
    Write-Host ""
    Write-Host "Full log saved to: $transcriptPath" -ForegroundColor Cyan
}

