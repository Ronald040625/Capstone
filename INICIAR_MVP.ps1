$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$backendScript = Join-Path $root "backend\start.ps1"

Start-Process powershell -WindowStyle Normal -ArgumentList @(
    "-NoExit",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$backendScript`""
)

Start-Sleep -Seconds 4
Set-Location (Join-Path $root "corestream_mobile")

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCommand) {
    $flutter = $flutterCommand.Source
} else {
    $flutter = Get-ChildItem (Join-Path $env:USERPROFILE ".codex\chatgpt-projects\*\tools\flutter\bin\flutter.bat") -File -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $flutter) {
    throw "No se encontró Flutter. Instálalo, agrégalo al PATH y vuelve a ejecutar este archivo."
}

& $flutter pub get
& $flutter run -d edge --dart-define=CS_API_URL=http://localhost:8000
