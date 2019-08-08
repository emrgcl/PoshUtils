<#
.SYNOPSIS
    Writes Log to specified file if not logs to a file under User temp.
.DESCRIPTION
    Writes Log to specified file if not logs to a file under User temp. Function also writes the log to the Verbose stream if -Verbose used.
.EXAMPLE
    PS C:\> Write-Log -LogFile c:\temp\mylog.txt -Message "Error Occured $($Error[0].Exception.Message)" -Tag "Script Start" -Level Error
    VERBOSE: [8/1/2019 7:21:13 AM][Error][EMREG-DSC][Script Start] Error Occured Cannot bind argument to parameter 'Message' because it is an empty string.
    
    The above example Writes the message to the LogFile specifed with the Level Type error and the Optional Tag used "ScriptStart"
.EXAMPLE
    PS C:\> Write-Log -Message "Script Started" -Tag "Script Start" -Level Info
    VERBOSE: [8/1/2019 7:22:43 AM][Info][EMREG-DSC][Script Start] Script Started
    
    The above example Writes the message ehich is the only require parameter. The file is save to users temp folder with the format Write-Log-yyyy-M-d.log
.INPUTS
    String
.OUTPUTS
    Output (if any)
.NOTES
    Author: Emre Güçlü
    Version: 1.0
    Release Date:1 August 2019
#>
function Write-Log {
    [CmdletBinding()]
    param (
        # setting Default path the User Temp.
        [Parameter(Mandatory=$true)]
        [String]$Message,
        [String]$LogFile="$($Env:Temp)\Write-Log-$(Get-Date -Format yyyy-M-d).log",
        [ValidateSet("Error","Warning","Info")] 
        [string]$Level="Info", 
        [string]$Tag 

    )
    
    if ($Tag) {
        $Log = "[$(Get-Date -Format G)][$Level][$($env:ComputerName)][$Tag] $Message"
    } else {
        $Log = "[$(Get-Date -Format G)][$Level] $Message"
    }
    $Log |  Out-File -FilePath $LogFile -Append
    Write-Verbose -Message  $Log
    
}


<#
.SYNOPSIS
    Copies files with retry support.
.DESCRIPTION
    Copies files with retry support.
.EXAMPLE
    PS C:\> Write-Log -LogFile c:\temp\mylog.txt -Message "Error Occured $($Error[0].Exception.Message)" -Tag "Script Start" -Level Error
    VERBOSE: [8/1/2019 7:21:13 AM][Error][EMREG-DSC][Script Start] Error Occured Cannot bind argument to parameter 'Message' because it is an empty string.
    
    The above example Writes the message to the LogFile specifed with the Level Type error and the Optional Tag used "ScriptStart"
.EXAMPLE
    PS C:\> Copy-Files -FilesToCopy $files -Destination $Destination -RetryCount 5 -RetryInterval 30 -Verbose
.INPUTS
    String
.OUTPUTS
    Output (if any)
.NOTES
    Author: Emre Güçlü
    Version: 1.0
    Release Date:1 August 2019
#>

