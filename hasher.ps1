Param(
    [Parameter(Mandatory = $true)]
    [string]$path
)

$folder = Split-Path -Leaf $path

if ($folder -like '*:\*') {
    $folder = Split-Path -Leaf $path | % { $_.replace(":\", "") }
}

$dateTime = Get-Date -UFormat "%Y-%m-%d_%H-%M-%S"
$logFile = $folder + '(' + $dateTime + ').log'

Start-Transcript -Path $logFile\\$logFile

$folderReport = $folder + '.xml'

[xml]$xml = New-Object System.Xml.XmlDocument
$xml.LoadXml("<?xml version=""1.0"" encoding=""UTF-8""?><Files></Files>")


Get-ChildItem -Recurse -File -Force $path | Select-Object FullName | ForEach-Object {
    
    Write-Host $_.FullName
    $fileHash = Get-FileHash -LiteralPath $_.FullName

    $fileElement = $xml.CreateElement("File")

    $pathElement = $xml.CreateElement("Path")
    $pathValue = $xml.CreateTextNode($_.FullName)
    $pathElement.AppendChild($pathValue) > $null
    $fileElement.AppendChild($pathElement) > $null

    $hashElement = $xml.CreateElement("Hash")
    $hashValue = $xml.CreateTextNode($fileHash.Hash)
    $hashElement.AppendChild($hashValue) > $null
    $fileElement.AppendChild($hashElement) > $null

    $xml.LastChild.AppendChild($fileElement) > $null

    $xml.Save("{0}\\$logFile\\$folderReport" -f (get-location)) > $null
}

Stop-Transcript
