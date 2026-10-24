# Activación de notificaciones push de StyleStore

La aplicación ya incluye Firebase Cloud Messaging, registro/desregistro del dispositivo,
notificaciones visibles en primer plano y apertura de rutas al tocar la notificación. Para
recibir mensajes reales se debe enlazar el binario con un proyecto Firebase y proporcionar
al backend una cuenta de servicio. Ninguna clave real debe guardarse en Git.

## 1. Firebase Console

1. Proyecto creado: `StyleStore` (`stylestore-99387`, número `1006137634795`).
2. Aplicación Android registrada con el `applicationId` declarado en
   `android/app/build.gradle.kts`: `com.stylestore.stylestore_mobile`.
   App ID: `1:1006137634795:android:1027e57e0ba51e8e75f3ae`.
3. Activar Cloud Messaging.
4. Copiar los valores de configuración de la aplicación: API key, App ID, Sender ID,
   Project ID y Storage Bucket.
5. En Configuración del proyecto > Cuentas de servicio, generar una clave JSON exclusiva
   para el backend. Guardarla como secreto; nunca dentro de este repositorio.

Los archivos nativos y las cuentas de servicio están excluidos explícitamente en
`.gitignore`. La creación del proyecto, el registro Android, la configuración local y la
credencial protegida del backend en Railway quedaron terminados el 23 de octubre de 2026.
La inicialización de Firebase Admin también fue verificada. La recepción física en primer
plano quedó comprobada en el Samsung el 23 de octubre de 2026, incluida la aparición en la
barra de notificaciones. Falta repetir y documentar la prueba en segundo plano y con la
aplicación cerrada.

La configuración Android local se obtiene con la CLI oficial y el complemento nativo ya
está activado en Gradle:

```powershell
firebase apps:sdkconfig ANDROID `
  1:1006137634795:android:1027e57e0ba51e8e75f3ae `
  --out android/app/google-services.json
```

Ese archivo permanece ignorado por Git. Con él presente, `Firebase.initializeApp()` usa la
configuración nativa y no hace falta pasar secretos mediante `--dart-define` en Android.

## 2. Compilar la aplicación

Con `android/app/google-services.json` presente localmente, Android se compila sin valores
Firebase en la línea de comandos:

```powershell
flutter build apk --release
```

Para iOS también se puede proporcionar `FIREBASE_IOS_BUNDLE_ID`. Si se usan los archivos
nativos generados por FlutterFire (`google-services.json` / `GoogleService-Info.plist`), la
inicialización automática también es compatible.

## 3. Configurar Railway

La producción usa la siguiente variable protegida en Railway:

```text
FIREBASE_SERVICE_ACCOUNT_B64=<json_completo_en_base64>
```

Como alternativa se puede usar `FIREBASE_SERVICE_ACCOUNT_JSON` con el JSON completo. Usar
solo una de las dos variables. La variable Base64 ya está instalada, el despliegue terminó
correctamente y se validó la inicialización de Firebase Admin sin exponer la credencial.

## 4. Prueba física obligatoria

1. Instalar la APK compilada con los valores Firebase.
2. Iniciar sesión y aceptar el permiso de notificaciones.
3. Confirmar en el backend que existe un registro en `push_devices`.
4. Completar una compra/reserva que genere una notificación.
5. Verificar recepción con la app abierta, en segundo plano y cerrada.
6. Cerrar sesión y confirmar que el dispositivo queda desregistrado.

Para una demostración repetible, abrir **Perfil** y pulsar **Probar notificación push**. El
endpoint autenticado solo envía la prueba al usuario y tenant activos; no modifica compras,
inventario, reservas ni delivery.

El código funciona de forma degradada cuando Firebase no está configurado: el inicio de
sesión y las notificaciones internas continúan, pero no se afirma que haya push real hasta
completar esta prueba con credenciales externas.
