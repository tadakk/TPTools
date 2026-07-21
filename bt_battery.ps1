# Generated using Google Gemini 3.5 flash with some minor corrections
# ==============================================================================
# Dynamic Bluetooth Headset Battery Monitor Tray Icon for Windows 11
# ==============================================================================

# 1. Configuration
$UpdateIntervalSeconds = 30 # Frequency of checking battery status
$LastNotification=(Get-Date).AddHours(-1)

# 2. Load necessary assemblies for UI and Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# Import DestroyIcon from user32.dll to clear GDI icon handles from memory
Add-Type -MemberDefinition '[DllImport("user32.dll", SetLastError = true)] public static extern bool DestroyIcon(IntPtr hIcon);' -Name "Win32Utils" -Namespace "Win32"

# 3. Initialize the application context and NotifyIcon
$Context = New-Object System.Windows.Forms.ApplicationContext
$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$NotifyIcon.Visible = $true
$theme = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
If ($theme.SystemUsesLightTheme -eq 1) {$defaultColor="BLACK"} else {$defaultColor="WHITE"}
$previousFound=$false
$containerKey = "DEVPKEY_Device_ContainerId"

# 1. Gather Container IDs of all CURRENTLY CONNECTED Audio Endpoints
# When a headset powers off, Windows removes these endpoints from -PresentOnly instantly.
$liveAudioEndpoints = @(Get-PnpDevice -Class "AudioEndpoint" -PresentOnly -ErrorAction SilentlyContinue | 
                        Where-Object { $_.Status -eq "OK" })
                          
$global:liveContainerIds = @()
foreach ($ep in $liveAudioEndpoints) {
    $cId = (Get-PnpDeviceProperty -InstanceId $ep.InstanceId -KeyName $containerKey -ErrorAction SilentlyContinue).Data
    if ($cId) { 
        Write-Host "Initially found audio device $($ep.Friendlyname)"
        $global:liveContainerIds += [string]$cId
    }
}
$global:liveAudioEndpointsOld=$liveAudioEndpoints
$liveContainerIdsOld=$global:liveContainerIds
$global:presentLiveContainerId=$null
$global:btDevOld=$null
$activeBluetoothDrivers = Get-PnpDevice -Status "OK" -ErrorAction SilentlyContinue | 
                            Where-Object { ($_.Service -eq "BthHFEnum" -or $_.Service -eq "BthLEEnum") -and $_.Description -eq "Microsoft Bluetooth Hands-Free Profile AudioGateway role" }


