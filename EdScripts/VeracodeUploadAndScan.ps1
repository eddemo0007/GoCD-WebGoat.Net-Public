# MIT License
#
# Note that this code was converted from Shell to PowerShell on 08/12/2023 by Ed Gannaway
#
# Copyright (c) 2019 Chris Tyson
# Author: Chris Tyson
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# When looking into this I was inspired by Matthias Gärtner's (https://gist.github.com/m9aertner) 
# "Using curl and openssl to access the Veracode API endpoint" ( https://gist.github.com/m9aertner/7ae804a5297617456f81c8b5a3a9305b) who showed how
# using plain shell scripting on the command line, it's possible to compute the Authorization header using openssl.
#
# For other interesting uses of the api see Veracode-Community-Projects page here: https://github.com/veracode/Veracode-Community-Projects

$Debug = $false
$UseCreds = $false

function Generate-HMACHeader {
    param (
        [string]$urlPath,
        [string]$method
    )
    # Generate the hmac header for Veracode
    if ($Debug) {
        Write-Host "`nGenerate the hmac header for URLPATH $urlPath and METHOD $method"
    }
    $nonce = ([byte[]]::new(32) | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 })
    $ts = [math]::floor((Get-Date -UFormat %s) * 1000)
    $encryptedNonce = $nonce | ForEach-Object { $_ } | ForEach-Object { [char]$_ } | Out-String | ForEach-Object { $_.Trim() } | Out-String | openssl dgst -sha256 -mac HMAC -macopt hexkey:$env:VERACODE_KEY | ForEach-Object { $_.Trim() }
    $encryptedTimestamp = $ts | ForEach-Object { $_.ToString() } | ForEach-Object { $_.Trim() } | openssl dgst -sha256 -mac HMAC -macopt hexkey:$encryptedNonce | ForEach-Object { $_.Trim() }
    $signingKey = "vcode_request_version_1" | ForEach-Object { $_ } | ForEach-Object { [char]$_ } | Out-String | ForEach-Object { $_.Trim() } | openssl dgst -sha256 -mac HMAC -macopt hexkey:$encryptedTimestamp | ForEach-Object { $_.Trim() }
    $data = "id=$env:VERACODE_ID&host=analysiscenter.veracode.com&url=$urlPath&method=$method"
    $signature = $data | openssl dgst -sha256 -mac HMAC -macopt hexkey:$signingKey | ForEach-Object { $_.Trim() }
    $VERACODE_AUTH_HEADER = "VERACODE-HMAC-SHA-256 id=$env:VERACODE_ID,ts=$ts,nonce=$nonce,sig=$signature"
    $VERACODE_AUTH_HEADER
}

function Usage {
    Write-Host ""
    Write-Host "$($MyInvocation.ScriptName) is a sample script to upload and scan an application with Veracode using curl and hmac headers"
    Write-Host ""
    Write-Host "-h,--help          prints this message"
    Write-Host "-d,--debug         prints debugging information"
    Write-Host "--app              = `<your appname>`"
    Write-Host "--file             = `<filename to upload>`"
    Write-Host "--filepath         = `<full path to filename to upload>`"
    Write-Host "                     Note: escape the final \\ with an extra \\ (i.e. c:\\mystuff\\\\example\\\\)"
    Write-Host "--crit             = `<businsess criticality of the app>`"
    Write-Host "--vid              = `<your Veracode ID>`"
    Write-Host "--vkey             = `<your Veracode Key>`"
    Write-Host "--usecreds, -uc    use the Veracode ID and Key credentials stored in ~/.veracode/credentials"
}

if ($Debug) {
    Write-Host "`nDebug on`n"
}

# Set default business criticality
$BUSINESSCRITICALITY = "Very High"
$USECREDS = "off"

