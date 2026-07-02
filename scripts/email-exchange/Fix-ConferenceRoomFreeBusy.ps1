<#
.SYNOPSIS
    Fix conference room Free/Busy publishing issues.
.DESCRIPTION
    Diagnoses and fixes the common issue where conference rooms don't show Busy/Free status
    because Free/Busy publishing is disabled on the calendar folder. Can diagnose a single
    room or scan all rooms in the organization.
.PARAMETER RoomName
    Name or partial name of the conference room to fix (e.g., "Room-A")
.PARAMETER ScanAll
    Switch to scan and fix all conference rooms in the organization
.PARAMETER DiagnoseOnly
    Switch to only diagnose without making changes
.EXAMPLE
    .\Fix-ConferenceRoomFreeBusy.ps1 -RoomName "Room-A"
    Fixes the Room-A conference room
.EXAMPLE
    .\Fix-ConferenceRoomFreeBusy.ps1 -ScanAll
    Scans and fixes all conference rooms with publishing disabled
.EXAMPLE
    .\Fix-ConferenceRoomFreeBusy.ps1 -RoomName "Room-B" -DiagnoseOnly
    Only checks Room-B without making changes
.NOTES
    Author: Matan Alon
    Security: Read-only by default, makes changes only when needed

    Common Issue: Conference rooms show "Always Busy" or no availability
    Root Cause: Free/Busy Publishing is disabled on the calendar folder
    Solution: Enable publishing with AvailabilityOnly detail level
    (AvailabilityOnly = users see Busy/Free, never meeting titles or organizers)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$RoomName,

    [Parameter(Mandatory=$false)]
    [switch]$ScanAll,

    [Parameter(Mandatory=$false)]
    [switch]$DiagnoseOnly
)

$ErrorActionPreference = "Stop"

# Connect to Exchange Online if not already connected
try {
    $conn = Get-ConnectionInformation -ErrorAction SilentlyContinue
    if (-not $conn) {
        Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
        Connect-ExchangeOnline -ShowBanner:$false
    }
}
catch {
    Connect-ExchangeOnline -ShowBanner:$false
}

Write-Host "`n==============================================================" -ForegroundColor Cyan
Write-Host "CONFERENCE ROOM FREE/BUSY FIX UTILITY" -ForegroundColor Yellow
Write-Host "==============================================================" -ForegroundColor Cyan

# Function to process a single room
function Process-Room {
    param(
        [Parameter(Mandatory=$true)]
        $Room,

        [Parameter(Mandatory=$false)]
        [bool]$FixIssues = $true
    )

    $roomEmail = $Room.PrimarySmtpAddress
    $calPath = $roomEmail + ":\Calendar"

    Write-Host "`nRoom: $($Room.DisplayName)" -ForegroundColor White
    Write-Host "   Email: $roomEmail" -ForegroundColor Gray

    # Check publishing status
    try {
        $cal = Get-MailboxCalendarFolder -Identity $calPath -ErrorAction Stop

        Write-Host "   Publishing Enabled: " -NoNewline
        if ($cal.PublishEnabled) {
            Write-Host "YES" -ForegroundColor Green
            $needsFix = $false
        } else {
            Write-Host "NO (Issue found)" -ForegroundColor Red
            $needsFix = $true
        }

        Write-Host "   Detail Level: $($cal.DetailLevel)" -ForegroundColor Gray

        # Get room statistics
        $stats = Get-MailboxFolderStatistics -Identity $roomEmail -FolderScope All
        $calendar = $stats | Where-Object { $_.FolderType -eq "Calendar" }
        $inbox = $stats | Where-Object { $_.FolderType -eq "Inbox" }

        Write-Host "   Calendar Items: $($calendar.ItemsInFolder)" -ForegroundColor Gray
        if ($inbox.ItemsInFolder -gt 100) {
            Write-Host "   Inbox Items: $($inbox.ItemsInFolder) " -NoNewline -ForegroundColor Yellow
            Write-Host "(High - should be near 0, indicates AutoAccept backlog)" -ForegroundColor Yellow
        } else {
            Write-Host "   Inbox Items: $($inbox.ItemsInFolder)" -ForegroundColor Gray
        }

        # Fix if needed
        if ($needsFix -and $FixIssues) {
            Write-Host "`n   FIXING: Enabling Free/Busy publishing..." -ForegroundColor Yellow

            Set-MailboxCalendarFolder -Identity $calPath -PublishEnabled $true -DetailLevel AvailabilityOnly

            # Verify
            $calAfter = Get-MailboxCalendarFolder -Identity $calPath
            if ($calAfter.PublishEnabled) {
                Write-Host "   SUCCESS - publishing now enabled" -ForegroundColor Green
                return $true
            } else {
                Write-Host "   FAILED to enable publishing" -ForegroundColor Red
                return $false
            }
        } elseif ($needsFix -and -not $FixIssues) {
            Write-Host "   Issue detected but not fixed (DiagnoseOnly mode)" -ForegroundColor Yellow
            return $false
        }

        return $true

    } catch {
        Write-Warning "   Failed to process room: $_"
        return $false
    }
}

