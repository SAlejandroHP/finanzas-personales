import 'package:flutter/material.dart';

/// DOCUMENTACIÓN DEL SISTEMA DE DISEÑO (Design System)
/// ---------------------------------------------------------------------------
/// Este archivo actúa como la fuente central de verdad para todos los estilos de la aplicación.
/// Funciona similar a un archivo .css global o main.css.
///
/// REGLAS DE USO:
/// 1. Ningún widget o pantalla debe tener valores hardcodeados para colores, tamaños de fuente,
///    bordes o espaciados.
/// 2. Todos los elementos visuales DEBEN importar y usar las constantes de esta clase [AppColors].
/// 3. Si se necesita un nuevo valor, se debe agregar aquí primero y documentar su uso.
///
/// LISTADO COMPLETO DE ELEMENTOS Y USOS (Sin excepción):
///
/// WIDGETS Y PANTALLAS (Implementación de Diseño):
/// - AppButton        -> Altura (buttonHeight), Radio (radiusSmall), Texto (bodyLarge).
/// - AppTextField     -> Padding (cardPadding), Radio (radiusMedium), Texto (bodyMedium).
/// - AppToast         -> Radio (radiusCircular), Iconos (iconXSmall), Texto (bodySmall).
/// - DashboardScreen  -> Margen (pagePadding), Gap (contentGap), Tarjetas (radiusLarge).
/// - AuthScreen       -> Títulos (titleLarge), Logo (iconLarge), Botonera (buttonHeight).
///
/// COLORES (Tematizados):
/// - AppColors.primary          -> Color de identidad (Teal). Usado globalmente para marca.
/// - AppColors.secondary        -> Color de soporte (Coral). Usado para acentos y estados.
/// - AppColors.tertiary         -> Color complementario (Gold). Usado para detalles y destaques.
///
/// COLORES DE FONDO Y TEXTO:
/// - AppColors.backgroundColor  -> Fondo base de todas las pantallas (Scaffold background).
/// - AppColors.surface          -> Fondo de Cards, Modal Bottom Sheets, Diálogos, Inputs.
/// - AppColors.textPrimary      -> Títulos, nombres de categorías, montos principales.
/// - AppColors.textSecondary    -> Descripciones, fechas, texto en botones sólidos (blanco), captions.
///
/// COLORES POR TEMA (Para configuración de Theme Data):
/// - Light: primaryLight, secondaryLight, tertiaryLight.
/// - Dark : primaryDark, secondaryDark, tertiaryDark.
///
/// TIPOGRAFÍA (Tamaños de fuente):
/// - AppColors.titleLarge (24)  -> Títulos en Dashboard, Títulos de pantallas de lista.
/// - AppColors.titleMedium (20) -> Subtítulos de sección (ej: "Transacciones Recientes").
/// - AppColors.titleSmall (18)  -> Títulos de Cards de cuenta, nombres de transacciones en lista.
/// - AppColors.bodyLarge (16)   -> Texto en campos de formulario (Input text), párrafos destacados.
/// - AppColors.bodyMedium (14)  -> Texto estándar, etiquetas de configuración, detalles de item.
/// - AppColors.bodySmall (12)   -> Fechas, notas pequeñas, texto de ayuda bajo inputs.
///
/// BORDES Y FORMAS (Border Radius):
/// - AppColors.radiusSmall (8)  -> Chips de categoría, botones pequeños, checkbox.
/// - AppColors.radiusMedium (12)-> TextFields, Cards estándar de transacciones.
/// - AppColors.radiusLarge (16) -> Tarjetas de cuenta (Bank Cards), Dashboards cards principales.
/// - AppColors.radiusXLarge (24)-> Modal Bottom Sheets (esquinas superiores).
/// - AppColors.radiusCircular (100) -> Avatares de usuario, Floating Action Buttons (FAB).
///
/// ESPACIADO Y LAYOUT:
/// - AppColors.cardPadding (16) -> Padding interno uniforme para todas las tarjetas.
/// - AppColors.pagePadding (16) -> Margen izquierdo/derecho obligatorio en cada Screen.
/// - AppColors.contentGap (12)  -> Separación vertical entre elementos dentro de una lista o columna.
/// - AppColors.cardElevation (2)-> Elevación/sombra uniforme para dar profundidad a las Cards.
/// ---------------------------------------------------------------------------

// Paleta base (Privada)
const Color _primaryTeal     = Color(0xFF0A7075);
const Color _accentCoral     = Color(0xFFFF8B6A);
const Color _gold            = Color(0xFFD4AF37);
const Color _backgroundLight = Color(0xFFF5F5F5);
const Color _textDark        = Color(0xFF333333);
const Color _textLight       = Color(0xFFFFFFFF);

