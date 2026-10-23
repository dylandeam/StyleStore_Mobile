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
`.gitignore`. La creación del proyecto y el registro Android están terminados; todavía se
debe descargar la configuración local, instalar la credencial del backend en Railway y
completar la prueba física antes de declarar FCM operativo de extremo a extremo.

## 2. Compilar la aplicación

Ejemplo para Android (sustituir todos los valores):

```powershell
flutter build apk --release `
  --dart-define=FIREBASE_API_KEY=... `
  --dart-define=FIREBASE_APP_ID=... `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... `
  --dart-define=FIREBASE_PROJECT_ID=... `
  --dart-define=FIREBASE_STORAGE_BUCKET=...
```

Para iOS también se puede proporcionar `FIREBASE_IOS_BUNDLE_ID`. Si se usan los archivos
nativos generados por FlutterFire (`google-services.json` / `GoogleService-Info.plist`), la
inicialización automática también es compatible.

## 3. Configurar Railway

Codificar el JSON de la cuenta de servicio en Base64 y definir en Railway:

```text
FIREBASE_SERVICE_ACCOUNT_B64=<json_completo_en_base64>
```

Como alternativa se puede usar `FIREBASE_SERVICE_ACCOUNT_JSON` con el JSON completo. Usar
solo una de las dos variables. Al redeplegar, el backend inicializa Firebase Admin y envía
notificaciones a los dispositivos registrados del usuario y tenant correspondientes.

## 4. Prueba física obligatoria

1. Instalar la APK compilada con los valores Firebase.
2. Iniciar sesión y aceptar el permiso de notificaciones.
3. Confirmar en el backend que existe un registro en `push_devices`.
4. Completar una compra/reserva que genere una notificación.
5. Verificar recepción con la app abierta, en segundo plano y cerrada.
6. Cerrar sesión y confirmar que el dispositivo queda desregistrado.

El código funciona de forma degradada cuando Firebase no está configurado: el inicio de
sesión y las notificaciones internas continúan, pero no se afirma que haya push real hasta
completar esta prueba con credenciales externas.
