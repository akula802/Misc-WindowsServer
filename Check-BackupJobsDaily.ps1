# Script to check a NAS share for Windows Server Backups - alerting if timestamp is older than 12 hours
# Runs M-F as a scheduled task, verifying the previous night's backups
# Uses SendGrid with a hard-coded API key, this could absolutely be done better but met an IMMEDIATE need
# If you use this script, do it better, for the sake of humanity


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

# Define initial variables
$Error.Clear()
$today = Get-Date
$limit = $today.AddHours(-12)


# Create the password SecureString file (leave commented out until password changes, then run just this while logged in as $userName - see line 63)
#Read-Host "Enter password" -AsSecureString | ConvertFrom-SecureString | Out-File -FilePath "C:\ProgramData\Scripts\12-log-old.txt"


# Create the credential object using the password in the SecureString file
# Note that the SecureString file is named in a way that obfuscates its real purpose - thuper thecurity
$userName = "yourDomain\scriptUser"
$sikritt = Get-Content -Path "C:\ProgramData\Scripts\12-log-old.txt" | ConvertTo-SecureString
[pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($userName, $sikritt)


# Connect to the NAS share, exit if unable
Try
    {
        $Error.Clear()
        If (!(Get-PSDrive -Name "NAS" -ErrorAction SilentlyContinue))
            {
                New-PSDrive -Name "NAS" -PSProvider FileSystem -Root "\\192.168.69.69\Backups" -Credential $credObject -ErrorAction Stop | Out-Null
            }
        else
            {
                Remove-PSDrive -Name "NAS"
                New-PSDrive -Name "NAS" -PSProvider FileSystem -Root "\\192.168.69.69\Backups" -Credential $credObject | Out-Null
            }     
    }
Catch
    {
        # Build the 'no-connection' alert message parameters
        $noShareAccessSubj = "Backups check: Unable to connect to NAS share."
        $noShareAccessBody = "Check NAS credentials used by this script, and NAS connectivity.`r`nError message encountered:`r`n$error"
        
        # Post the script failure to the alert channel
        Send-Alert -Subject $noShareAccessSubj -Body $noShareAccessBody
        #Write-Host $noShareAccessBody

        # Script cannot proceed from here, so exit
        exit
    }


# Create an empty array to store all the backup folder paths
# In this case, the folders are named like "WB_ServerName"
$folders = @()
$folders += Get-ChildItem -Path "NAS:\" -Filter "WB_*"


# Create an empty array to store any problem backup items
$problemBackups = @()


# Loop through the backup path folders to get the timestamps of the 'WindowsImageBackup\<serverName>' subfolders in each
# These are the folders that will have a recent timestamp if the backup job runs
ForEach ($folder in $folders)
    {
        # Define the path to the folder we need to look into
        $path = $folder.FullName.Trim() + '\WindowsImageBackup'

        # Check if any of the subfolders were last touched outside of the $limit
        # If so, add to the $problemBackups array
        $problemBackups += Get-ChildItem -Path $path -ErrorAction SilentlyContinue | `
            Select-Object | Where-Object {$_.LastWriteTime -lt $limit}

    }  # End foreach $folder loop



# If there are any WindowsImageBackup\<serverName> folders with a timestmap older than $limit, there is a problem
# This means the backup job did not run
# Here, first check to see if there are NO problem backups
If (!($problemBackups))
    {
        # Build the 'no-alert' message parameters
        $summaryFinal = "Backup Check: No Problems Detected"
        $bodyFinal = "WSB backup jobs have all run to completion last night."
        
        # Send the 'no-alert' message to Slack
        Send-Alert -Subject $summaryFinal -Body $bodyFinal

        # Nothing else to do at this point, exit now
        exit

    } # End if

# Then, if there ARE problem backups, post the details of each to Slack
Else
    {
        ForEach ($backup in $problemBackups)
            {
                # Get the backup file's last write time and format a string for reporting
                $subString1 = ((($backup.FullName).ToString()).TrimStart('\\192.168.69.69\Backups\'))
                $substring2 = $substring1.Split("\")[2]
                $lastBackupTime = $backup.LastWriteTime

                # Build the alert parameters
                $subjProblemBackups = "Server Backups: Problem Detected!"
                #$bodyProblemBackups = Write-Host Backup job for $subString2 last ran at: $backup.LastWriteTime 6>&1  #This is a way to get Write-Host to a variable, leaving for future reference
                $bodyProblemBackups = "Backup job for $subString2 last ran at: $lastBackupTime"

                # Send the alert to Slack
                Send-Alert -Subject $subjProblemBackups -Body $bodyProblemBackups

            } # End ForEach $backup loop

    } # End else


# Clean up
Remove-PSDrive -Name "NAS"
exit
