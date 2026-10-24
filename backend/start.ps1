$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (Test-Path ".venv\Scripts\python.exe") {
    $python = ".venv\Scripts\python.exe"
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    py -3 -m venv .venv
    $python = ".venv\Scripts\python.exe"
} else {
    $systemPython = Get-Command python -ErrorAction SilentlyContinue
    if ($systemPython -and $systemPython.Source -notlike "*WindowsApps*") {
        python -m venv .venv
        $python = ".venv\Scripts\python.exe"
    } else {
        $codexPython = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
        if (-not (Test-Path $codexPython)) {
            throw "No se encontró Python 3. Instálalo y vuelve a ejecutar este archivo."
        }
        $python = $codexPython
        if (-not (Test-Path ".packages\fastapi")) {
            & $python -m pip install -r requirements.txt --target .packages
        }
        $env:PYTHONPATH = (Resolve-Path ".packages").Path
    }
}

if ($python -like "*.venv*") {
    & $python -m pip install -r requirements.txt
}
& $python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