# Main execution
if ($ScanAll) {
    # Scan all conference rooms
    Write-Host "`nScanning all conference rooms..." -ForegroundColor Cyan

    $allRooms = Get-Mailbox -RecipientTypeDetails RoomMailbox -ResultSize Unlimited | Sort-Object DisplayName

    Write-Host "Found $($allRooms.Count) conference rooms`n" -ForegroundColor White

    $fixedCount = 0
    $alreadyOkCount = 0
    $failedCount = 0

    foreach ($room in $allRooms) {
        $result = Process-Room -Room $room -FixIssues (-not $DiagnoseOnly)

        if ($result) {
            if ((Get-MailboxCalendarFolder -Identity "$($room.PrimarySmtpAddress):\Calendar").PublishEnabled) {
                $alreadyOkCount++
            } else {
                $fixedCount++
            }
        } else {
            $failedCount++
        }
    }

    Write-Host "`n==============================================================" -ForegroundColor Cyan
    Write-Host "SUMMARY" -ForegroundColor Yellow
    Write-Host "==============================================================" -ForegroundColor Cyan
    Write-Host "Total Rooms: $($allRooms.Count)" -ForegroundColor White
    Write-Host "Already OK: $alreadyOkCount" -ForegroundColor Green
    if (-not $DiagnoseOnly) {
        Write-Host "Fixed: $fixedCount" -ForegroundColor Yellow
        Write-Host "Failed: $failedCount" -ForegroundColor Red
    } else {
        Write-Host "Need Fixing: $failedCount" -ForegroundColor Yellow
    }

} elseif ($RoomName) {
    # Process specific room
    Write-Host "`nSearching for room: $RoomName..." -ForegroundColor Cyan

    $room = Get-Mailbox -Filter "Name -like '*$RoomName*' -or DisplayName -like '*$RoomName*' -or Alias -like '*$RoomName*'" -RecipientTypeDetails RoomMailbox

    if (-not $room) {
        Write-Host "Room not found" -ForegroundColor Red
        Write-Host "`nTip: Try searching with a partial name (e.g., 'Room-A' instead of full name)" -ForegroundColor Gray
        exit 1
    }

    if ($room.Count -gt 1) {
        Write-Host "Found multiple rooms:" -ForegroundColor Yellow
        $room | Format-Table DisplayName, PrimarySmtpAddress -AutoSize
        Write-Host "Using first match...`n" -ForegroundColor Gray
        $room = $room[0]
    }

    $result = Process-Room -Room $room -FixIssues (-not $DiagnoseOnly)

    if ($result) {
        Write-Host "`nRoom is configured correctly" -ForegroundColor Green
    }

} else {
    # No parameters provided
    Write-Host "`nERROR: Must specify either -RoomName or -ScanAll" -ForegroundColor Red
    Write-Host "`nExamples:" -ForegroundColor Yellow
    Write-Host "  .\Fix-ConferenceRoomFreeBusy.ps1 -RoomName 'Room-A'" -ForegroundColor Gray
    Write-Host "  .\Fix-ConferenceRoomFreeBusy.ps1 -ScanAll" -ForegroundColor Gray
    Write-Host "  .\Fix-ConferenceRoomFreeBusy.ps1 -RoomName 'Room-B' -DiagnoseOnly" -ForegroundColor Gray
    exit 1
}

Write-Host "`nScript Complete" -ForegroundColor Green

if (-not $DiagnoseOnly) {
    Write-Host "`nNote: Changes may take 5-10 minutes to propagate." -ForegroundColor Cyan
    Write-Host "   Users may need to restart Outlook or clear cache (delete .ost file)." -ForegroundColor Gray
}
