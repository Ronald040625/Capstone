# CoreStream

Proyecto Capstone del Equipo 7 con aplicación Flutter, API FastAPI y base de datos persistente.

## Primera instalación en Windows

Necesitas Git, Python 3, Flutter estable y Microsoft Edge.

Comprueba las herramientas disponibles:

```powershell
git --version
python --version
flutter --version
```

Si Flutter no está instalado, puedes dejarlo dentro de tu carpeta de usuario sin permisos de administrador:

```powershell
cd "$env:USERPROFILE"
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git flutter
```

El lanzador detecta automáticamente Flutter en esa ubicación. La primera ejecución descarga componentes adicionales y puede tardar varios minutos.

Clona CoreStream en el Escritorio:

```powershell
cd "$env:USERPROFILE\Desktop"
git clone https://github.com/Ronald040625/Capstone.git
cd Capstone
```

Inicia el proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File .\INICIAR_MVP.ps1
```

Se abrirán dos ventanas de PowerShell: una para el backend y otra para Flutter. Deben permanecer abiertas mientras utilices CoreStream. El navegador se abre automáticamente cuando el backend está listo.

## Próximos inicios

```powershell
cd "$env:USERPROFILE\Desktop\Capstone"
git pull origin main
powershell -ExecutionPolicy Bypass -File .\INICIAR_MVP.ps1
```

## Comprobación rápida

El backend funciona correctamente si esta dirección muestra los usuarios de prueba:

```text
http://localhost:8000/users/
```

Si una pestaña antigua muestra un error, espera hasta ver `Application startup complete` en la ventana del backend y recarga el navegador con `Ctrl + R`.

## Base de datos

CoreStream crea automáticamente `backend\corestream.db`. Cada computador mantiene su propia base local y este archivo no se sube a GitHub.

También se puede usar PostgreSQL configurando la variable `DATABASE_URL`.

## Componentes

- `corestream_mobile`: aplicación Flutter.
- `backend`: API, autenticación y persistencia.
- `Fase 1`: documentación de la primera fase.
- `Fase 2`: documentación y evidencias de desarrollo.
