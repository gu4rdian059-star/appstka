# Skrip Menjalankan Aplikasi Web TKA Secara Aman (Gateway + Flutter Web)
Write-Host "🛡️ Memulai TKA Secure API Gateway di http://localhost:8787..." -ForegroundColor Cyan
Start-Process -NoNewWindow -FilePath "D:\flutter\bin\cache\dart-sdk\bin\dart.exe" -ArgumentList "run tool/secure_api_gateway.dart" -WorkingDirectory $PSScriptRoot
Start-Sleep -Seconds 2
Write-Host "🚀 Memulai Flutter Web di http://localhost:5500..." -ForegroundColor Green
& "D:\flutter\bin\flutter.bat" run -d chrome --web-port=5500