Function Copy-Files {


    [CmdletBinding()]
    param(
    
        [string[]]$FilesToCopy,
        [string]$Destination,
        [int32]$RetryCount = 10,
        [int32]$RetryInterval = 60
    )
    
    #Setting Variables
    $TargetFolder = $env:COMPUTERNAME
    $TargetPath = "$Destination\$TargetFolder" 
    
    
    #Create the remote folder
    Try {
        New-PSDrive -Name CopyTarget -PSProvider FileSystem -Root $Destination -ErrorAction Stop | Out-Null
        if (!(Test-Path -Path $TargetPath)) {
            Write-Log -Message "Could Not Find $TargetPath Creating it."
            New-Item -Path "CopyTarget:\" -Name $TargetFolder -ItemType Directory -ErrorAction Stop | Out-Null
    
        }
    }
    Catch {
    
        Write-verbose -Message "Could not Create $TargetPath Exception Type: $($_.Exception.GetType().FullName), Message:$($_.Exception.Message)"
        $ErrorOccured = $true
        Throw
    
    }
    Finally {
    
        if (get-psdrive -Name CopyTarget) {
            Remove-PSDrive -Name CopyTarget | out-null
    
        }
    
    }
    
    #Copy Files
    Foreach ($File in $FilesToCopy) {
        $CurrentRetry = 1
    
        #Set targe tPath to test
        $TargetFile = "$TargetPath\$($file | split-path -Leaf )"
    
        do {
    
            if ($CurrentRetry -eq $RetryCount) {
    
                $Message = "Retry limit has reached after $RetryCount retries. Exiting script."
    
                Write-Log -Message $Message
                Throw $Message
    
            }
    
            Try {
                Write-Log -Message "Copying $File to to $TargetPath."
                #try copying
                Copy-Item -Path $File -Destination $TargetFile -Force -ErrorAction Stop
                Write-Log -Message "Copied $File to to $TargetPath after retrying $CurrentRetry times."
    
            }
            Catch {
    
                $ErrorOccured = $true
    
                Write-Log -Message "Retry Count: $CurrentRetry. Could not Copy $File to $TargetPath. $($_.Exception.GetType().FullName), Message:$($_.Exception.Message)"
                Write-Log -Message "Waiting for $RetryInterval Seconds." 
    
                # if error occurs sleep
                Start-Sleep -Seconds $RetryInterval | out-null
    
                ++$CurrentRetry
    
            }
            Finally {
    
                if (!$ErrorOccured) {
    
                    Write-Log -Message "Copied $File to to $TargetPath after retrying $CurrentRetry times."
    
                }
    
            }
    
        } 
    
        until (test-path -Path $TargetFile)
    
    }
}

<#
.SYNOPSIS
    Compresses files using System.IO.Compression.Zip type.
.DESCRIPTION
    Writes Log to specified file if not logs to a file under User temp. Function also writes the log to the Verbose stream if -Verbose used.

    INMPORTANT: System.IO.Compression.Zip type may not compress files over 4gb due to a limitation of .Net. 
.EXAMPLE
    $FileItems = (Get-ChildItem -Path C:\temp\compresstest\2GbLogs).FullName
    Compress-Files -FileItems $FileItems -zipFilePath 'c:\temp\compresstest\2gb.zip' -Verbose -compressionLevel Fastest
    

    VERBOSE: Size of Files to Zip: 11513.54 Mbs
    VERBOSE: Created zip: c:\temp\compresstest\1gb.zip
    VERBOSE: CompressionLevel: Optimal
    VERBOSE: Working on C:\temp\compresstest\1GbLogs\1.Log. File Size: 1151.35 Mbs
    VERBOSE: Updated zip: c:\temp\compresstest\1gb.zip, Added C:\temp\compresstest\1GbLogs\1.Log
    VERBOSE: Working on C:\temp\compresstest\1GbLogs\10.Log. File Size: 1151.35 Mbs
    VERBOSE: Updated zip: c:\temp\compresstest\1gb.zip, Added C:\temp\compresstest\1GbLogs\10.Log
    VERBOSE: Working on C:\temp\compresstest\1GbLogs\2.Log. File Size: 1151.35 Mbs
    VERBOSE: Updated zip: c:\temp\compresstest\1gb.zip, Added C:\temp\compresstest\1GbLogs\2.Log
    VERBOSE: Working on C:\temp\compresstest\1GbLogs\3.Log. File Size: 1151.35 Mbs
    VERBOSE: Updated zip: c:\temp\compresstest\1gb.zip, Added C:\temp\compresstest\1GbLogs\3.Log
    VERBOSE: Working on C:\temp\compresstest\1GbLogs\4.Log. File Size: 1151.35 Mbs
    VERBOSE: Updated zip: c:\temp\compresstest\1gb.zip, Added C:\temp\compresstest\1GbLogs\4.Log
    VERBOSE: Working on C:\temp\compresstest\1GbLogs\5.Log. File Size: 1151.35 Mbs
    VERBOSE: Updated zip: c:\temp\compresstest\1gb.zip, Added C:\temp\compresstest\1GbLogs\5.Log
    VERBOSE: Working on C:\temp\compresstest\1GbLogs\6.Log. File Size: 1151.35 Mbs
    VERBOSE: Updated zip: c:\temp\compresstest\1gb.zip, Added C:\temp\compresstest\1GbLogs\6.Log
    VERBOSE: Working on C:\temp\compresstest\1GbLogs\7.Log. File Size: 1151.35 Mbs
    VERBOSE: Updated zip: c:\temp\compresstest\1gb.zip, Added C:\temp\compresstest\1GbLogs\7.Log
    VERBOSE: Working on C:\temp\compresstest\1GbLogs\8.Log. File Size: 1151.35 Mbs
    VERBOSE: Updated zip: c:\temp\compresstest\1gb.zip, Added C:\temp\compresstest\1GbLogs\8.Log
    VERBOSE: Working on C:\temp\compresstest\1GbLogs\9.Log. File Size: 1151.35 Mbs
    VERBOSE: Updated zip: c:\temp\compresstest\1gb.zip, Added C:\temp\compresstest\1GbLogs\9.Log
    VERBOSE: Compression Duration = 400.0986761 Seconds
    VERBOSE: ZipFile = c:\temp\compresstest\1gb.zip Size: 288.29 Mbs
    VERBOSE: Compression Ratio : 40 Times
    VERBOSE: Compression Percent : 97%

    The above example compresses the files with the specified compression method passed to Compress-Files

