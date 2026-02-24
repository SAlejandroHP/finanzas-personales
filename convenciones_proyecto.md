# CONVENCIONES_PROYECTO.md  
**Última actualización:** 16 de febrero de 2026  
**Autor:** Alejandro (con apoyo de Grok)  
**Objetivo:** Documentar las convenciones de organización, estructura, nomenclatura y buenas prácticas del proyecto Flutter para mantener consistencia, legibilidad y escalabilidad.

## 1. Estructura de Carpetas (Actual)
finanzas/
├── lib/
│   ├── core/                           # Todo lo global, reutilizable y de bajo nivel
│   │   ├── constants/                  # Constantes estáticas (colores, tamaños, strings)
│   │   ├── theme/                      # Temas claro/oscuro + extensiones
│   │   ├── network/                    # Clientes API (Supabase, Belvo, etc.)
│   │   ├── services/                   # Servicios centrales (FinanceService, etc.)
│   │   ├── utils/                      # Utilidades puras (toast_utils, formatters, validators)
│   │   ├── widgets/                    # Widgets base reutilizables en toda la app
│   │   └── navigation/                 # Router (go_router), rutas nombradas
│   │
│   ├── features/                       # Módulos funcionales (cada uno con su propia lógica)
│   │   ├── auth/                       # Autenticación y onboarding
│   │   ├── dashboard/                  # Pantalla principal / resumen
│   │   ├── accounts/                   # Gestión de cuentas
│   │   ├── categories/                 # Categorías de ingresos/gastos
│   │   ├── transactions/               # Registro y listado de transacciones + recurrentes
│   │   ├── debts/                      # Deudas externas y tarjetas de crédito
│   │   └── settings/                   # Configuración general + recurrentes
│   │
│   ├── shared/                         # Elementos compartidos entre features
│   │   ├── models/                     # Modelos base reutilizables
│   │   └── providers/                  # Providers globales (si no pertenecen a un feature)
│   │
│   └── main.dart                       # Entry point + inicialización
│
├── assets/                             # Recursos estáticos
├── test/                               # Tests
└── docs/                               # Documentación (LOGICA_APP.md, CONVENCIONES_PROYECTO.md)


### Regla de ubicación
- Si es **global y reutilizable** → `core/`  
- Si es **específico de una funcionalidad** → `features/nombre_feature/`  
- Si es **compartido entre varios features** → `shared/`

## 2. Centralización (Reglas de Organización)

### Diseño y Estilos (Design System)
El archivo **`lib/core/constants/app_colors.dart`** es la **FUENTE ÚNICA DE VERDAD** para el diseño visual de la aplicación.
- Actúa como el "main.css" del proyecto.
- **Contenido Obligatorio en `app_colors.dart`**:
  - Paleta de colores (Primary, Accent, Backgrounds).
  - Tamaños de tipografía (`titleLarge`, `bodyMedium`, etc.).
  - Radios de borde (`radiusSmall`, `radiusMedium`).
  - Espaciados y propiedades de Cards (`cardPadding`, `cardElevation`).
- **Regla Estricta**:
  - **PROHIBIDO** hardcodear valores numéricos de tamaño (font-size: 18) o colores (Colors.red) en los Widgets o Screens.
  - TODOS los widgets visuales deben consumir las propiedades estáticas de `AppColors`.
  - Ejemplo: Usar `style: TextStyle(fontSize: AppColors.titleMedium)` en lugar de `fontSize: 20`.

### Iconografía y Componentes Visuales (Homologación)
Para mantener un estilo "Premium" y consistente, todos los iconos de categorías en listas, gráficas y transacciones deben seguir este estándar visual:
- **Contenedor**: Cuadrado suave (Squircle) con `BorderRadius.circular(10)`.
- **Fondo**: Color de la categoría con opacidad del 15-20% (`color.withOpacity(0.15)`).
- **Icono**: Color de la categoría sólido (100% opacidad).
- **Dimensiones**: Contenedor de `32x32dp` con icono de `16dp` para listas estándar.
- **Ubicación**: Se deben usar siempre los mapeos de `_getIconFromString` para asegurar que el icono guardado en BD coincida con el mostrado.

- **State Management**: Riverpod 2.x en todos lados (Provider, StateProvider, FutureProvider, StreamProvider).
- **Actualización de datos**: TODA actualización de saldos, deudas, ingresos/gastos, totales y reportes debe pasar por **FinanceService** (lib/core/services/finance_service.dart).
- **FinanceService**: 
  - NO escribe en la BD
  - Solo invalida providers relevantes (accountsListProvider, totalBalanceProvider, etc.)
  - Se llama después de **cualquier** operación que modifique datos financieros
- **Repositorios**: solo hacen operaciones CRUD en Supabase (insert, update, delete, select).
- **Providers**: hacen cálculos reactivos (sumas, filtros) y escuchan realtime.

## 3. Nomenclatura de Archivos y Carpetas

- Carpetas: **snake_case** (accounts, transactions, debts)
- Archivos Dart: **snake_case.dart** (account_model.dart, transaction_form_sheet.dart)
- Clases: **PascalCase** (AccountModel, TransactionFormSheet)
- Providers: **camelCaseProvider** (accountsListProvider, totalBalanceProvider)
- Widgets reutilizables: **AppXxxx** (AppButton, AppTextField, AppToast)
- Funciones de utilidad: **camelCase** (showAppToast, formatCurrency)
- Constantes: **UPPER_SNAKE_CASE** (solo en constants/) o **camelCase** con prefijo k (kPrimaryColor)
- Rutas go_router: **snake_case** (/accounts, /transactions/new)

## 4. Nomenclatura de Componentes y Widgets

- Widgets base/reutilizables (core/widgets/): **AppXxxx** (AppButton, AppTextField, AppToast, AppScaffold)
- Widgets específicos de feature (features/transactions/presentation/widgets/): **XxxxTile**, **XxxxCard**, **XxxxFormSheet** (TransactionTile, CategoryCard, TransactionFormSheet)
- Pantallas completas: **XxxxScreen** (DashboardScreen, AccountsListScreen)
- Providers: **xxxxProvider** (accountsListProvider, recentTransactionsProvider)
- Modelos: **XxxxModel** (TransactionModel, AccountModel)
- Servicios: **XxxxService** (FinanceService)
- Utilidades: **toast_utils.dart**, **date_utils.dart**

## 5. Convenciones de Código y Organización de Documentos

- **Comentarios**: siempre en español, explicativos (// Corrección: ... , // Lógica financiera: ...)
- **Imports**: ordenados (primero Dart, luego paquetes, luego internos con ../../)
- **Documentación**: 
  - LOGICA_APP.md → reglas de negocio y flujo financiero
  - CONVENCIONES_PROYECTO.md → estructura, nomenclatura, buenas prácticas
  - Actualizar siempre después de cada fase importante
- **Commit messages**: en español, descriptivos (ej. "feat: implementa FinanceService centralizado")
- **Pantallas y bottom sheets**: siempre con SafeArea + Padding(horizontal: 16, vertical: 8-12)
- **Bottom sheets**: homogéneos (altura 0.85, cierre swipe, barrierColor 0.5, header con cerrar)

## 6. Próximas Fases Pendientes (según diagnóstico)

1. Centralización total con FinanceService (en progreso)
2. Consolidación de tarjetas de crédito y deudas externas
3. Transacciones recurrentes con recordatorios
4. Pulir dashboard (sección pendientes, visuales)
5. Integración con Belvo (vincular cuentas reales)
