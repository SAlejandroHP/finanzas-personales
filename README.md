# Finanzas Personales (App Flutter)

Aplicación móvil para la gestión integral de finanzas personales, desarrollada en Flutter.

## 📚 Documentación y Normas

Para entender la arquitectura, reglas de negocio y estándares de código, consulta los siguientes documentos en la raíz del proyecto o en la carpeta `docs/`:

1.  **[Convenciones del Proyecto](convenciones_proyecto.md)**:
    *   Estructura de carpetas y nomenclatura.
    *   **Sistema de Diseño**: Uso obligatorio de `AppColors` para colores, fuentes y estilos.
    *   Patrones de gestión de estado (Riverpod).

2.  **[Lógica de la Aplicación](logica_app.md)** (si existe):
    *   Reglas de negocio financiero y flujos de usuario.

## 🎨 Sistema de Diseño (Design System)

La identidad visual de la aplicación está centralizada en **[lib/core/constants/app_colors.dart](lib/core/constants/app_colors.dart)**.

*   Este archivo funciona como la **única fuente de verdad** (similar a un `main.css`).
*   **Contiene**:
    *   Paleta de Colores (`primary`, `accent`, etc.).
    *   Tipografía (`titleLarge`, `bodyMedium`, etc.).
    *   Bordes y Formas (`radiusSmall`, `cardElevation`).
    *   Espaciados (`cardPadding`, `pagePadding`).
*   **Regla**: No se deben usar valores literales ("hardcoded") en las vistas. Siempre referenciar `AppColors`.

### ⚠️ Refactorización y Casos Especiales (Manual)
Existen áreas donde la automatización puede fallar o no ser deseable. En estos casos, se debe intervenir manualmente siguiendo el estándar:

*   **Gráficos y Charts**: Si se usan librerías externas (como `fl_chart`), los colores deben mapearse manualmente desde `AppColors`.
*   **TextSpans Compuestos**: En textos con múltiples estilos dentro de un solo párrafo, verificar que cada `TextStyle` use una constante de `AppColors`.
*   **Paquetes de Terceros**: Plugins como Google Maps o selectores de archivos pueden requerir colores específicos; intenta usar el tono más cercano de la paleta.
*   **Iconos con Tamaños Especiales**: Los tamaños de iconos que no coincidan con la tipografía deben definirse en `AppColors` antes de usarse.

## 🚀 Comenzando

Este proyecto utiliza Flutter. Asegúrate de tener el entorno configurado.

1.  **Instalar dependencias**:
    ```bash
    flutter pub get
    ```

2.  **Ejecutar la aplicación**:
    ```bash
    flutter run
    ```

## 🛠 Estructura Principal

*   `lib/core`: Componentes globales, constantes y utilidades.
*   `lib/features`: Módulos funcionales (Auth, Dashboard, Transacciones).
*   `lib/shared`: Modelos y providers compartidos.