.INPUTS
    String
.OUTPUTS
    Output (if any)
.NOTES
    Author: Emre Güçlü
    Version: 1.0
    Release Date:1 August 2019
    Support Note: System.IO.Compression.Zip type may not compress files over 4gb due to a limitation of .Net.  
#>

Function Compress-Files {
    [CmdletBinding()]
    Param(
        [string]$zipFilePath = 'c:\temp\compresstest\1gb.zip',
        [string[]]$FileItems,
        [ValidateSet("Optimal", "Fastest", "NoCompression")]
        [string]$compressionLevel
    )
    $Timer = Get-Date
    Add-Type -Assembly 'System.IO.Compression.FileSystem'
    $TotalFileSize = [Math]::Round((($FileItems | Get-ChildItem | Measure-Object -Property Length -Sum).Sum / 1mb), 2)
    Write-Log -Message "Size of Files to Zip: $TotalFileSize Mbs"
    #Create Empty zip
    try {
        $zip = [System.IO.Compression.ZipFile]::Open($zipFilePath, 'create')
    }
    Catch {
        Write-Log -Message "$($_.Exception.GetType().FullName), Message:$($_.Exception.Message)"
        $ErrorOccured = $true
        Throw
    }
    Finally {
        if ($ErrorOccured) {
            $Zip.Dispose()
        }
        else {
            Write-Log -Message "Created zip: $zipFilePath"
            $zip.dispose()
        }
    }
    
    #Set the Compression Level
    Write-Log -Message "CompressionLevel: $CompressionLevel"
    $compressionLevel = [System.IO.Compression.CompressionLevel]::($CompressionLevel)
    
    
    Foreach ($File in $FileItems) {
    
        Write-Log -Message "Working on $File. File Size: $([Math]::Round((($File | Get-ChildItem | Measure-Object -Property Length -Sum).Sum /1mb),2)) Mbs"
    
        try {
            #Open the zip file
            $zip = [System.IO.Compression.ZipFile]::Open($zipFilePath, 'update')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file, (Split-Path $file -Leaf), $compressionLevel) | out-null
        }
        catch {
    
            Write-Log -Message "$($_.Exception.GetType().FullName), Message:$($_.Exception.Message)"
            $ErrorOccured = $true
    
        }
        finally {
    
            if ($ErrorOccured) {
                $Zip.Dispose()
            }
            else {
                Write-Log -Message "Updated zip: $zipFilePath, Added $File"
                $zip.dispose()
    
            }
        }
    }
    
    Write-Log -Message "Compression Duration = $(((Get-Date) - $Timer).TotalSeconds) Seconds"
    Write-Log  -Message "ZipFile = $zipFilePath Size: $([Math]::Round((($zipFilePath | Get-ChildItem | Measure-Object -Property Length -Sum).Sum /1mb),2)) Mbs"
    Write-Log  -Message "Compression Ratio : $( [Math]::Round($TotalFileSize / (($zipFilePath | Get-ChildItem | Measure-Object -Property Length -Sum).Sum /1mb))) Times"
    
    Write-Log  -Message "Compression Percent : $([Math]::Round(100 - [Math]::Round((($zipFilePath | Get-ChildItem | Measure-Object -Property Length -Sum).Sum /1mb),2) / $TotalFileSize * 100))%"
    
}
    