# 4. Helper function to dynamically draw a percentage text icon
function Update-TrayIcon ([string]$text, [System.Drawing.Color]$textColor) {
    $bitmap = New-Object System.Drawing.Bitmap(32, 32)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    
    $font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush($textColor)
    
    $textSize = $graphics.MeasureString($text, $font)
    $x = (32 - $textSize.Width) / 2
    $y = (32 - $textSize.Height) / 2
    
    $graphics.DrawString($text, $font, $brush, $x, $y)
    
    $hIcon = $bitmap.GetHicon()
    $oldIcon = $NotifyIcon.Icon
    
    # Create the new icon from the handle
    $NotifyIcon.Icon = [System.Drawing.Icon]::FromHandle($hIcon)
    
    # Force the Shell Notification Area to refresh its drawing cache
    $NotifyIcon.Visible = $true
    
    # Clean up managed and unmanaged GDI resources
    if ($oldIcon) { 
        $oldIcon.Dispose() 
    }
    [Win32.Win32Utils]::DestroyIcon($hIcon) | Out-Null
    
    $brush.Dispose()
    $font.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

# 5. Core logic to dynamically fetch the active Bluetooth battery status
function Refresh-BatteryStatus {
    Write-Host ""
    $containerKey = "DEVPKEY_Device_ContainerId"

    # 1. Gather Container IDs of all CURRENTLY CONNECTED Audio Endpoints
    # When a headset powers off, Windows removes these endpoints from -PresentOnly instantly.
    $liveAudioEndpoints = @(Get-PnpDevice -Class "AudioEndpoint" -PresentOnly -ErrorAction SilentlyContinue | 
                          Where-Object { $_.Status -eq "OK" })
                          
    #if($global:presentLiveContainerId) {$global:liveContainerIds = @($liveContainerIdsOld | ? {$_ -ne $global:presentLiveContainerId})}
    #$liveContainerIds=$liveContainerIdsOld
    If ((Compare-Object -ReferenceObject $liveAudioEndpoints -DifferenceObject $global:liveAudioEndpointsOld)) {
        $global:liveContainerIds=@()
        foreach ($ep in ($liveAudioEndpoints | ? {$global:liveAudioEndpointsOld -notcontains $liveAudioEndpoints })) {
            $cId = (Get-PnpDeviceProperty -InstanceId $ep.InstanceId -KeyName $containerKey -ErrorAction SilentlyContinue).Data
            if ($cId) { 
                Write-Host "Found audio device $($ep.Friendlyname)"
                $global:liveContainerIds += [string]$cId
            }
        }
    }
    $liveContainerIdsOld = $global:liveContainerIds 
    $global:liveAudioEndpointsOld = $liveAudioEndpoints 

    # 2. Get active Bluetooth Hands-Free drivers and verify it's an audio gateway
    if ($null -eq $activeBluetoothDrivers -or $activeBluetoothDrivers.Count -eq 0 -or $liveContainerIds.Count -eq 0) {
        $NotifyIcon.Text = "No Bluetooth Audio Connected"
        Update-TrayIcon "X" ([System.Drawing.Color]::Red)
        return
    }

    $batteryKey = "{104EA319-6EE2-4701-BD47-8DDBF425BBE5} 2"
    $isAudioDeviceKey = "DEVPKEY_Device_DeviceDesc"
    $foundBatteryData = $null
    $matchedDeviceName = ""
    
    if ($global:btDevOld) {
        Write-Host "Found previous bluetooth device $($btDevOld.FriendlyName)"
        # Check if this Bluetooth driver's Container ID exists in the LIVE audio endpoint list
        $devContainerId = [string](Get-PnpDeviceProperty -InstanceId $global:btDevOld.InstanceId -KeyName $containerKey -ErrorAction SilentlyContinue).Data
        if ($global:liveContainerIds -contains $devContainerId) {
            $checkData = (Get-PnpDeviceProperty -InstanceId $global:btDevOld.InstanceId -KeyName $batteryKey -ErrorAction SilentlyContinue).Data
            if ($null -ne $checkData -and $checkData -gt 0 -and $checkData -le 100) {
                Write-Host "Found previous current device $($global:btDevOld.FriendlyName) with Battery Level $checkData%" -ForegroundColor Cyan
                $foundBatteryData = $checkData
                $matchedDeviceName = $global:btDevOld.FriendlyName -replace "\s+Hands-Free\s+AG$", ""
                $previousFound=$true
                $global:presentLiveContainerId=$devContainerId
            } else {
                Write-Host "Previous bluetooth device disconnected in between data gathering"
                $previousFound=$false
                $global:presentLiveContainerId=$null
                $global:btDevOld=$null
            }
        } else {
            Write-Host "Previous bluetooth device disconnected"
            $previousFound=$false
            $global:presentLiveContainerId=$null
            $global:btDevOld=$null
        }
    }
    if ($previousFound -eq $false) {
        foreach ($btDev in $activeBluetoothDrivers) {
            try {
                Write-Host "Found bluetooth device $($btDev.FriendlyName)"
                # Check if this Bluetooth driver's Container ID exists in the LIVE audio endpoint list
                $devContainerId = [string](Get-PnpDeviceProperty -InstanceId $btDev.InstanceId -KeyName $containerKey -ErrorAction SilentlyContinue).Data
                if ($global:liveContainerIds -notcontains $devContainerId) {
                    continue # Stale node from a powered-off headset—skip it!
                }
                $checkData = (Get-PnpDeviceProperty -InstanceId $btDev.InstanceId -KeyName $batteryKey -ErrorAction SilentlyContinue).Data
                if ($null -ne $checkData -and $checkData -gt 0 -and $checkData -le 100) {
                    Write-Host "Found current device $($btDev.FriendlyName) with Battery Level $checkData%" -ForegroundColor Cyan
                    $foundBatteryData = $checkData
                    $matchedDeviceName = $btDev.FriendlyName -replace "\s+Hands-Free\s+AG$", ""
                    $global:btDevOld=$btDev
                    $global:presentLiveContainerId=$devContainerId
                    break
                }
            } catch {}
        }
    }

    # Update the Tray Icon
    if ($null -ne $foundBatteryData) {
        $percentage = [int]$foundBatteryData
        $NotifyIcon.Text = "${matchedDeviceName}: $percentage% - $(Get-Date -Format "HH:mm:ss")"
        
        # Color coding
        $color = [System.Drawing.Color]::$defaultColor
        if ($percentage -le 20) { $color = [System.Drawing.Color]::OrangeRed }
        elseif ($percentage -le 50) { $color = [System.Drawing.Color]::Orange }
        
        if ($percentage -le 10 -and $LastNotification -lt (Get-Date).AddHours(-1)) {
            $script:LastNotification = Get-Date
            [System.Windows.Forms.MessageBox]::Show("Please charge your headset", "Headset under 11%")
        }

        Update-TrayIcon "$percentage" $color
    } else {
        $NotifyIcon.Text = "No Audio Battery Data - $(Get-Date -Format "HH:mm:ss")"
        Update-TrayIcon "--" ([System.Drawing.Color]::LightGray)
    }
}

# 6. Set up a right-click Context Menu to gracefully close the script
$ContextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$ExitItem = $ContextMenu.Items.Add("Exit")
$ExitItem.add_Click({
    $Timer.Stop()
    $NotifyIcon.Visible = $false
    $NotifyIcon.Dispose()
    $Context.ExitThread()
})
$NotifyIcon.ContextMenuStrip = $ContextMenu

# 7. Set up an asynchronous UI Timer loop
$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = $UpdateIntervalSeconds * 1000
$Timer.add_Tick({
    Refresh-BatteryStatus
})

# 8. Execution
Refresh-BatteryStatus  # Initial check on launch
$Timer.Start()
[System.Windows.Forms.Application]::Run($Context)
