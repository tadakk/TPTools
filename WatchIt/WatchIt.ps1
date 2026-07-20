#ver 0.5
<#
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
#>
param([Parameter(Mandatory=$true, ValueFromPipeline=$true,Position=1)] [string]$Command,[int]$N=2)
$t=$null;$bg=[console]::ForegroundColor;$fg=[console]::BackgroundColor
while (1) {
    cls;$s=Invoke-Expression $Command | Out-String
    $s=$s -split "\n"
    If ($s -ne $t -and $t) {
        $j=0
        foreach ($line in $s) {
        $line=$line.ToCharArray();$color=$false;$sub="";$i=0;try {$u=$t[$j].ToCharArray()} catch {$u=" "};$j++
        foreach ($char in $line) {
            $m=try {$u[$i] -eq $char} catch {$false}
            if ($m) {if (-not $color) {$sub="$sub$char"} else {Write-Host "$sub" -NoNewline -BackgroundColor $bg -ForegroundColor $fg;$color=$false;$sub=$char}}
             else {if ($color) {$sub="$sub$char"}else {Write-Host "$sub" -NoNewline;$color=$true;$sub=$char}
            }$i++;;if ($i -eq $line.count) {Write-Host "$sub$char";$sub=""}}}} else {$s}
    $t=$s;sleep $N
}
