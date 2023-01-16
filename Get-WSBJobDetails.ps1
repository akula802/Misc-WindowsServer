# Check the status of the last Windows Server Backup
# Write the details to an event log, that can be ingested with a SIEM or monitored with an RMM tool
# This is intended to run as a scheduled task with a service account, on each server using WSB


# Preflight items if applicable
$hostname = hostname



# Check to see if there is a WSB policy configured
Try {
    $backup_policy = Get-WBPolicy

    if (!($backup_policy.Schedule)) {
        $final_summary = "The Windows Backup feature is installed, but there is no backup job configured on this server ($hostname)."
        # Script now jumps to 'write to event log' section
    }

    else {

        # There does seem to be a backup job configured
        # Get some details about the backup job

        # Get the necessary objects to start with
        $backup_summary = Get-WBSummary
        $last_backup_details = Get-WBJob -Previous 1


        # What local volumes (if any) does the backup job protect?
        if ($backup_policy.VolumesToBackup) {
            $protected_volumes = ($backup_policy.VolumesToBackup | Select-Object MountPath | Where-Object {$_.MountPath -ne ''}).MountPath
        }
        else {
            $protected_volumes = "None"
        }


        # Are there any VMs backing up on this server?
        if ($backup_policy.ComponentsToBackup) {
            $protected_VMs = ""
            ForEach ($component in $backup_policy.ComponentsToBackup) {
                $protected_VMs += $backup_policy.ComponentsToBackup.VMname + " "
            }
        }
        else {
            $protected_VMs = "None"
        }


        # Is the backup BMR-able?
        $bare_metal_recoverable = $backup_policy.BMR
        #$system_state_backed_up = $backup_policy.SystemState


        # Where is the backup being sent?
        if ($backup_policy.BackupTargets.Label) {
            # Backup destination is a local disk
            $last_successful_backup_destination = $backup_policy.BackupTargets.Label
        }
        else {
            # Backup destination is a NAS share
            $last_successful_backup_destination = $backup_summary.LastSuccessfulBackupTargetPath
        }


        # How did the last backup job go?
        $last_backup_timestamp = $last_backup_details.EndTime
        if ($backup_summary.LastBackupResultHR -eq 0) {
            $last_backup_job_status = "Success"
        }
        else {
            $last_backup_job_status = "Failed"
        }


        # How many backups do we have available at the destination?
        $number_of_backups_available = $backup_summary.NumberOfVersions

        # When will the next backup run?
        $next_scheduled_backup_time = $backup_policy.Schedule




# Construct the final summary, leave unindented because here-strings are weird
$final_summary = @"
Hostname: $hostname
Protected Volumes: $protected_volumes
Protected VMs = $protected_VMs
Bare-Metal Recoverable: $bare_metal_recoverable
Backup Target: $last_successful_backup_destination
Last Backup Timestamp: $last_backup_timestamp
Last Backup Job Status: $last_backup_job_status
Number of Backups Available: $number_of_backups_available
Next Scheduled Backup Time: $next_scheduled_backup_time
"@

    
    } # End main else

} # End main Try


Catch {
    $final_summary = "There is no Windows Backup job configured for this server ($hostname). The feature is not installed."
}





# Print the final summary to the console
Write-Host `r`n$final_summary`r`n



# Write the final summary to the event log
Try {

    $error.Clear()
    if ([system.diagnostics.eventlog]::SourceExists("LTService") -eq $true) {
        Write-EventLog -LogName Application -Source "LTService" -EntryType Information -EventId 103  -Message $final_summary -Category 1 #-ErrorAction SilentlyContinue
    }

    else {
        New-EventLog -LogName Application -Source "LTService"
        Write-EventLog -LogName Application -Source "LTService" -EntryType Information -EventId 103  -Message $final_summary -Category 1
    }
} # End Try

Catch {
    Write-Host Failed to write to the event log. Error:
    Write-Host $error
}
