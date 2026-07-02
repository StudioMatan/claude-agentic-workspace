# Fix CSV Date Formats
# Detects day-first (DD/MM/YYYY) dates in an expiration CSV and rewrites them as
# ISO 8601 (YYYY-MM-DD) so downstream scripts parse them consistently.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Source,

    [Parameter(Mandatory=$false)]
    [string]$Destination = ($Source -replace '\.csv$', '_CLEAN.csv')
)

$data = Import-Csv $Source
$cleanData = @()

foreach ($row in $data) {
    # Get the date string
    $dateStr = if ($row.EndDate) { $row.EndDate }
               elseif ($row.ExpirationDate) { $row.ExpirationDate }
               elseif ($row.'End Date') { $row.'End Date' }
               else { $null }

    if ($dateStr) {
        # Try to fix "DD/MM/YYYY" format
        if ($dateStr -match "^(\d{1,2})/(\d{1,2})/(\d{4})") {
            # Day > 12 implies DD/MM format (unambiguous)
            if ([int]$matches[1] -gt 12) {
                # Convert DD/MM/YYYY to YYYY-MM-DD
                $newDate = "$($matches[3])-$($matches[2])-$($matches[1])"
                $row.EndDate = $newDate
            }
        }
    }
    $cleanData += $row
}

$cleanData | Export-Csv $Destination -NoTypeInformation
Write-Host "Created clean CSV at: $Destination"
