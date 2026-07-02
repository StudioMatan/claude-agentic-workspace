<#
.SYNOPSIS
    Sets Active Directory user account expiration dates using .NET AccountManagement API

.DESCRIPTION
    Updates account expiration dates for AD users based on a CSV file or a default date.
    Flexible identity resolution (UPN / email / SAM / Name) and multi-format date parsing.

.PARAMETER CsvPath
    Path to CSV file containing user identities and expiration dates

.PARAMETER DefaultExpirationDate
    Optional default date to use if a CSV row has no date

.PARAMETER Domain
    AD domain FQDN to connect to

.PARAMETER LogDirectory
    Folder for the timestamped update log

.NOTES
    Author: Matan Alon
    Uses the .NET AccountManagement API to bypass AD Module permission issues.
    WRITE operation - review the CSV and run against test users first.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, ParameterSetName="FromCSV")]
    [string]$CsvPath,

    [Parameter(Mandatory=$false)]
    [string]$DefaultExpirationDate,

    [Parameter(Mandatory=$false)]
    [string]$Domain = "ad.example.com",

    [Parameter(Mandatory=$false)]
    [string]$LogDirectory = "C:\Reports"
)

if (!(Test-Path $LogDirectory)) { New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null }
$LogPath = Join-Path $LogDirectory "UpdateLog-$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-Log {
    param([string]$Message, [string]$Color="White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMsg = "[$timestamp] $Message"
    Write-Host $Message -ForegroundColor $Color
    $logMsg | Out-File -FilePath $LogPath -Append
}

$defaultDateObj = $null
if ($DefaultExpirationDate) {
    try {
        $defaultDateObj = Get-Date $DefaultExpirationDate
        # AD expiration is "end of day": set to midnight of the NEXT day so the account
        # remains usable through the stated end date.
        $defaultDateObj = $defaultDateObj.Date.AddDays(1)
    } catch {
        Write-Log "Invalid default date format: $DefaultExpirationDate" "Red"
        exit
    }
}

try {
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
    $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $Domain)
} catch {
    Write-Log "Failed to connect to AD Context: $($_.Exception.Message)" "Red"
    exit
}

$usersToProcess = @()
if (Test-Path $CsvPath) {
    $csvData = Import-Csv $CsvPath
    foreach ($row in $csvData) {
        $user = $null
        $searchType = ""

        if ($row.UserPrincipalName) { $user = $row.UserPrincipalName; $searchType = "UserPrincipalName" }
        elseif ($row.Email) { $user = $row.Email; $searchType = "UserPrincipalName" }
        elseif ($row.EmailAddress) { $user = $row.EmailAddress; $searchType = "UserPrincipalName" }
        elseif ($row.SamAccountName) { $user = $row.SamAccountName; $searchType = "SamAccountName" }
        elseif ($row.Name) { $user = $row.Name; $searchType = "Name" }

        $rowDate = $null
        if ($row.EndDate) { $rowDate = $row.EndDate }
        elseif ($row.ExpirationDate) { $rowDate = $row.ExpirationDate }
        elseif ($row.'End Date') { $rowDate = $row.'End Date' }
        elseif ($row.AccountExpires) { $rowDate = $row.AccountExpires }

        if ($user) {
            $usersToProcess += @{
                Identity = $user
                Type = $searchType
                SpecificDate = $rowDate
            }
        }
    }
} else {
    Write-Log "CSV file not found: $CsvPath" "Red"
    exit
}

foreach ($item in $usersToProcess) {
    $identity = $item.Identity
    $type = $item.Type
    $specificDateStr = $item.SpecificDate

    $targetDateToSet = $null

    if ($specificDateStr) {
        if ($specificDateStr -match "No End Date" -or $specificDateStr -match "Never") {
            Write-Log "SKIPPING ${identity}: CSV says '$specificDateStr'"
            continue
        } else {
            try {
                $d = Get-Date $specificDateStr -ErrorAction Stop
                $targetDateToSet = $d.Date.AddDays(1)
            } catch {
                # Fallbacks for non-US locale exports (day-first formats)
                try {
                    $d = [DateTime]::ParseExact($specificDateStr.Split(" ")[0], "d/M/yyyy", [System.Globalization.CultureInfo]::InvariantCulture)
                    $targetDateToSet = $d.Date.AddDays(1)
                } catch {
                    try {
                        $d = [DateTime]::ParseExact($specificDateStr.Split(" ")[0], "dd/MM/yyyy", [System.Globalization.CultureInfo]::InvariantCulture)
                        $targetDateToSet = $d.Date.AddDays(1)
                    } catch {
                        Write-Log "SKIPPING ${identity}: Invalid date format '$specificDateStr'" "Red"
                        continue
                    }
                }
            }
        }
    } elseif ($defaultDateObj) {
        $targetDateToSet = $defaultDateObj
    } else {
        Write-Log "SKIPPING ${identity}: No date available"
        continue
    }

    try {
        $userPrincipal = $null

        if ($type -eq "UserPrincipalName") {
            $userPrincipal = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($ctx, [System.DirectoryServices.AccountManagement.IdentityType]::UserPrincipalName, $identity)
        } elseif ($type -eq "SamAccountName") {
            $userPrincipal = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($ctx, [System.DirectoryServices.AccountManagement.IdentityType]::SamAccountName, $identity)
        } else {
            $userPrincipal = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($ctx, [System.DirectoryServices.AccountManagement.IdentityType]::Name, $identity)
        }

        if ($userPrincipal) {
            if ($targetDateToSet) {
                $oldDate = if ($userPrincipal.AccountExpirationDate) { $userPrincipal.AccountExpirationDate } else { "Never" }
                $userPrincipal.AccountExpirationDate = $targetDateToSet
                $userPrincipal.Save()
                Write-Log "SUCCESS: $($userPrincipal.SamAccountName) | $oldDate -> $targetDateToSet" "Green"
            }
        } else {
            Write-Log "NOT FOUND: User '$identity' not found in AD" "Red"
        }
    } catch {
        Write-Log "ERROR: Failed to update $identity. $($_.Exception.Message)" "Red"
    }
}
