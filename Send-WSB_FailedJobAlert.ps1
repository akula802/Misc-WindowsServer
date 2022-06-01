# Script to post a message to Slack when the Windows Server Backup (WSB) job finishes AND FAILS
# Uses SendGrid with a hard-coded API key, this could absolutely be done better but met an immediate need

# Based on an event log trigger on each server
# Log: Apps & Services \ Microsoft \ Windows \ Backup \ Operational
# Event ID: 5
# Event Level: Error
# Event Source: Backup
# Event text: The backup operation that started at %date has failed with the following error code: %error


# Define the Send-Alert function
Function Send-Alert() {
    [CmdletBinding()]
    Param(
        #[stirng]$To,
        #[string]$From,
        [String]$Subject,
        [string]$Body
    ) # End param

    # Do the things
    Try
        {
            $Error.Clear()

            # Define the credential object
            $username = "YoUr-SeNdGrId-UsEr"
            $password = ConvertTo-SecureString 'yOuR-SeNdGrId-aPi-KeY-GoEs-HeRe' -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($username, $password)

            # Define the message
            $alertRecipient = 'alert-recipient@your-domain.com'
            $alertFrom = 'backup-alerts@your-domain.com'
            $subjectLine = $subject
            $MsgBody = $body

            # Send the message
            Send-MailMessage -To $alertRecipient -From $alertFrom -Subject $subjectLine -Body $MsgBody -SmtpServer "smtp.sendgrid.net" -Port 587 -Credential $credential -UseSSL

            # State the obvious
            Write-Host Alert was posted to Slack.
            return
        }

    Catch
        {
            Write-Host Something bad happened trying to post the alert.
            Write-Host $Error
            return
        }


} # End function Send-Alert


# Get the event details and double-check
$lastFailedBackupEvent = Get-WinEvent -ProviderName "Microsoft-Windows-Backup" | `
    Select-Object TimeCreated, ID, ProviderName, LevelDisplayName, Message | `
    Where-Object{$_.Id -eq "5"} | Select-Object -First 1


# Testing this additional verification, leave commented out
#if (!($lastFailedBackupEvent)) { Write-Host No event found ; exit }


# Build a date-time comparison
$timestamp = Get-Date
$limit = $timestamp.AddHours(-1)


# Compare event creation time to now
$eventTimestamp = $lastFailedBackupEvent.TimeCreated
if ($eventTimestamp -gt $limit)
    {
        # Event was triggered within $limit, event is legit so build the message params
        $hostname = Hostname
        $subjectMsg = "WSB backup job FAILED on $hostname"
        $bodyMsg = "The WSB job on $hostname failed at: $eventTimestamp.`r`n`r`n $lastFailedBackupEvent.Message"

        # Finally, post the message
        Send-Alert -Subject $subjectMsg -Body $bodyMsg

        # Nothing left to do, exit
        exit

    } # End if

else
    {
        # Something is wrong, the event was triggered but the event verification here failed
        # For now, script does nothing in this case
        # The morning backup check will be the verifier

        # Nothing to do
        exit
    }
