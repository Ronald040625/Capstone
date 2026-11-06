$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function New-CoreStreamVenv {
    foreach ($version in @("-3.13", "-3.12", "-3.11", "-3")) {
        & py $version -c "import sys" *> $null
        if ($LASTEXITCODE -ne 0) {
            continue
        }
        & py $version -m venv .venv
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
    }
    return $false
}

if (Test-Path ".venv\Scripts\python.exe") {
    $python = ".venv\Scripts\python.exe"
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    if (-not (New-CoreStreamVenv)) {
        throw "No se pudo crear el entorno de Python. Instala Python 3.12 o 3.13."
    }
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

if ($env:DATABASE_URL) {
    Write-Host "Base de datos: PostgreSQL"
} else {
    Write-Host "Base de datos: SQLite local (backend\corestream.db)"
}

& $python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
