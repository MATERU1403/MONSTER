# Rig helpers: run a Lua file on one of the two alts through the workspace file poller (_poller.lua on each client).
#   . .\tools\rig.ps1
#   Run-Lua morrowindf tools\live\status.lua            # waits for the result and prints it
#   Run-Lua gotham77r  tools\live\status.lua -Timeout 20
# The poller runs _cmd_<name>.lua and writes _res_<name>.txt (values joined with " | ", a leading "true" when it ran clean).
$script:Ws = 'C:\Users\conno\AppData\Local\Volt\workspace'

function Run-Lua {
    param(
        [Parameter(Mandatory)][string]$Client,
        [Parameter(Mandatory)][string]$File,
        [int]$Timeout = 15,
        [hashtable]$Globals = @{}
    )
    $src = Get-Content -Raw -Path (Join-Path $script:Ws "monster-build\$File") -ErrorAction SilentlyContinue
    if (-not $src) { $src = Get-Content -Raw -Path $File }
    # globals the script reads through getgenv().RIG
    $prefix = ''
    foreach ($k in $Globals.Keys) {
        $v = $Globals[$k]
        if ($v -is [string]) { $prefix += "getgenv().$k = '" + ($v -replace "'", "\'") + "'`n" }
        elseif ($v -is [bool]) { $prefix += "getgenv().$k = " + $v.ToString().ToLower() + "`n" }
        else { $prefix += "getgenv().$k = $v`n" }
    }
    $res = Join-Path $script:Ws "_res_$Client.txt"
    $cmd = Join-Path $script:Ws "_cmd_$Client.lua"
    Remove-Item $res -ErrorAction SilentlyContinue
    # (UTF-8 without a BOM: Set-Content -Encoding utf8 writes one in Windows PowerShell 5.1 and loadstring chokes on it)
    [System.IO.File]::WriteAllText($cmd, ($prefix + $src), (New-Object System.Text.UTF8Encoding($false)))
    $deadline = (Get-Date).AddSeconds($Timeout)
    while ((Get-Date) -lt $deadline -and -not (Test-Path $res)) { Start-Sleep -Milliseconds 100 }
    if (Test-Path $res) { Get-Content -Raw $res } else { "(no answer from $Client in $Timeout s)" }
}

function Read-Result {
    param([Parameter(Mandatory)][string]$Path)
    $full = Join-Path $script:Ws $Path
    if (Test-Path $full) { Get-Content -Raw $full } else { "(missing $Path)" }
}
