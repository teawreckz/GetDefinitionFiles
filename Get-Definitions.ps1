<#
.SYNOPSIS
    Download antimalware definition update files for Microsoft and McAfee
.DESCRIPTION
    Based on: How to manually download the latest antimalware definition updates for
    Microsoft Forefront Client Security, Microsoft Forefront Endpoint
    Protection 2010 and Microsoft System Center 2012 Endpoint Protection
    KB: http://support.microsoft.com/kb/935934/en
    McAfee https://www.mcafee.com/apps/downloads/security-updates/security-updates.aspx
.PARAMETER 
    NONE
.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -file "Get-Definitions.ps1"
.NOTES
    Script name: Get-Definitions.ps1
    Version:     2.0
    Author:      Richard Tracy
    DateCreated: 2015-07-22
    LastUpdate:  2018-06-06
    #>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
## Variables: Script Name and Script Paths
[string]$scriptPath = $MyInvocation.MyCommand.Definition
[string]$scriptName = [IO.Path]::GetFileNameWithoutExtension($scriptPath)
[string]$scriptFileName = Split-Path -Path $scriptPath -Leaf
[string]$scriptRoot = Split-Path -Path $scriptPath -Parent
[string]$invokingScript = (Get-Variable -Name 'MyInvocation').Value.ScriptName

#  Get the invoking script directory
If ($invokingScript) {
	#  If this script was invoked by another script
	[string]$scriptParentPath = Split-Path -Path $invokingScript -Parent
}
Else {
	#  If this script was not invoked by another script, fall back to the directory one level above this script
	[string]$scriptParentPath = (Get-Item -LiteralPath $scriptRoot).Parent.FullName
}

#=======================================================
# BUILD FOLDER STRUCTURE
#=======================================================
[string]$WinDefFolder = Join-Path -Path $scriptRoot -ChildPath 'Definitions\Defender'
New-Item -Path $WinDefFolder -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

$path7x86 = Join-Path -Path $WinDefFolder -ChildPath 'Win7\x86'
$path7x64 = Join-Path -Path $WinDefFolder -ChildPath 'Win7\x64'
New-Item -Path $path7x86 -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
New-Item -Path $path7x64 -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

$path10x86 = Join-Path -Path $WinDefFolder -ChildPath 'Win8_10\x86'
$path10x64 = Join-Path -Path $WinDefFolder -ChildPath 'Win8_10\x64'
New-Item -Path $path10x86 -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
New-Item -Path $path10x64 -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

$pathNISx86 = Join-Path -Path $WinDefFolder -ChildPath 'NIS\x86'
$pathNISx64 = Join-Path -Path $WinDefFolder -ChildPath 'NIS\x64'
New-Item -Path $pathNISx86 -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
New-Item -Path $pathNISx64 -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

[string]$DatFolder = Join-Path -Path $scriptRoot -ChildPath 'Definitions\McAfee'
New-Item -Path $DatFolder -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

#==================================================
# FUNCTIONS
#==================================================
Function logstamp {
    $now=get-Date
    $yr=$now.Year.ToString()
    $mo=$now.Month.ToString()
    $dy=$now.Day.ToString()
    $hr=$now.Hour.ToString()
    $mi=$now.Minute.ToString()
    if ($mo.length -lt 2) {
    $mo="0"+$mo #pad single digit months with leading zero
    }
    if ($dy.length -lt 2) {
    $dy ="0"+$dy #pad single digit day with leading zero
    }
    if ($hr.length -lt 2) {
    $hr ="0"+$hr #pad single digit hour with leading zero
    }
    if ($mi.length -lt 2) {
    $mi ="0"+$mi #pad single digit minute with leading zero
    }

    write-output $yr$mo$dy$hr$mi
}

Function Write-Log{
   Param ([string]$logstring)
   Add-content $Logfile -value $logstring -Force
}

