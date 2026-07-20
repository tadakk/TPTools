# Generated using Google Gemini 3.5 flash with some minor corrections
# ==============================================================================
# Dynamic Bluetooth Headset Battery Monitor Tray Icon for Windows 11
# ==============================================================================

# 1. Configuration
$UpdateIntervalSeconds = 300 # Frequency of checking battery status
$LastNotification=(Get-Date).AddHours(-1)

# 2. Load necessary assemblies for UI and Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 3. Initialize the application context and NotifyIcon
$Context = New-Object System.Windows.Forms.ApplicationContext
$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$NotifyIcon.Visible = $true

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
    $NotifyIcon.Icon = [System.Drawing.Icon]::FromHandle($hIcon)
    
    if ($oldIcon) { $oldIcon.Dispose() }
    $brush.Dispose()
    $font.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

# 5. Core logic to dynamically fetch the active Bluetooth battery status
function Refresh-BatteryStatus {
    # Speed optimization: Retrieve only active ('OK') devices, then narrow down to the Hands-Free Audio service
    $activeAudioDevices = Get-PnpDevice -Status "OK" -ErrorAction SilentlyContinue | Where-Object { $_.Service -eq "BthHFEnum" }
    
    if ($null -eq $activeAudioDevices -or $activeAudioDevices.Count -eq 0) {
        $NotifyIcon.Text = "No Bluetooth Audio Connected"
        Update-TrayIcon "X" ([System.Drawing.Color]::Red)
        return
    }

    $batteryKey = "{104EA319-6EE2-4701-BD47-8DDBF425BBE5} 2"
    $foundBatteryData = $null
    $matchedDeviceName = ""

    # Check the active audio hands-free device(s) directly
    foreach ($dev in $activeAudioDevices) {
        try {
            $checkData = (Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName $batteryKey -ErrorAction SilentlyContinue).Data
            if ($null -ne $checkData -and $checkData -gt 0 -and $checkData -le 100) {
                $foundBatteryData = $checkData
                # Clean up "Hands-Free AG" trailing text from name if present for a cleaner tray label
                $matchedDeviceName = $dev.FriendlyName -replace "\s+Hands-Free\s+AG$", ""
                break
            }
        } catch {}
    }
    
    # Update the Tray Icon
    if ($null -ne $foundBatteryData) {
        $percentage = [int]$foundBatteryData
        $NotifyIcon.Text = "${matchedDeviceName}: $percentage% -$(Get-Date -Format "HH:mm:ss")"
        
        # Color coding
        $color = [System.Drawing.Color]::White
        if ($percentage -lt 20) { $color = [System.Drawing.Color]::OrangeRed }
        elseif ($percentage -lt 50) { $color = [System.Drawing.Color]::Orange }
        If ($percentage -lt 10 -and $LastNotification -lt (Get-Date).AddHours(-1)) {
            $LastNotification=Get-Date
            [System.Windows.Forms.MessageBox]::Show("Please charge your headset", "Headset under 10%")
        
        }

        Update-TrayIcon "$percentage" $color
    } else {
        $NotifyIcon.Text = "No Audio Battery Data"
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
