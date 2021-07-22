# Script to parse the MegaRaid Storage Manager (MSM) configuration file
# Intended to detect MSM instances that were not updated to use SendGrid for alerting


# Clear the $error variable
$Error.Clear()



# File location variables
$pathRoot = "C:\Program Files (x86)\MegaRAID Storage Manager\MegaMonitor"
$filename = "config-current.xml"
$xmlFileOriginal = "$pathRoot\$fileName"
$xmlFile = "$pathRoot\config-current-COPY.xml"



# Check for the presence of the file, and make a copy
if (!(Test-Path -Path $xmlFileOriginal))
    {
        Write-Host The XML file is missing!
        exit
    }
else
    {
        try
            {
                # Make a copy the file
                Copy-Item -Path $xmlFileOriginal -Destination $xmlFile -Force
                #Write-Host Made the copy of the config file for parsing.
            }
        catch
            {
                Write-Host Failed to make a copy of the file!
                exit
            }
    }



# Check the file for proper tagging
# If 
try
    {
        # Load the contents of the XML file (which is not yet ready for parsing) into memory       
        $xmlFileContents = Get-Content -Path $xmlFile

        # If the last line is not a closing XML tag, add one
        $lastLine = Get-Content -Path $xmlFile | Select-Object -Last 1 -ErrorAction SilentlyContinue
        if ($lastline -ne "</xml>")
            {
                #Write-Host The XML file is missing the closing tag!
                Add-Content -Path $xmlFile -Value "</xml>" -Encoding UTF8
                #Write-Host Added the closing tag to the XML file.

                # Now make the first line into a proper opening XML tag, replacing the prolog
                # But first reload the file contents into memory, since it was altered above
                $xmlFileContents = Get-Content -Path $xmlFile
                if ($xmlFileContents[0] -ne "<xml>")
                    {
                        $xmlFileContents[0] = "<xml>"
                        $xmlFileContents | Set-Content -Path $xmlFile -Encoding UTF8
                        #Write-Host Replaced the prolog on line 0 with a proper opening tag.
                    }

            }
        <#else
            {
                Write-Host The XML file is properly tagged.
            }#>
    }
catch
    {
        Write-Host Unable to read the XML file!
        exit
    }



# Read the file into memory
try
    {
        $error.Clear()
        [xml]$configFile = Get-Content -Path $xmlFile #-ErrorAction SilentlyContinue
    }
catch
    {
        Write-Host The XML file appears to be damaged!
        Write-Host $error
        exit
    }



# Collect the info from the XML file's contents
$emailServer = $configFile.xml.'monitor-config'.actions.email.servername
# $emailPort = $configFile.xml.'monitor-config'.actions.email.port
# $emailUsername = $configFile.xml.'monitor-config'.actions.email.username
# $emailPassword = $configFile.xml.'monitor-config'.actions.email.password
# $emailFrom = $configFile.xml.'monitor-config'.actions.email.sender
# $emailTo = $configFile.xml.'monitor-config'.actions.email.'email-target'


# Check configured email server
if ($emailServer -ne "smtp.sendgrid.net")
    {
        $configError = "FAIL: This MSM instance is configured to use $emailServer"
        Write-Host $configError
        # Update the file here? Or just make a ticket? To update the file, need the SG password from LP.
        # Also restart the 'MSMFramework' service when done
    }
else
    {
        Write-Host SUCCESS: This MSM instance is configured to use $emailServer
        exit
    }
