Param(
    [Parameter(Mandatory = $true)]
    [string]$pathMasterXml = "",

    [Parameter(Mandatory = $true)]
    [string]$pathMaster = "",

    [Parameter(Mandatory = $true)]
    [string]$pathTargetXml = "",

    [Parameter(Mandatory = $true)]
    [string]$pathTarget = "",

    [Parameter(Mandatory = $false)]
    [int]$numberOfHashtables = 300
)

$folderMaster = Split-Path -Leaf $pathMaster
if ($folderMaster -like '*:\*') {
    $folderMaster = Split-Path -Leaf $pathMaster | % { $_.replace(":\", "") }
}

$folderTarget = Split-Path -Leaf $pathTarget
if ($folderTarget -like '*:\*') {
    $folderTarget = Split-Path -Leaf $pathTarget | % { $_.replace(":\", "") }
}

$dateTime = Get-Date -UFormat "%Y-%m-%d_%H-%M-%S"
$logFile = $folderMaster + '_vs_' + $folderTarget + '(' + $dateTime + ').log'

Start-Transcript -Path $logFile\\$logFile

Write-Host "Loading Master XML..."
[xml]$xmlMaster = Get-Content -Path $pathMasterXml
Write-Host "Done loading Master XML..."

$hashMaster = $null
$hashMaster = @()
For ($i = 0; $i -lt $numberOfHashtables; $i++) {
    $hashMaster += @{}
}

Measure-Command {
    $i = 0
    $totalMasterFiles = $xmlMaster.Files.File.Count
    Write-Host "Total files that need to be loaded into the hashtable: $totalMasterFiles"
    $xmlMaster.Files.File | <#Select-Object -First 500 | #>ForEach-Object {
        Write-Progress -Activity "Loading $numberOfHashtables hashtables with $totalMasterFiles files from master XML..." -Status "File $($i+1)" -PercentComplete (($i+1)/$totalMasterFiles*100)
        $hashMaster[$i % $numberOfHashtables] += @{$_.Path = $_.Hash}
        $i++
    }

    Write-Progress -Activity "Loading $numberOfHashtables hashtables with $totalMasterFiles files from master XML..." -Status "Ready" -Completed
}

Write-Host "Loading Target XML..."
[xml]$xmlTarget = Get-Content -Path $pathTargetXml
Write-Host "Done loading Target XML..."

$duplicatesFile = 'Duplicates-' + $folderMaster + '_vs_' + $folderTarget + '(' + $dateTime + ').ps1'
$targetHashIsNullFile = 'TargetHashNull-' + $folderMaster + '_vs_' + $folderTarget + '(' + $dateTime + ').log'
$differentFile = 'Different-' + $folderMaster + '_vs_' + $folderTarget + '(' + $dateTime + ').log'
$missingFile = 'Missing-' + $folderMaster + '_vs_' + $folderTarget + '(' + $dateTime + ').log'

$i = 0
$totalTargetFiles = $xmlTarget.Files.File.Count
Write-Host "Total files that need to be processed: $totalTargetFiles"

$xmlTarget.Files.File | ForEach-Object {
    Write-Progress -Activity "Processing $totalTargetFiles files..." -Status "File $($i+1)" -PercentComplete (($i+1)/$totalTargetFiles*100)

    $masterPath = $_.Path.Replace($pathTarget, $pathMaster)
    $tmp = $_.Path -replace "'", "''"
    $path = $tmp -replace "’", "'’"

    if (!$_.Hash)
    {
        Write-Output "[TargetHashIsNull] ""$($path)""" | Out-File -Append $logFile\\$targetHashIsNullFile
        return
    }

    for ($j = 0; $j -lt $numberOfHashtables; $j++) {
        $masterValue = $hashMaster[$j][$masterPath]
        if ($masterValue) {
            break
        }
    }

    if ($masterValue) {
        if ($masterValue -eq $_.Hash) {
            Write-Output "Remove-Item -Force –LiteralPath '$($path)'" | Out-File -Append $logFile\\$duplicatesFile
        }
        else {
            Write-Output "Remove-Item -Force –LiteralPath '$($path)'" | Out-File -Append $logFile\\$differentFile
        }
    }
    else {
        $tmp = $masterPath -replace "'", "''"
        $mpath = $tmp -replace "’", "'’"
        Write-Output "Move-Item –LiteralPath '$($path)' -Destination '$($mpath)'" | Out-File -Append $logFile\\$missingFile
    }

    $i++
}

Write-Progress -Activity "Processing $totalTargetFiles files..." -Status "Done!" -Completed

Stop-Transcript
