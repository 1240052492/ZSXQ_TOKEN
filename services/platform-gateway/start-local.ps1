$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$env:PORT = '8787'
$env:NEW_API_BASE_URL = 'http://127.0.0.1:3001'
$env:CANVAS_CALLBACK_URL = 'http://127.0.0.1:8787/sso/callback'
$env:CANVAS_APP_URL = 'http://127.0.0.1:3013/'
$out = Join-Path $PSScriptRoot 'platform-gateway.out.log'
$err = Join-Path $PSScriptRoot 'platform-gateway.err.log'
$process = Start-Process -FilePath 'node.exe' -ArgumentList (Join-Path $root 'platform-gateway\src\server.js') -WorkingDirectory $root -RedirectStandardOutput $out -RedirectStandardError $err -PassThru -WindowStyle Hidden
$process.Id | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'platform-gateway.pid')
Write-Output "Platform gateway started with PID $($process.Id) on http://127.0.0.1:8787"
