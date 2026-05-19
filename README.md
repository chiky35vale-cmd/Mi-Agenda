# Mi Agenda

Aplicacion Android de recordatorios creada con Flutter.

## Que incluye esta version

- Crear recordatorios con titulo, fecha y hora.
- Editar recordatorios existentes.
- Marcar recordatorios como completados o reactivarlos.
- Eliminar recordatorios.
- Guardado local con SQLite.
- Notificaciones locales programadas en Android.
- Interfaz inicial en espanol.

## Estructura principal

- `lib/src/models`: modelo `Reminder`.
- `lib/src/data`: repositorio SQLite.
- `lib/src/services`: servicio de notificaciones.
- `lib/src/controllers`: controlador principal de estado.
- `lib/src/screens`: pantallas del listado y formulario.

## Comandos utiles

Desde `C:\Users\av\Desktop\IA\Aplicaciones IA\Mi Agenda`:

```powershell
$env:Path = 'C:\Program Files\Git\cmd;' + $env:Path
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:ANDROID_SDK_ROOT = (Resolve-Path '.\.android-sdk').Path
$env:ANDROID_HOME = $env:ANDROID_SDK_ROOT
Set-Location .\app
..\tools\flutter\bin\flutter.bat analyze
..\tools\flutter\bin\flutter.bat test
..\tools\flutter\bin\flutter.bat run
```

Para compilar una APK:

```powershell
Set-Location 'C:\Users\av\Desktop\IA\Aplicaciones IA\Mi Agenda\app'
..\tools\flutter\bin\flutter.bat build apk
```

## APK generada

- Ruta actual: `build\app\outputs\flutter-apk\app-release.apk`

Ruta absoluta:

- `C:\Users\av\Desktop\IA\Aplicaciones IA\Mi Agenda\app\build\app\outputs\flutter-apk\app-release.apk`

## Emulador preparado

- AVD creado: `recordatorio_api36`

Si quieres arrancarlo manualmente:

```powershell
Set-Location 'C:\Users\av\Desktop\IA\Aplicaciones IA\Mi Agenda'
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:ANDROID_SDK_ROOT = (Resolve-Path '.\.android-sdk').Path
$env:ANDROID_HOME = $env:ANDROID_SDK_ROOT
.\.android-sdk\emulator\emulator.exe -avd recordatorio_api36
```

## Notas

- La APK de prueba se firma con la configuracion debug por defecto.
- La app esta preparada para crecer en el futuro sin rehacer almacenamiento y notificaciones.
- Si Android pide permisos de notificaciones o alarmas exactas, aceptalos para que los avisos funcionen mejor.
