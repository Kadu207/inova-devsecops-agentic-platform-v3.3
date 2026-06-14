param(
  [Parameter(Mandatory = $true)]
  [string]$PayloadJson,
  [string]$WebhookUrl = "https://skillsmcp.inovatitech.com.br/webhook/publish",
  [string]$EnvFile = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not $EnvFile) {
  $EnvFile = Join-Path $root ".env.staging"
}
if (-not (Test-Path $EnvFile)) {
  Write-Error "Arquivo de env nao encontrado: $EnvFile"
}

$secretLine = Get-Content $EnvFile | Where-Object { $_ -match '^WEBHOOK_SECRET=' } | Select-Object -First 1
if (-not $secretLine) {
  Write-Error "WEBHOOK_SECRET ausente em $EnvFile"
}
$secret = ($secretLine -replace '^WEBHOOK_SECRET=', '').Trim()

$body = $PayloadJson.Trim()
$null = $body | ConvertFrom-Json

$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$hmac = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($secret))
$sig = 'sha256=' + ([BitConverter]::ToString($hmac.ComputeHash($bytes)) -replace '-', '').ToLower()

$tmp = [System.IO.Path]::GetTempFileName()
try {
  [System.IO.File]::WriteAllText($tmp, $body, [System.Text.UTF8Encoding]::new($false))
  $response = curl.exe -sS -w "`n%{http_code}" -X POST $WebhookUrl `
    -H "Content-Type: application/json" `
    -H "X-Inova-Signature: $sig" `
    --data-binary "@$tmp"
} finally {
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}

$lines = @($response -split "`n")
$statusCode = $lines[-1]
$respBody = ($lines[0..($lines.Length - 2)] -join "`n").Trim()

Write-Host $respBody
if ($statusCode -notmatch '^2') {
  Write-Error "Webhook HTTP $statusCode : $respBody"
}

return ($respBody | ConvertFrom-Json)
