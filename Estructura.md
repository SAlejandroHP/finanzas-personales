# Estructura de la Aplicación de Finanzas

> **Última actualización:** 2026-02-15  
> Este documento mantiene la estructura actual del proyecto Flutter de gestión financiera.

---

## 📁 Estructura General

```
finanzas/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart
│   │   │   └── app_sizes.dart
│   │   ├── network/
│   │   │   ├── belvo_client.dart         # Cliente para API de Belvo (bancos)
│   │   │   └── supabase_client.dart      # Cliente de Supabase
│   │   ├── providers/
│   │   │   └── ui_provider.dart          # Provider para estado UI global
│   │   ├── theme/
│   │   │   ├── app_theme.dart            # Tema claro/oscuro de la app
│   │   │   └── extensions.dart           # Extensiones de tema
│   │   ├── utils/
│   │   │   └── toast_utils.dart          # Utilidades para notificaciones toast
│   │   └── widgets/                      # Widgets reutilizables
│   │       ├── app_button.dart           # Botón estándar de la app
│   │       ├── app_shell.dart            # Shell principal con navegación
│   │       ├── app_social_button.dart    # Botón para login social
│   │       ├── app_text_field.dart       # Campo de texto estándar
│   │       ├── app_toast.dart            # Widget de notificación toast
│   │       ├── bank_logo.dart            # Widget para mostrar logos de bancos
│   │       └── loading_indicator.dart    # Indicador de carga
│   │
│   ├── features/
│   │   ├── auth/                         # Autenticación
│   │   │   ├── data/
│   │   │   │   └── repositories/
│   │   │   │       ├── auth_repository.dart
│   │   │   │       └── auth_repository_impl.dart
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       │   └── auth_provider.dart
│   │   │       └── screens/
│   │   │           └── auth_screen.dart  # Pantalla de login/registro
│   │   │
│   │   ├── dashboard/                    # Dashboard principal
│   │   │   └── presentation/
│   │   │       └── screens/
│   │   │           ├── dashboard_screen.dart      # Pantalla principal con resumen
│   │   │           └── notifications_screen.dart  # Pantalla de advertencias/notificaciones
│   │   │
│   │   ├── accounts/                     # Cuentas bancarias
│   │   │   ├── models/
│   │   │   │   ├── account_model.dart
│   │   │   │   ├── bank_model.dart       # Modelo para bancos (Belvo)
│   │   │   │   └── currency_model.dart
│   │   │   ├── data/
│   │   │   │   └── accounts_repository.dart
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       │   ├── accounts_provider.dart
│   │   │       │   ├── banks_provider.dart        # Provider para lista de bancos
│   │   │       │   └── currencies_provider.dart
│   │   │       ├── screens/
│   │   │       │   ├── accounts_list_screen.dart  # Lista de cuentas con logos
│   │   │       │   └── account_form_screen.dart
│   │   │       └── widgets/
│   │   │           ├── account_card.dart          # Card de cuenta
│   │   │           └── account_form_bottom_sheet.dart
│   │   │
│   │   ├── categories/                   # Categorías de transacciones
│   │   │   ├── models/
│   │   │   │   └── category_model.dart
│   │   │   ├── data/
│   │   │   │   └── categories_repository.dart
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       │   └── categories_provider.dart
│   │   │       ├── screens/
│   │   │       │   └── categories_list_screen.dart # Grid de categorías
│   │   │       └── widgets/
│   │   │           ├── category_card.dart
│   │   │           └── category_form_bottom_sheet.dart
│   │   │
│   │   ├── transactions/                 # Transacciones (incluye recurrentes)
│   │   │   ├── models/
│   │   │   │   └── transaction_model.dart
│   │   │   ├── data/
│   │   │   │   └── transactions_repository.dart
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       │   ├── transactions_provider.dart
│   │   │       │   ├── transaction_filters_provider.dart
│   │   │       │   └── recurring_warnings_provider.dart  # Advertencias de transacciones recurrentes
│   │   │       ├── screens/
│   │   │       │   ├── transaction_list_screen.dart
│   │   │       │   └── recurring_transactions_screen.dart # Pantalla de transacciones recurrentes
│   │   │       └── widgets/
│   │   │           ├── transaction_form_sheet.dart       # Formulario con toggle recurrente
│   │   │           ├── transaction_tile.dart             # Tile con warnings
│   │   │           └── transaction_filters_bar.dart
│   │   │
│   │   └── settings/                     # Configuración general
│   │       └── presentation/
│   │           └── screens/
│   │               └── settings_screen.dart # Ajustes de tema, etc.
│   │
│   ├── shared/                           # Recursos compartidos
│   │   └── models/
│   │       └── user_model.dart
│   │
│   └── main.dart                         # Entry point de la aplicación
│
├── migrations/                           # Migraciones de base de datos (Supabase)
├── .vscode/                              # Configuración de VS Code
├── analysis_options.yaml                 # Opciones de análisis de Dart
├── pubspec.yaml                          # Dependencias del proyecto
├── BELVO_INTEGRATION.md                  # Documentación de integración con Belvo
└── Estructura.md                         # Este archivo
```

