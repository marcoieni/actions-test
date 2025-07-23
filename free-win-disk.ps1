$ErrorActionPreference = 'Stop'

Get-Volume | Out-String | Write-Output

$available = $(Get-Volume C).SizeRemaining

$dirs = 'C:\Program Files\Google\Chrome', 'C:\Program Files (x86)\Microsoft\Edge',
'C:\errorerror', 'C:\Strawberry', 'C:\hostedtoolcache\windows\Java_Temurin-Hotspot_jdk'

foreach ($dir in $dirs) {
    Start-ThreadJob -InputObject $dir {
        Remove-Item -Recurse -Force -LiteralPath $input
    } | Out-Null
}

foreach ($job in Get-Job) {
    Wait-Job $job  | Out-Null
    if ($job.Error) {
        Write-Output "::warning file=$PSCommandPath::$($job.Error)"
    }
    Remove-Job $job
}

foreach ($dir in $dirs) {
        if (Test-Path -LiteralPath $dir) {
                Write-Output "::warning file=$PSCommandPath::Directory still exists: $dir"
        }
        if (Test-Path -LiteralPath 'C:\Program Files\MongoDB') {
                Write-Output "::warning file=$PSCommandPath::Directory still exists: MongoDB"
        }
}

Get-Volume | Out-String | Write-Output

$saved = ($(Get-Volume C).SizeRemaining - $available) / 1gb
Write-Output "total space saved $saved GB"
