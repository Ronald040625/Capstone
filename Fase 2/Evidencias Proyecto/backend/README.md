# Backend CoreStream MVP

API FastAPI con persistencia para usuarios, sesiones, proyectos, tickets,
incidencias, comentarios y notificaciones.

## Ejecutar en Windows

Desde la carpeta `backend`:

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

La API queda disponible en `http://localhost:8000` y la documentación en
`http://localhost:8000/docs`.

La primera ejecución crea `corestream.db` y carga datos de demostración. El
archivo se conserva al cerrar el servidor, por lo que los cambios no se pierden.

## PostgreSQL

Para usar PostgreSQL, define `DATABASE_URL` antes de iniciar:

```powershell
$env:DATABASE_URL="postgresql://usuario:clave@servidor:5432/corestream"
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

## Usuarios iniciales

| Usuario | Correo | Clave | Rol |
|---|---|---|---|
| Ana Torres | ana@corestream.cl | CoreStream123! | ADMIN |
| Luis Vega | luis@corestream.cl | CoreStream123! | GROUP_LEADER |
| Diego Ramos | diego@corestream.cl | CoreStream123! | DEVELOPER |
| Sofía Márquez | sofia@corestream.cl | CoreStream123! | DEVELOPER |

La interfaz usa el selector de usuarios y solicita una sesión al backend. El
endpoint de correo y contraseña también está disponible.

## Pruebas

```powershell
.venv\Scripts\python.exe -m pytest -q
```