function Download-FileProgress($url, $targetFile){
   $uri = New-Object "System.Uri" "$url"
   $request = [System.Net.HttpWebRequest]::Create($uri)
   $request.set_Timeout(15000) #15 second timeout
   $response = $request.GetResponse()
   $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
   $responseStream = $response.GetResponseStream()
   $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
   $buffer = new-object byte[] 10KB
   $count = $responseStream.Read($buffer,0,$buffer.length)
   $downloadedBytes = $count
   while ($count -gt 0)
   {
       $targetStream.Write($buffer, 0, $count)
       $count = $responseStream.Read($buffer,0,$buffer.length)
       $downloadedBytes = $downloadedBytes + $count
       Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
   }
   Write-Progress -activity "Finished downloading file '$($url.split('/') | Select -Last 1)'"
   $targetStream.Flush()
   $targetStream.Close()
   $targetStream.Dispose()
   $responseStream.Dispose()
}

# GENERATE INITIAL LOG
#==================================================
$logstamp = logstamp
[string]$LogFolder = Join-Path -Path $scriptRoot -ChildPath 'Logs'
$Logfile =  "$LogFolder\definitions.log"
Write-log -logstring "Downloading Definition Files, Please wait"

#==================================================
# MAIN - DOWNLOAD 3RD PARTY SOFTWARE
#==================================================
## Load the System.Web DLL so that we can decode URLs
Add-Type -Assembly System.Web
$wc = New-Object System.Net.WebClient

# Proxy-Settings
#$wc.Proxy = [System.Net.WebRequest]::DefaultWebProxy
#$wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

#Get-Process "firefox" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
#Get-Process "iexplore" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
#Get-Process "Openwith" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue


# Microsoft Security Essentials - X64 DOWNLOAD
#==================================================
$source = "http://go.microsoft.com/fwlink/?LinkID=121721&arch=x64"
Write-Host "Parsing site: $source for Windows 10 (64-bit) Windows Defender/Microsoft Security Essentials full definition files" -ForegroundColor Yellow

$destination = $path10x64 + "\" + 'mpam-fe.exe'
Try{
    Download-FileProgress -url $source -targetFile $destination
    #$wc.DownloadFile($source, $destination)  
    Write-Host "Successfully downloaded Microsoft Security Essentials to $destination" -ForegroundColor Green
} Catch {
    Write-Host "failed to download Microsoft Security Essentials (x64)" -ForegroundColor Red
}

<# Windows Defender in Windows 10 and Windows 8.1 
$source = "http://go.microsoft.com/fwlink/?LinkID=121721&arch=x64"
$destination = $path10x64 + "\" + 'mpam-d.exe'
Try{
    Download-FileProgress -url $source -targetFile $destination
    #$wc.DownloadFile($source, $destination) 
    Write-Host "Successfully downloaded Windows Defender in Windows 10 and Windows 8.1 to $destination" -ForegroundColor Green
} Catch {
    Write-Host "failed to download Windows Defender in Windows 10 and Windows 8.1 (x64)" -ForegroundColor Red
}
#>

# Windows 7 and Windows Vista Defender definitions - X64 DOWNLOAD
#================================================================
$source = "http://go.microsoft.com/fwlink/?LinkID=121721&clcid=0x409&arch=x64&eng=0.0.0.0&avdelta=0.0.0.0&asdelta=0.0.0.0&prod=925A3ACA-C353-458A-AC8D-A7E5EB378092"
Write-Host "Parsing site: $source for Windows 7 (64-bit) Windows Defender definition files" -ForegroundColor Yellow

$destination = $path7x64 + "\" + 'mpas-fe.exe'
Try{
    Download-FileProgress -url $source -targetFile $destination
    #$wc.DownloadFile($source, $destination) 
    Write-Host "Successfully downloaded Windows Defender in Windows 7 and Windows Vista to $destination" -ForegroundColor Green
} Catch {
    Write-Host "failed to download Windows Defender in Windows 7 and Windows Vista (x64)" -ForegroundColor Red
}

# Network-based exploit definitions - X64 DOWNLOAD
#==================================================
$source = "http://go.microsoft.com/fwlink/?LinkID=187316&arch=x64&nri=true"
Write-Host "Parsing site: $source for  Network-based (64-bit) exploit definition files" -ForegroundColor Yellow

$destination = $pathNISx64 + "\" + 'nis_full.exe'
Try{
    Download-FileProgress -url $source -targetFile $destination
    #$wc.DownloadFile($source, $destination) 
    Write-Host "Successfully downloaded Network-based exploit definitions to $destination" -ForegroundColor Green
} Catch {
    Write-Host "failed to download Network-based exploit definitions (x64)" -ForegroundColor Red
}

