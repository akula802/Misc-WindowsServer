# Script to reset the Network Location Awareness service (nlasvc) if NetConnectionProfile != Domain Authenticated
# When non-DC guests come online before the DC on a host, they sometimes flip to Public or Private, disrupting services
# Setting the nlasvc service to Delayed Start can help, as can setting startup delays on non-DC guests
# I use this script through an RMM monitor



# Initial steps
$Error.Clear()


# Get the network categories for all adapters
$profile = (Get-Netconnectionprofile | Select-Object NetworkCategory).NetworkCategory

if ($profile -contains "Public")
    {
        try
            {
                # Restart service
                Stop-Service nlasvc -Force
                Start-Service nlasvc

                # Verify service is running
                $status = (Get-Service nlasvc | Select-Object Status).Status
                if ($status -ne "Running")
                    {
                        Write-Host The Network Location Awareness service failed to start.
                        exit
                    }

            } # End try block

        catch
            {
                # Failed to restart service
                Write-Host Failed to restart the Network Location Awareness service.
                Write-Host $Error
                exit
            } # End catch block

    # Everything went well
    $profileAfter = (Get-Netconnectionprofile | Select-Object NetworkCategory).NetworkCategory
    if ($profileAfter -contains "Public")
        {
            Write-Host There is still an interface with a Public network category!
            exit
        } # End sub-if block

    else
        {
            Write-Host Public network category detected! Successfully restarted NLA service and corrected the issue.
            exit
        } # End sub-else block


    } # End main if block


else
    {
        Write-Host Nothing to do. Network category is not Public. Exiting...
    }
