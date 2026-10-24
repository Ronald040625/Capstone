# CoreStream

Proyecto Capstone del Equipo 7 con aplicación Flutter, API FastAPI y base de
datos persistente.

## Inicio rápido

Requisitos: Git, Python 3, Flutter y Microsoft Edge.

```powershell
powershell -ExecutionPolicy Bypass -File .\INICIAR_MVP.ps1
```

El script inicia la API en `http://localhost:8000` y abre la aplicación en
Microsoft Edge conectada a la base de datos.

## Componentes

- `corestream_mobile`: aplicación Flutter.
- `backend`: API, autenticación y persistencia.
- `Fase1`: documentación del proyecto.

Por defecto el backend utiliza SQLite para funcionar sin servicios externos.
También acepta PostgreSQL mediante la variable `DATABASE_URL`.
