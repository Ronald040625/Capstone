$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$backendScript = Join-Path $root "backend\start.ps1"

Start-Process powershell -WindowStyle Normal -ArgumentList @(
    "-NoExit",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$backendScript`""
)

$backendReady = $false
for ($attempt = 0; $attempt -lt 90; $attempt++) {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:8000/health" -TimeoutSec 2
        if ($response.StatusCode -eq 200) {
            $backendReady = $true
            break
        }
    } catch {
        # El backend sigue iniciando.
    }
    Start-Sleep -Seconds 2
}

if (-not $backendReady) {
    throw "El backend no pudo iniciar. Revisa la otra ventana de PowerShell."
}

Set-Location (Join-Path $root "corestream_mobile")

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCommand) {
    $flutter = $flutterCommand.Source
} else {
    $flutter = Get-ChildItem (Join-Path $env:USERPROFILE ".codex\.chatgpt-projects\*\tools\flutter\bin\flutter.bat") -File -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $flutter) {
    throw "No se encontró Flutter. Instálalo, agrégalo al PATH y vuelve a ejecutar este archivo."
}

& $flutter pub get
& $flutter run -d edge --dart-define=CS_API_URL=http://localhost:8000
