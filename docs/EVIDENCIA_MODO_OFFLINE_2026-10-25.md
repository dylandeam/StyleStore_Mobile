# Evidencia física del modo offline móvil — 25/10/2026

## Hallazgo reproducido

En el Samsung SM-G996B, al desconectar Wi-Fi y datos móviles, la lista del catálogo seguía
visible pero la ficha de producto intentaba consultar Railway. El resultado era un
`SocketException`, la imagen dependía de red y el botón de carrito tampoco tenía persistencia
local.

## Corrección

- La ficha busca el producto en el snapshot SQLite aislado por `empresa + usuario` cuando la
  API no está disponible.
- Las imágenes de catálogo se precargan y conservan en caché de disco; las tarjetas y fichas
  usan `CachedNetworkImage`.
- SQLite versión 2 incorpora el último snapshot de carrito y adiciones offline pendientes.
- Agregar una prenda sin red actualiza el carrito local y persiste aunque la app se cierre.
- Al recuperar conectividad, las adiciones pendientes se envían al backend y se eliminan de la
  cola local solo después de una respuesta exitosa.
- El checkout permanece deshabilitado hasta sincronizar y confirmar stock en el servidor.
- El resumen ya no inventa una distancia fija de 4,5 km: el delivery se calcula después con la
  ubicación real del cliente.

## Prueba física

1. Se abrió el catálogo con conexión para guardar datos e imágenes.
2. Se deshabilitaron Wi-Fi y datos móviles mediante ADB.
3. La ficha `PROD-0001` abrió desde SQLite, mostró la fotografía cacheada y el aviso
   `Detalle guardado en el dispositivo`.
4. `Al Carrito` añadió una unidad; el carrito indicó una prenda pendiente y bloqueó el pago.
5. Al reactivar la conexión, la unidad se sincronizó: las dos líneas local/remota se
   consolidaron en una línea del servidor con cantidad 2 y el checkout volvió a habilitarse.

## Validación

- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub`: 14/14 pruebas aprobadas.
- APK release: versión `1.0.8+9`, 99,7 MB.
- SHA-256: `088240BBBCC326036FAFA50A5396723F5A5246E58A100106E6099F4AFD75F7AA`.
- Instalación conservando datos: `adb install -r` -> `Success`.

La prueba no ejecutó checkout ni creó un pedido; únicamente incrementó el carrito de la cuenta
de demostración de una a dos unidades para verificar la sincronización.
