Genera el módulo completo de autenticación en Flutter con Riverpod y Supabase para lib/features/auth/, todo en UNA SOLA PANTALLA con tabs para Login y Registro, y agrega soporte para ingresar con Face ID / Touch ID después del primer login exitoso.

Requisitos detallados:

1. Centralización total de estilo:
   - Usa o crea AppTextField en core/widgets/app_text_field.dart (compacto: padding h16 v10, radius 12, fillColor AppColors.surface / surfaceDark)
   - Usa o crea AppButton en core/widgets/app_button.dart (compacto: padding 20x10, radius 12, background primaryTeal)
   - Crea AppSocialButton en core/widgets/app_social_button.dart para Google/Apple (ícono Ionicons.logo_google / logo_apple, texto pequeño)

2. Pantalla auth_screen.dart:
   - Tabs arriba: solo texto "Iniciar sesión" / "Crear cuenta" (Montserrat 16 w500, sin bordes visibles)
   - Línea animada debajo del tab activo: degradado teal que desliza con spring (AnimatedContainer o TabBar custom indicator)
   - Contenedor del form con altura FIJA (no cambia al cambiar tab)
   - Transición del contenido: deslizamiento horizontal suave izquierda/derecha (PageView con BouncingScrollPhysics)

3. Pestaña "Iniciar sesión":
   - Campos: AppTextField email + AppTextField contraseña (con ojo Ionicons.eye/eye-off)
   - Arriba: AppSocialButton Google + AppSocialButton Apple (Apple solo iOS o fallback)
   - Abajo fila separada: AppButton pequeño "Ingresar con Face ID / Touch ID" (ícono Ionicons.face_id o fingerprint, solo si local_auth.canCheckBiometrics es true y hay credenciales guardadas)
   - Fila diferente: texto pequeño coral "Olvidé mi contraseña" alineado derecha

4. Pestaña "Crear cuenta":
   - Campos: email, contraseña, confirmar contraseña
   - Botones sociales iguales
   - AppButton "Crear cuenta"

5. Funcionalidad biométricos (Face ID / Touch ID):
   - Usa paquete local_auth para autenticación biométrica
   - Después de login exitoso (email/password o social): pregunta si quiere activar biométricos → guarda token/flag en flutter_secure_storage
   - Al abrir app: si hay flag + biométricos disponibles → muestra botón Face ID/Touch ID
   - Al tocar: local_auth.authenticate() → si éxito, hace login automático con credenciales guardadas o refresca sesión Supabase
   - Maneja casos: no disponible, denegado, error → fallback a form normal

6. Funcionalidad general:
   - google_sign_in + sign_in_with_apple + supabase.auth.signInWithIdToken
   - Repository y providers: auth_repository_impl.dart, authStateProvider, authLoadingProvider
   - Errores: SnackBar estilizado
   - Éxito: redirige a dashboard
   - Realtime auth listener

7. SplashScreen mejorada (actualiza en main.dart):
   - Fondo degradado teal
   - Ícono Ionicons.wallet con fade-in
   - Texto "Finanzas Personal" Montserrat bold 36
   - Loading con mensaje cambiante
   - Chequea auth después de 2s mínimo → redirige a auth o dashboard

Código 100% limpio, modular, comentarios en español. Usa AppColors, AppTheme (Montserrat), Ionicons. Todo estilo centralizado. Al final indica ejecutar "flutter run" para probar splash → auth con biométricos.