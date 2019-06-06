if (!(Test-Path -Path $PROFILE.AllUsersCurrentHost))
{ New-Item -Type File -Path $PROFILE.AllUsersCurrentHost -Force }
Set-Content -Path $PROFILE.AllUsersCurrentHost -value "Write-Host 'hi'"