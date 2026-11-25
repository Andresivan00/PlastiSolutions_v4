# PlastiSolutions

App móvil de inventario para PlastiSolutions hecha con Flutter, **Firebase Authentication** (correo y contraseña) y **Cloud Firestore** (base de datos remota).

## Requisitos

- Flutter 3.44 o superior (`flutter --version`)
- Un celular Android (Android 7.0 o superior) o un emulador con conexión a internet
- Un proyecto de Firebase con:
  - Authentication → método **Correo electrónico/contraseña** activado
  - **Firestore Database** creada
  - Las reglas de `firestore.rules` publicadas

## Configuración de Firebase

1. En la consola de Firebase, registra una app Android con el nombre de paquete
   `com.plastisolutions.inventario_app`.
2. Descarga `google-services.json` y colócalo en `android/app/`.
3. En Firestore → Reglas, pega el contenido de `firestore.rules` y publica.

La app lee la configuración directamente de `google-services.json`; no hay que editar código.

## Cómo ejecutar

```bash
flutter clean
flutter pub get
flutter run
```

Para generar un instalable:

```bash
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.

> La app está configurada solo para Android. No se ejecuta en Chrome.

## Estructura de datos (Firestore)

| Colección | Campos |
|---|---|
| `proveedores` | uid, nombre, telefono, correo, creadoEn, actualizadoEn |
| `productos` | uid, nombre, precio, stock, proveedorId, proveedorNombre, creadoEn, actualizadoEn |
| `movimientos` | uid, productoId, productoNombre, tipo (entrada/salida), cantidad, stockResultante, nota, fecha |

`uid` identifica al usuario dueño del documento; las reglas de seguridad solo permiten a cada usuario leer y modificar sus propios datos.

## Funcionalidades

- Inicio de sesión, registro de cuenta y cierre de sesión
- Dashboard con totales
- CRUD de productos y proveedores sobre Firestore, con confirmación antes de eliminar
- Detalle de producto
- Movimientos de inventario (entradas y salidas) que actualizan el stock en una transacción
- Búsqueda de productos por nombre
- Sincronización en tiempo real: los cambios hechos en la nube se reflejan en la app sin recargar
- Reglas de seguridad: sin sesión no se puede leer ni escribir nada
