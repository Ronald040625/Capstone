# CoreStream Mobile

MVP en Flutter para gestionar proyectos, tickets e incidencias.

## Requerimientos cubiertos

- APP-15: listado, filtro de incidencias propias y detalle con comentarios.
- APP-16: ciclo de vida y comentarios de incidencias.
- APP-17: carga de trabajo del equipo.
- APP-20 / TRV-04: cambio de idioma ES/EN con persistencia.
- APP-21: cierre de sesión y limpieza local de la sesión.

## Ejecutar

Modo demo sin servidor:

```bash
flutter pub get
flutter run -d edge
```

Con el backend ejecutándose en el puerto 8000:

```bash
flutter run --dart-define=CS_API_URL=http://localhost:8000
```

En modo API, el selector de usuarios crea una sesión real y los cambios quedan
guardados en la base de datos.

## Verificar

```bash
flutter analyze
flutter test
flutter build web --release
```
