# Creates an ingest token for the iOS Shortcut. Run in Windows PowerShell:
#   powershell -ExecutionPolicy Bypass -File scripts\get-ingest-token.ps1
# Signs in with your owner email and password, asks the rotate-token function for a new token and prints it once.
# Any older token stops working. Nothing is written to disk.

$base = "https://evepfssanoffnwtqjmyq.supabase.co"
$publishableKey = "sb_publishable_ZmF7b-XpcsFn54t2HQWMRw_URDNC8nF"  # public client key, not a secret

$email = Read-Host "Owner email"
$secure = Read-Host "Password" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
$password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

$login = Invoke-RestMethod -Method Post -Uri "$base/auth/v1/token?grant_type=password" `
  -Headers @{ apikey = $publishableKey } -ContentType "application/json" `
  -Body (@{ email = $email; password = $password } | ConvertTo-Json)

$result = Invoke-RestMethod -Method Post -Uri "$base/functions/v1/rotate-token" `
  -Headers @{ apikey = $publishableKey; Authorization = "Bearer $($login.access_token)" } `
  -ContentType "application/json" -Body '{"label":"iPhone"}'

Write-Host ""
Write-Host "Ingest token (shown once, copy it now):"
Write-Host $result.token