---

## 📊 Desglose por Feature

### 🔐 Auth
- **Purpose:** Manejo de autenticación de usuarios
- **Estado:** Implementado con Supabase Auth
- **Archivos clave:** `auth_screen.dart`, `auth_provider.dart`

### 📈 Dashboard
- **Purpose:** Vista principal con resumen financiero
- **Componentes:**
  - Balance total de cuentas
  - Ingresos/gastos del mes
  - Transacciones pendientes
  - Mini-vista de cuentas
  - Enlace a notificaciones/advertencias
- **Archivos clave:** `dashboard_screen.dart`, `notifications_screen.dart`

### 💳 Accounts
- **Purpose:** Gestión de cuentas bancarias
- **Características:**
  - Lista de cuentas con logos de bancos (Belvo API)
  - Soporte multi-moneda
  - CRUD completo de cuentas
- **Archivos clave:** `accounts_list_screen.dart`, `bank_logo.dart`, `banks_provider.dart`

### 🏷️ Categories
- **Purpose:** Categorías para clasificar transacciones
- **UI:** Grid de 2 columnas con iconos Material
- **Archivos clave:** `categories_list_screen.dart`, `category_card.dart`

### 💰 Transactions
- **Purpose:** Gestión de transacciones (regulares y recurrentes)
- **Características:**
  - Formulario con toggle para transacciones recurrentes
  - Sistema de advertencias para transacciones recurrentes
  - Filtros de transacciones
  - Vista de transacciones pendientes
  - Pantalla específica para transacciones recurrentes
- **Archivos clave:** 
  - `transaction_form_sheet.dart` (con toggle recurrente)
  - `transaction_tile.dart` (con warnings)
  - `recurring_warnings_provider.dart`
  - `recurring_transactions_screen.dart`

### ⚙️ Settings
- **Purpose:** Configuración de la aplicación
- **Características:**
  - Cambio de tema claro/oscuro
  - Navegación a gestión de transacciones recurrentes
- **Archivos clave:** `settings_screen.dart`

---

## 🎨 Core Components

### Constants
- `app_colors.dart` - Paleta de colores
- `app_sizes.dart` - Tamaños y espaciados consistentes

### Theme
- `app_theme.dart` - Tema Material con modo claro/oscuro
- `extensions.dart` - Extensiones de tema

### Widgets
Todos los widgets base reutilizables en toda la app:
- `AppButton` - Botón estándar
- `AppTextField` - Input de texto
- `AppToast` - Notificaciones toast
- `AppShell` - Navegación principal
- `BankLogo` - Visualización de logos de bancos
- `LoadingIndicator` - Indicador de carga

### Network
- `supabase_client.dart` - Cliente de Supabase
- `belvo_client.dart` - Cliente para API de Belvo (datos bancarios)

---

## 🔄 Última Actualización

**Cambios recientes:**
- Integración con Belvo API para logos de bancos
- Sistema de advertencias para transacciones recurrentes
- Rediseño de categorías con grid de 2 columnas
- Migración a Material Icons en dashboard y transacciones
- Mejoras en theme switcher y toast notifications
- Pantalla dedicada de transacciones recurrentes

---

## 📝 Notas

- Usa **Riverpod** para state management
- **Supabase** como backend
- **Belvo API** para información bancaria
- **Material Design** con iconografía de Material Icons
- Soporte para **tema claro/oscuro**
- **go_router** para navegación