# Microsoft Security Essentials - X86 DOWNLOAD
#==================================================
# Windows Defender in Windows 10 and Windows 8.1 
$source = "http://go.microsoft.com/fwlink/?LinkID=121721&arch=x86"
Write-Host "Parsing site: $source for Windows 10 (32-bit) Windows Defender//Microsoft Security Essentials full definition files" -ForegroundColor Yellow
$destination = $path10x86 + "\" + 'mpam-fe.exe'
Try{
    Download-FileProgress -url $source -targetFile $destination
    #$wc.DownloadFile($source, $destination)  
    Write-Host "Successfully downloaded Microsoft Security Essentials to $destination" -ForegroundColor Green
} Catch {
    Write-Host "failed to download Microsoft Security Essentials (x86)" -ForegroundColor Red
}


<# Windows Defender in Windows 10 and Windows 8.1 
$source = "http://go.microsoft.com/fwlink/?LinkID=121721&arch=x86"
$destination = $path10x86 + "\" + 'mpam-d.exe'
Try{
    $wc.DownloadFile($source, $destination) 
    Write-Host "Successfully downloaded Windows Defender in Windows 10 and Windows 8.1 to $destination" -ForegroundColor Green
} Catch {
    Write-Host "failed to download Windows Defender in Windows 10 and Windows 8.1 (x86)" -ForegroundColor Red
}#>


# Windows 7 and Windows Vista Defender definitions - X86 DOWNLOAD
#================================================================
$source = "http://go.microsoft.com/fwlink/?LinkID=121721&clcid=0x409&arch=x86&eng=0.0.0.0&avdelta=0.0.0.0&asdelta=0.0.0.0&prod=925A3ACA-C353-458A-AC8D-A7E5EB378092"
Write-Host "Parsing site: $source for Windows 7 (32-bit) Windows Defender definition files" -ForegroundColor Yellow
$destination = $path7x86 + "\" + 'mpas-fe.exe'
Try{
    Download-FileProgress -url $source -targetFile $destination
    #$wc.DownloadFile($source, $destination)  
    Write-Host "Successfully downloaded Windows Defender in Windows 7 and Windows Vista to $destination" -ForegroundColor Green
} Catch {
    Write-Host "failed to download Windows Defender in Windows 7 and Windows Vista (x86)" -ForegroundColor Red
}

# Network-based exploit definitions - X86 DOWNLOAD
#==================================================
$source = "http://go.microsoft.com/fwlink/?LinkID=187316&arch=x86&nri=true"
Write-Host "Parsing site: $source for  Network-based (32-bit) exploit definition files" -ForegroundColor Yellow
$destination = $pathNISx86 + "\" + 'nis_full.exe'
Try{
    Download-FileProgress -url $source -targetFile $destination
    #$wc.DownloadFile($source, $destination)  
    Write-Host "Successfully downloaded Network-based exploit definitions to $destination" -ForegroundColor Green
} Catch {
    Write-Host "failed to download Network-based exploit definitions (x86)" -ForegroundColor Red
}

# McAfee DAT V2 Virus Definition - DOWNLOAD
#==================================================
$Response = (invoke-webrequest -uri http://update.nai.com/products/commonupdater/gdeltaavv.ini)
[array]$A=$Response.Content -split "`r`n"
$CurrentVersion=$A[3].Split('=')[1]
$URI="http://update.nai.com/products/datfiles/4.x/nai/$($CurrentVersion)xdat.exe"
$datfile = (invoke-webrequest -uri $URI).Content.RawContent
#Change this path if you wish otherwise default location is C:\temp
$destination = $DatFolder + "\" + $($CurrentVersion) + "x.dat.exe"

If (Test-Path "$destination" -ErrorAction SilentlyContinue){
    $LogComment = $($CurrentVersion) + "x.dat.exe is already downloaded"
    Write-Host $LogComment -ForegroundColor Gray | Write-Log -logstring $LogComment
} Else {
    Remove-Item "$DatFolder\*" -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
    Try{
        Invoke-WebRequest -Uri $uri -OutFile $destination
        Write-Host "Successfully downloaded McAfee latest DAT definitions to [$destination]" -ForegroundColor Green
    } Catch {
        Write-Host "failed to downloaded McAfee latest DAT definitions (DAT)" -ForegroundColor Red
    }
}