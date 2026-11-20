# HW_2 one-shot setup for Windows (PowerShell).
# Run from the project root:  powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
# Prereqs: Flutter SDK on PATH, Node.js, a Firebase project with Email/Password
# sign-in enabled and a Cloud Firestore database created.

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "== 1. Generate Android platform folder (keeps lib/ untouched) ==" -ForegroundColor Cyan
if (-not (Test-Path android)) {
  flutter create . --project-name message_board --org edu.gsu.hw2 --platforms android
  # flutter create adds a counter-app widget test that does not match this app
  if (Test-Path test\widget_test.dart) { Remove-Item test\widget_test.dart }
}

Write-Host "== 2. Ensure INTERNET permission in the release manifest ==" -ForegroundColor Cyan
$manifest = 'android\app\src\main\AndroidManifest.xml'
$xml = Get-Content $manifest -Raw
if ($xml -notmatch 'android.permission.INTERNET') {
  $xml = $xml -replace '(<manifest[^>]*>)', "`$1`r`n    <uses-permission android:name=`"android.permission.INTERNET`" />"
  Set-Content $manifest $xml -NoNewline
}
# App label shown on the device
(Get-Content $manifest -Raw) -replace 'android:label="message_board"', 'android:label="Vault Board"' | Set-Content $manifest -NoNewline

Write-Host "== 3. Firebase requires minSdk 23 ==" -ForegroundColor Cyan
$gradle = Get-ChildItem android\app -Filter 'build.gradle*' | Select-Object -First 1
$g = Get-Content $gradle.FullName -Raw
$g = $g -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23'
$g = $g -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23'
Set-Content $gradle.FullName $g -NoNewline

Write-Host "== 4. Dependencies ==" -ForegroundColor Cyan
flutter pub get

Write-Host "== 5. Firebase config (project hw2-vault-board, already set up) ==" -ForegroundColor Cyan
# lib/firebase_options.dart is committed for project hw2-vault-board.
Copy-Item google-services.json android\app\google-services.json -Force
# Rules are already published. To redeploy after edits:
#   npm install -g firebase-tools; firebase login; firebase deploy --only firestore:rules

Write-Host "== 7. Analyze + build release APK ==" -ForegroundColor Cyan
flutter analyze
flutter build apk --release
Write-Host "APK: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
