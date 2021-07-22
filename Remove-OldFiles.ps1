# Script to clean up old files in multiple specified directories, and report on disk space saved
# Below, old files are defined by $threshhold as >365 days since last modified


# Define the 'old file' threshhold, and the path to the backup files
$today = Get-Date
$threshhold = $today.AddDays(-365)
$backupsPaths = @("E:\First\Folder\", "D:\Second\Folder\")
#$backupsPath = "D:\Single\Folder\"  # Superseded by $backupsPaths above to allow for multiple folders
$numberOfFiles = 0
$spaceReclaimed = 0


ForEach ($path in $backupsPaths)
    {
        # Get / select the old backup files, defining the file extension and first part of file name, which is common to all
        $oldBackups = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | `
                        Select-Object | `
                        Where-Object {$_.LastWriteTime -lt $threshhold `
                        -and $_.Extension -like "*.cdr" `
                        -and $_.BaseName -Like "Backup_of_*" }


        # Loop through the old files and remove them
        ForEach ($file in $oldBackups)
            {
                $numberOfFiles ++
                $spaceReclaimed = $spaceReclaimed + ($file.Length / 1MB)
                Remove-Item $file -ErrorAction SilentlyContinue
            }


        $spaceReclaimed = [math]::Round($spaceReclaimed,2)
        Write-Host `r`nRemoved $numberOfFiles files, and reclaimed $spaceReclaimed MB in $path

    } #End Foreach loop