/// Clase centralizada para estilos de la aplicación.
abstract class AppColors {
  // ===========================================================================
  // PALETA GLOBAL (Source of Truth)
  // ===========================================================================
  static const Color primary         = _primaryTeal;
  static const Color secondary       = _accentCoral;
  static const Color tertiary        = _gold;
  
  static const Color backgroundColor = _backgroundLight;
  static const Color textPrimary     = _textDark;
  static const Color textSecondary   = _textLight;
  static const Color surface         = Colors.white;

  // ===========================================================================
  // COLORES POR TEMA (Para ThemeMode / ColorScheme)
  // ===========================================================================
  
  // TEMA CLARO
  static const Color primaryLight   = _primaryTeal;
  static const Color secondaryLight = _accentCoral;
  static const Color tertiaryLight  = _gold;
  
  // TEMA OSCURO
  static const Color primaryDark    = Color(0xFF14B8A6); // Teal más brillante para contraste
  static const Color secondaryDark  = Color(0xFFFFA28A); // Coral más suave
  static const Color tertiaryDark   = Color(0xFFFDE047); // Oro más claro
  
  static const Color backgroundDark = Color(0xFF1A1A1A);
  static const Color surfaceDark    = Color(0xFF252525);
  
  // COLORES DE ESTADO Y TEXTO REUTILIZABLES
  static const Color error          = Color(0xFFE53935); // Rojo estándar
  static const Color success        = Color(0xFF43A047); // Verde estándar
  static const Color warning        = Color(0xFFFFB300); // Ámbar estándar
  static const Color info           = Color(0xFF1E88E5); // Azul estándar
  static const Color description    = Colors.grey;       // Texto de descripción (600)
  static const Color disabled       = Colors.grey;       // Elementos deshabilitados

  // ===========================================================================
  // SISTEMA DE TIPOGRAFÍA (Font Sizes)
  // ===========================================================================
  static const double titleLarge  = 24.0; // Títulos de pantallas principales
  static const double titleMedium = 20.0; // Subtítulos de sección
  static const double titleSmall  = 18.0; // Títulos de items / headers menores
  static const double bodyLarge   = 16.0; // Texto de cuerpo destacado / Inputs
  static const double bodyMedium  = 14.0; // Texto estándar / Párrafos
  static const double bodySmall   = 12.0; // Captions / Fechas / Ayuda

  // ===========================================================================
  // SISTEMA DE BORDES (Border Radius)
  // ===========================================================================
  static const double radiusSmall    = 8.0;   // Botones pequeños, chips
  static const double radiusMedium   = 12.0;  // Tarjetas, inputs
  static const double radiusLarge    = 16.0;  // Modals, tarjetas destacadas
  static const double radiusXLarge   = 24.0;  // Contenedores grandes
  static const double radiusCircular = 100.0; // Avatares, FABs

  // ===========================================================================
  // SISTEMA DE ESPACIADO Y CARDS (Layout)
  // ===========================================================================
  static const double cardPadding   = 16.0; // Padding interno estándar
  static const double pagePadding   = 16.0; // Margen lateral de pantallas
  static const double contentGap    = 12.0; // Espacio entre elementos verticales
  static const double gapSmall      = 4.0;  // Pequeños espacios entre texto e iconos
  static const double cardElevation = 2.0;  // Sombra estándar

  // ===========================================================================
  // SISTEMA DE ESPACIADO GENÉRICO (Tokens de tamaño)
  // ===========================================================================
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;
  static const double lg  = 24.0;
  static const double xl  = 32.0;
  static const double xxl = 48.0;

  // ===========================================================================
  // SISTEMA DE ICONOS Y BOTONES
  // ===========================================================================
  static const double iconXSmall   = 16.0;
  static const double iconSmall    = 20.0;
  static const double iconMedium   = 24.0;
  static const double iconLarge    = 32.0;
  
  static const double buttonHeight      = 44.0; // Altura estándar de botones
  static const double buttonHeightSmall = 36.0; // Botones compactos
  static const double inputHeight       = 48.0; // Altura estándar para campos de texto

  // ===========================================================================
  // DEGRADADOS Y OTROS
  // ===========================================================================
  static const LinearGradient tealGradient = LinearGradient(
    colors: [_primaryTeal, Color(0xFF0D9BA1)],
    begin : Alignment.centerLeft,
    end   : Alignment.centerRight,
  );
  
  static const List<Color> categoryColors = [
    Color(0xFF0A7075), Color(0xFFFF8B6A), Color(0xFFD4AF37),
    Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFF9C27B0),
    Color(0xFFFF5722), Color(0xFFE91E63), Color(0xFF00BCD4),
    Color(0xFFFF9800), Color(0xFF607D8B), Color(0xFF795548),
    Color(0xFF8BC34A), Color(0xFFFFC107), Color(0xFF3F51B5),
  ];
}

