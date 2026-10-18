param([Parameter(Mandatory=$true)][string]$Address)
$ErrorActionPreference = 'Stop'
$parsed = [System.Net.IPAddress]::Parse($Address)
if ($parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { throw 'Use the computer LAN IPv4 address.' }
$directory = Join-Path $PSScriptRoot '../build/island-production/tls'
New-Item -ItemType Directory -Force -Path $directory | Out-Null
@"
[req]
distinguished_name=dn
x509_extensions=extensions
prompt=no
[dn]
CN=Californication Local Preview
[extensions]
subjectAltName=IP:$Address,IP:127.0.0.1,DNS:localhost
"@ | Set-Content -LiteralPath (Join-Path $directory 'openssl.cnf') -Encoding ascii
& openssl req -x509 -newkey rsa:2048 -nodes -config (Join-Path $directory 'openssl.cnf') -keyout (Join-Path $directory 'key.pem') -out (Join-Path $directory 'cert.pem') -days 7
if ($LASTEXITCODE -ne 0) { throw 'Local certificate generation failed.' }
Write-Output "Run node tools/serve_production_web.mjs --https then open https://${Address}:8068/index.html"
