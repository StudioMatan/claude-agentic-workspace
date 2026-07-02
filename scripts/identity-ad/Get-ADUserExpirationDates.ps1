<#
.SYNOPSIS
    Retrieves Active Directory user account expiration dates using AccountExpirationDate property
    
.DESCRIPTION
    This script queries AD users and retrieves their account expiration dates using the 
    AccountExpirationDate property (recommended modern approach). It supports filtering
    by enabled status, specific OUs, and exporting results to CSV.
    
.PARAMETER ExportPath
    Path where the CSV report will be saved. Default: C:\Reports
    
.PARAMETER IncludeDisabled
    Include disabled accounts in the report. Default: $false (only enabled accounts)
    
.PARAMETER SearchBase
    Specific OU to search. If not provided, searches entire domain
    
.EXAMPLE
    .\Get-ADUserExpirationDates.ps1
    Retrieves all enabled users with their expiration dates
    
.EXAMPLE
    .\Get-ADUserExpirationDates.ps1 -IncludeDisabled -ExportPath "C:\Temp"
    Retrieves all users (including disabled) and exports to C:\Temp
    
.EXAMPLE
    .\Get-ADUserExpirationDates.ps1 -SearchBase "OU=Contractors,DC=ad,DC=example,DC=com"
    Retrieves users only from the Contractors OU
    
.NOTES
    Author: Matan Alon
    Created: 2024-12-09
    Version: 1.0
    
    Requirements:
    - Active Directory PowerShell module
    - Read permissions on Active Directory
    
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
    [string]$SearchBase
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Start transcript for logging
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$transcriptPath = Join-Path $ExportPath "Get-ADUserExpirationDates-Log-$timestamp.txt"
Start-Transcript -Path $transcriptPath

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "AD User Account Expiration Date Report" -ForegroundColor Cyan
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
        Properties = @(
            'AccountExpirationDate',
            'EmailAddress',
            'Department',
            'Title',
            'Manager',
            'Created',
            'Modified',
            'LastLogonDate',
            'PasswordLastSet',
            'Enabled'
        )
    }
    
    if ($SearchBase) {
        $adParams['SearchBase'] = $SearchBase
        Write-Host "[INFO] Searching in OU: $SearchBase" -ForegroundColor Cyan
    } else {
        Write-Host "[INFO] Searching entire domain" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "[QUERY] Retrieving users from Active Directory..." -ForegroundColor Yellow
    
    # Query AD users
    $users = Get-ADUser @adParams
    
    Write-Host "[OK] Retrieved $($users.Count) users" -ForegroundColor Green
    Write-Host ""
    
    # Process users and create report
    Write-Host "[PROCESS] Processing user data..." -ForegroundColor Yellow
    
    $report = $users | ForEach-Object {
        # Get manager name if exists
        $managerName = if ($_.Manager) {
            try {
                (Get-ADUser -Identity $_.Manager).Name
            } catch {
                "Unable to retrieve"
            }
        } else {
            "Not set"
        }
        
        # Determine expiration status
        $expirationStatus = if ($_.AccountExpirationDate) {
            if ($_.AccountExpirationDate -lt (Get-Date)) {
                "EXPIRED"
            } elseif ($_.AccountExpirationDate -lt (Get-Date).AddDays(30)) {
                "EXPIRING SOON"
            } else {
                "ACTIVE"
            }
        } else {
            "NEVER EXPIRES"
        }
        
        # Calculate days until expiration
        $daysUntilExpiration = if ($_.AccountExpirationDate -and $_.AccountExpirationDate -gt (Get-Date)) {
            [math]::Round(($_.AccountExpirationDate - (Get-Date)).TotalDays, 0)
        } elseif ($_.AccountExpirationDate -and $_.AccountExpirationDate -lt (Get-Date)) {
            [math]::Round(((Get-Date) - $_.AccountExpirationDate).TotalDays, 0) * -1  # Negative for expired
        } else {
            $null
        }
        
        [PSCustomObject]@{
            Name = $_.Name
            Username = $_.SamAccountName
            EmailAddress = $_.EmailAddress
            Enabled = $_.Enabled
            Department = $_.Department
            Title = $_.Title
            Manager = $managerName
            AccountExpirationDate = $_.AccountExpirationDate
            ExpirationStatus = $expirationStatus
            DaysUntilExpiration = $daysUntilExpiration
            Created = $_.Created
            LastLogonDate = $_.LastLogonDate
            PasswordLastSet = $_.PasswordLastSet
            DistinguishedName = $_.DistinguishedName
        }
    }
    
    Write-Host "[OK] Processed $($report.Count) user records" -ForegroundColor Green
    Write-Host ""
    
    # Export to CSV
    $csvPath = Join-Path $ExportPath "ADUserExpirationDates-$timestamp.csv"
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
    
    # Show users expiring soon if any
    if ($stats.ExpiringSoon -gt 0) {
        Write-Host "USERS EXPIRING IN NEXT 30 DAYS:" -ForegroundColor Yellow
        Write-Host "-" * 80 -ForegroundColor Yellow
        $report | Where-Object {$_.ExpirationStatus -eq "EXPIRING SOON"} | 
            Sort-Object AccountExpirationDate | 
            Format-Table Name, Username, AccountExpirationDate, DaysUntilExpiration -AutoSize
    }
    
    # Show expired users if any
    if ($stats.Expired -gt 0) {
        Write-Host "EXPIRED ACCOUNTS:" -ForegroundColor Red
        Write-Host "-" * 80 -ForegroundColor Red
        $report | Where-Object {$_.ExpirationStatus -eq "EXPIRED"} | 
            Sort-Object AccountExpirationDate -Descending | 
            Format-Table Name, Username, AccountExpirationDate, DaysUntilExpiration -AutoSize
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
    }
    
    exit 1
}
finally {
    Stop-Transcript
    Write-Host ""
    Write-Host "Full log saved to: $transcriptPath" -ForegroundColor Cyan
}


