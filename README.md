# TPTools
Tools made by me.

HoneywellAPI - folder containing an API for Honeywell thermostats


bt_battery.ps1 - Get the percentage of the currently plugged in Bluetooth headset. Checks every 5 minutes and can be put in a scheduled task


# WatchIt
Powershell script to run a command over and over highlighting changes

	.SYNOPSIS
	Runs a command over and over highlighting changes between each run
	.PARAMETER <string> Command
	Command to run
	.PARAMETER <int> N
	Number of seconds between each command run
	.EXAMPLE
	.\WatchIt.ps1 -N 10 -Command 'Get-Process | Sort-Object PM -Descending | Select-Object -First 10' 
	.NOTES
	Current user

