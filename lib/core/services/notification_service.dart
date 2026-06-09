import 'dart:isolate';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'pending_notification_manager.dart';

/// Lista de paquetes de aplicaciones bancarias permitidas.
/// Esto asegura que solo procesamos notificaciones de bancos y descartamos el resto
/// para ahorrar recursos y proteger la privacidad del usuario.
const List<String> allowedBankPackages = [
  // Bancos Tradicionales
  'com.bbva.bbvacontigo',
  'com.banamex.mexico',
  'com.santander.mxbanking',
  'com.banorte.mob',
  'mx.com.hsbc.hsbcmovil',
  'com.scotiabank.mexico.scotiamovil',
  'com.inbursa.inbursamovil',
  'com.baz.bancoazteca',
  
  // Neobancos y Fintechs
  'com.nu.production',
  'com.banregio.hey', // Hey Banco
  'com.mercadopago.wallet',
  'mx.com.klar',
  'ai.powerup.stori',
  'ar.com.bancar.uala', // Ualá México usa la misma base
  'com.fondeadora.bank',
  'mx.albo.app',
  'com.spin.oxxo',
  'com.actinver.dinn',
  
  // SOFIPOs
  'com.finsus.finsus',
];

/// Callback de segundo plano para procesar notificaciones.
/// Debe ser de nivel superior (top-level) y usar el pragma vm:entry-point
/// para que no sea removido en la compilación de release.
@pragma('vm:entry-point')
void notificationCallback(NotificationEvent event) {
  // Filtro de Aplicaciones
  if (event.packageName == null || !allowedBankPackages.contains(event.packageName)) {
    // Descartamos silenciosamente cualquier notificación que no sea de los bancos permitidos
    return;
  }

  debugPrint("==================================================");
  debugPrint("Notificación Bancaria Interceptada (Background)");
  debugPrint("Paquete: ${event.packageName}");
  debugPrint("Título: ${event.title}");
  debugPrint("Texto: ${event.text}");
  debugPrint("==================================================");

  // Guardamos la notificación en SharedPreferences para que la UI la procese
  final rawNotif = RawPendingNotification(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    packageName: event.packageName!,
    title: event.title ?? 'Sin título',
    text: event.text ?? '',
    timestamp: DateTime.now(),
  );
  PendingNotificationManager.saveNotification(rawNotif);

  // Enviar el evento al hilo principal de la UI si la app está en memoria
  final SendPort? sendPort = IsolateNameServer.lookupPortByName("_listener_");
  if (sendPort != null) {
    sendPort.send(event);
  }
}

/// Servicio para inicializar y gestionar el listener de notificaciones.
class NotificationService {
  static const String _isolateName = "_listener_";
  static ReceivePort? _port;

  /// Inicializa el servicio, registra los puertos y el callback en segundo plano
  static Future<void> initialize() async {
    try {
      _port = ReceivePort();
      IsolateNameServer.removePortNameMapping(_isolateName);
      IsolateNameServer.registerPortWithName(_port!.sendPort, _isolateName);

      _port!.listen((message) {
        if (message is NotificationEvent) {
          _handleNotificationInUI(message);
        }
      });

      // Inicializa el plugin con el callback de segundo plano
      await NotificationsListener.initialize(callbackHandle: notificationCallback);
      
      // Inicia el servicio si ya se tienen los permisos
      final hasPermission = await NotificationsListener.hasPermission;
      if (hasPermission ?? false) {
        await NotificationsListener.startService();
        debugPrint("NotificationService iniciado correctamente.");
      } else {
        debugPrint("NotificationService: Permisos pendientes.");
      }
    } catch (e) {
      debugPrint('Error inicializando NotificationService: $e');
    }
  }

  static final StreamController<NotificationEvent> onNotification = StreamController.broadcast();

  /// Procesa la notificación cuando la app está abierta en la UI
  static void _handleNotificationInUI(NotificationEvent event) {
    debugPrint("UI recibió notificación bancaria: ${event.title} - ${event.text}");
    onNotification.add(event);
  }

  /// Limpia los recursos y puertos del servicio
  static void dispose() {
    _port?.close();
    IsolateNameServer.removePortNameMapping(_isolateName);
    onNotification.close();
  }
}