# Parse command line options
for ($i=0; $i -lt $args.Length; $i++) {
    $param = $args[$i].Split('=')[0]
    $value = $args[$i].Split('=')[1]
    switch ($param) {
        "-h", "--help" {
            Usage
            exit
        }
        "--debug", "-d" {
            $Debug = "on"
        }
        "--usecreds", "-uc" {
            $USECREDS = "on"
        }
        "--app" {
            $APP = $value
        }
        "--file" {
            $FILE = $value
        }
        "--filepath" {
            $FILEPATH = $value
        }
        "--crit" {
            $BUSINESSCRITICALITY = $value
        }
        "--vid" {
            $env:VERACODE_ID = $value
        }
        "--vkey" {
            $env:VERACODE_KEY = $value
        }
        default {
            Write-Host "ERROR: unknown parameter `"$param`""
            Usage
            exit 1
        }
    }
}

if ($Debug) {
    Write-Host "`nRunning $($MyInvocation.ScriptName) with the following values`n"
    Write-Host "--app           = $APP"
    Write-Host "--file          = $FILE"
    Write-Host "--filepath      = $FILEPATH"
    Write-Host "--crit          = $BUSINESSCRITICALITY"
    Write-Host "--vid           = $env:VERACODE_ID"
    Write-Host "--vkey          = $env:VERACODE_KEY"
}

if ($USECREDS -eq "on") {
    $creds = Get-Content "$env:USERPROFILE\.veracode\credentials"
    $foundDefault = $false
    foreach ($line in $creds) {
        if ($line -match "default") {
            $line = $creds[$creds.IndexOf($line) + 1]
            $env:VERACODE_ID = ($line -split '=')[1].Trim()
            $line = $creds[$creds.IndexOf($line) + 1]
            $env:VERACODE_KEY = ($line -split '=')[1].Trim()
            if ($Debug) {
                Write-Host "Veracode ID from credentials is       = $env:VERACODE_ID"
                Write-Host "Veracode Key from credentials is      = $($env:VERACODE_KEY.Substring(0, 5))**********"
            }
            $foundDefault = $true
            break
        }
    }
}

if ($Debug) {
    Write-Host ""
}

if ($APP -eq "" -or $FILE -eq "" -or $FILEPATH -eq "" -or (($env:VERACODE_ID -eq "" -or $env:VERACODE_KEY -eq "") -and $USECREDS -eq "off")) {
    Write-Host "At a minimum you need to specify the app name, file name, file path, and your Veracode ID and Key or --usecreds. Here is an example invocation:"
    Write-Host "`"$($MyInvocation.ScriptName) --app=verademoscript --file=`"my.war`" --filepath=`"C:\\Users\\myuser\\DemoStuff\\shell script\\ --crit=`"Very High`" --vid=a251a1d**************** --vkey=312054************`""
    Usage
    exit 0
}

if ($USECREDS -eq "on") {
    if ($Debug) {
        Write-Host "Using credentials from ~/.veracode/credentials"
    }
}

if ($Debug) {
    Write-Host ""
}

if ($Debug) {
    Write-Host "Check if the $APP profile exists, create it if it does not exist, and get the app id"
}

# Get the app list from the platform
$urlPath = "/api/5.0/getapplist.do"
$method = "GET"
$veracodeAuthHeader = Generate-HMACHeader $urlPath $method
Invoke-RestMethod -Method $method -Uri "https://analysiscenter.veracode.com$urlPath" -Headers @{ "Authorization" = $veracodeAuthHeader } -OutFile applist.xml

# Check the app list to see if the application profile to be used exists
$appFound = $false
foreach ($line in Get-Content -Path applist.xml) {
    if ($line -match 'app_name="(.*)"') {
        $app_name = $Matches[1]
    }
    if ($line -match 'app_id="(.*)"') {
        $app_id = $Matches[1]
    }
    if ($app_name -eq $APP) {
        $appFound = $true
        break
    }
}

if ($appFound) {
    if ($Debug) {
        Write-Host ""
        Write-Host "The $APP profile with app_id $app_id exists, not creating"
    }
}
else {
    # Create the app
    if ($Debug) {
        Write-Host "Create $APP profile"
    }
    $urlPath = "/api/5.0/createapp.do"
    $method = "POST"
    $veracodeAuthHeader = Generate-HMACHeader $urlPath $method
    Invoke-RestMethod -Method $method -Uri "https://analysiscenter.veracode.com$urlPath" -Headers @{ "Authorization" = $veracodeAuthHeader } -Body "app_name=$APP&business_criticality=$BUSINESSCRITICALITY" -OutFile createapp.xml
    $app_id = (Get-Content -Path createapp.xml | Select-String 'app_id="(.*)"' | ForEach-Object { $_ -replace '.*app_id="(.*)".*', '$1' }).Trim()
}

# Upload the file
$upload = "$FILEPATH$FILE"
Write-Host ""
Write-Host "Uploading the file $upload to $APP"
$urlPath = "/api/5.0/uploadfile.do"
$method = "POST"
$veracodeAuthHeader = Generate-HMACHeader $urlPath $method
Invoke-RestMethod -Method $method -Uri "https://analysiscenter.veracode.com$urlPath" -Headers @{ "Authorization" = $veracodeAuthHeader } -Form @{ "app_id" = $app_id; "file" = Get-Item -Path $upload } -OutFile upload.xml

# Start the scan
Write-Host ""
Write-Host "Starting the prescan for $APP with auto_scan true"
$urlPath = "/api/5.0/beginprescan.do"
$method = "POST"
$veracodeAuthHeader = Generate-HMACHeader $urlPath $method
Invoke-RestMethod -Method $method -Uri "https://analysiscenter.veracode.com$urlPath" -Headers @{ "Authorization" = $veracodeAuthHeader } -Form @{ "app_id" = $app_id; "auto_scan" = "true" } -OutFile beginscan.xml
