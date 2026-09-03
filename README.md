# StyleStore Mobile App (Flutter)

Aplicación móvil multiplataforma desarrollada en **Flutter** para el sistema de autenticación centralizada de StyleStore.

---

## 📱 Características

- **Autenticación Completa:** Pantallas de Login y Registro con validación en tiempo real y visibilidad de contraseñas.
- **Tokens Cifrados:** Almacenamiento seguro de tokens JWT (`access_token` y `refresh_token`) usando `flutter_secure_storage` (Keychain en iOS / EncryptedSharedPreferences en Android).
- **Gestión de Estado Reactiva:** Implementada con `provider` para suscripción y actualización instantánea de estado.
- **Resolución Dinámica de URL:** Configurada para resolver automáticamente `10.0.2.2` en emulador Android y `localhost` en Desktop/Web.

---

## 🚀 Cómo Ejecutar la App Móvil

### Prerrequisitos
1. Tener instalado [Flutter SDK](https://docs.flutter.dev/get-started/install/windows/mobile).
2. Tener configurado Android Studio o VS Code con el plugin de Flutter.

### Pasos

1. Instalar dependencias:
   ```bash
   cd mobile
   flutter pub get
   ```

2. Ejecutar pruebas unitarias:
   ```bash
   flutter test
   ```

3. Iniciar la aplicación:
   ```bash
   flutter run
   ```
