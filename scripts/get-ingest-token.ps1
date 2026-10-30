# Creates an ingest token for the iOS Shortcut. Run in Windows PowerShell:
#   powershell -ExecutionPolicy Bypass -File scripts\get-ingest-token.ps1
# Signs in with your owner email and password, asks the rotate-token function for a new token and prints it once.
# Any older token stops working. Nothing is written to disk.

$ErrorActionPreference = "Stop"

$base = "https://evepfssanoffnwtqjmyq.supabase.co"
$publishableKey = "sb_publishable_ZmF7b-XpcsFn54t2HQWMRw_URDNC8nF"  # public client key, not a secret

$email = Read-Host "Owner email"
$secure = Read-Host "Password" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
$password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

function Send-Json($uri, $headers, $obj) {
  # Send UTF-8 bytes explicitly: Windows PowerShell 5.1 would otherwise encode the body as ISO-8859-1.
  $bytes = [Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json -Compress))
  Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json; charset=utf-8" -Body $bytes
}

try {
  $login = Send-Json "$base/auth/v1/token?grant_type=password" @{ apikey = $publishableKey } @{ email = $email; password = $password }
} catch {
  Write-Host "Sign-in failed. Check the email and password." -ForegroundColor Red
  exit 1
}

try {
  $result = Send-Json "$base/functions/v1/rotate-token" @{ apikey = $publishableKey; Authorization = "Bearer $($login.access_token)" } @{ label = "iPhone" }
} catch {
  Write-Host "Could not create the token. Is the rotate-token function deployed?" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "Ingest token (shown once, copy it now):"
Write-Host $result.token
Write-Host ""
Write-Host "Any earlier token no longer works: update the X-Ingest-Token header in your Shortcut(s)."
