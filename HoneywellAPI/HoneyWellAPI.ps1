<#
	.SYNOPSIS
	Version 0.1. Set of functions to interact with Honeywell API
	.PARAMETER <string> Key
	Consumer Key
	.PARAMETER <string> Secret
	Consumer Secret
	.PARAMETER <string> RedirectURI
	Redrect URI defined in App
	.PARAMETER <string> User
	Honeywell API username
	.PARAMETER <string> Password
	Honeywell API password
	.PARAMETER <string> RefreshToken
	Refresh Token used to get another token
	.PARAMETER <string> Token
	Used to interact with the API and Honeywell devices
	.PARAMETER <string> HWLOCID
	Honeywell Location ID
	.PARAMETER <string> HWDEVICE
	Honeywell Device ID
	.PARAMETER <string> Mode
	Mode to set for device such as On or Heat. Default setting for Thermostats is Auto
	.PARAMETER <string> HeatSetPoint
	Heat set temperature
	.PARAMETER <string> CoolSetPoint
	Cool set temperature
	.PARAMETER <string> AutoChangeoverActive
	If true, switch between heat and cool automatically. Default setting is true
	.EXAMPLES
    $mytoken=New-HWToken -Key $Key -Secret $Secret -RedirectURI $RedirectUri -User $User -Password $Password
    $mytoken=Refresh-HWToken -Key $Key -Secret $Secret -RefreshToken $mytoken.RefreshToken
	Set-ThermostatMode -Key $Key -Token $mytoken.Token -HWLOCID $HWLOCID -HWDEVICE $HWDEVICE -mode "Cool" -HeatSetPoint 65 -CoolSetPoint 72
	.NOTES
	Current user
#>
Function New-HWToken ($Key,$Secret,$RedirectURI,$User,$Password)
{
        Write-Host "Getting new token"
        $keyencoded=[convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($Key):$Secret"))
        $req=iwr -Method GET -MaximumRedirection 0 -Uri "https://api.honeywell.com/oauth2/authorize" -Body @{response_type='code';client_id="$Key";redirect_uri="$RedirectURI"} -ErrorAction SilentlyContinue
        $location=$r.Headers.Location
        $req = Invoke-WebRequest -Uri $location
        $req.Forms[0].Fields.username="$User"
        $req.Forms[0].Fields.password="$Password"
        $loginPage = Invoke-WebRequest -Uri $location -Method POST -Body $req.Forms[0] -SessionVariable WebSession # Post the form to log-in
        $loginPage.Forms[0].Fields.decision="yes"
        $login2=Invoke-WebRequest -Method POST -Uri ("https://api.honeywell.com/" + $loginPage.Forms[0].action) -Body $loginPage.Forms[0].Fields -WebSession $WebSession
        $devices=$login2.AllElements | ? Class -eq "device-label" | Select-Object innerHTML,id
        $devstring=$devices.id -join ":"
        $login2.forms[0].Fields.selDevices="$devstring"
        $login2.forms[0].Fields.areFutureDevicesEnabled=$False
        $login3=Invoke-WebRequest -MaximumRedirection 0 -Method POST -Uri ("https://api.honeywell.com" + $login2.Forms[0].action) -WebSession $WebSession -Body $login2.Forms[0].Fields -ErrorAction SilentlyContinue
        $dcode=(($login3.Headers.Location -split "=")[1] -split "&")[0]
        $r=Invoke-RestMethod -Method POST -Headers @{Authorization="Basic $keyencoded"; ContentType='application/x-www-form-urlencoded';Accept="application/json"} -Body @{grant_type='authorization_code';code="$dcode";redirect_uri="$RedirectURI"} -uri "https://api.honeywell.com/oauth2/token" 
        $token=$r.access_token
        $refreshtoken=$null
        $RefreshToken=$r.refresh_token
        $expiresin=$r.expires_in
        $expiresat=(Get-Date).AddSeconds($expiresin-1)
        [PSCustomObject]@{"Token"=$Token;"RefreshToken"=$RefreshToken;"ExpiresAt"=$expiresat}
}
Function Refresh-HWToken ($Key,$Secret,$RefreshToken)
{
        Write-Host "Refreshing refresh token"
        $keyencoded=[convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($Key):$Secret"))
        $r=Invoke-RestMethod -Method "POST" -Headers @{Authorization="Basic $keyencoded"; ContentType='application/x-www-form-urlencoded';Accept="application/json"} -Body @{grant_type='refresh_token';refresh_token="$RefreshToken"} -uri https://api.honeywell.com/oauth2/token
        $token=$r.access_token
        $refreshtoken=$null
        $RefreshToken=$r.refresh_token
        $expiresin=$r.expires_in
        $expiresat=(Get-Date).AddSeconds($expiresin-1)
        [PSCustomObject]@{"Token"=$Token;"RefreshToken"=$RefreshToken;"ExpiresAt"=$expiresat}
}

Function Get-HWDevices ($Key,$Token)
{
    Invoke-RestMethod -Headers @{Authorization="Bearer $Token"} -Body @{apikey="$Key"} -uri https://api.honeywell.com/v2/locations
}

Function Set-ThermostatFanMode ($Key,$Token,$HWLOCID,$HWDEVICE,$Mode)
{
    Invoke-RestMethod -Uri "https://api.honeywell.com/v2/devices/thermostats/$($HWDEVICE)/fan?apikey=$Key&locationId=$HWLOCID" -Method Post -Headers @{Authorization="Bearer $Token"} -Body "{ ""mode"" : ""$mode"" }" -ContentType "application/json"
}

Function Set-ThermostatMode ($Key,$Token,$HWLOCID,$HWDEVICE,$Mode="Auto",$HeatSetPoint,$CoolSetPoint,$AutoChangeoverActive="true")
{
    Invoke-RestMethod -Uri "https://api.honeywell.com/v2/devices/thermostats/$($HWDEVICE)?apikey=$Key&locationId=$HWLOCID" -Method Post -Headers @{Authorization="Bearer $Token"} -Body "{ ""mode"" : ""$mode"",""thermostatSetpointStatus"" : ""TemporaryHold"",""heatSetpoint"" : ""$HeatSetPoint"",""coolSetpoint"" : ""$CoolSetPoint"",""autoChangeoverActive"" : $AutoChangeoverActive }" -ContentType "application/json"
}