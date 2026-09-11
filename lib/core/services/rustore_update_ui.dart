import 'dart:async';
import 'dart:io';

import 'package:flutter_rustore_update/flutter_rustore_update.dart';

class RuStoreUpdateUi {
  static bool _started = false;
  static StreamSubscription<RequestResponse>? _updateSubscription;

  /// Полный in-app update flow с UI RuStore:
  /// - info()
  /// - если доступно: download() (UI RuStore)
  /// - слушаем stateStream; когда DOWNLOADED -> completeUpdateFlexible() (UI RuStore)
  static Future<void> checkAndRunDeferredUpdate() async {
    if (!Platform.isAndroid) return;
    if (_started) return;
    _started = true;

    try {
      final info = await RustoreUpdateClient.info();

      final updateAvailable =
          info.updateAvailability == UPDATE_AVAILABILITY_AVAILABLE;

      if (!updateAvailable) return;

      _ensureListener();

      // Если уже скачано (например, пользователь начал раньше) — сразу предлагаем установку
      if (info.installStatus == INSTALL_STATUS_DOWNLOADED) {
        await RustoreUpdateClient.completeUpdateFlexible();
        return;
      }

      // Отложенное обновление: скачивание с UI от RuStore
      await RustoreUpdateClient.download();
    } catch (_) {
      // По рекомендациям RuStore ошибки пользователю лучше не показывать
    }
  }

  static void _ensureListener() {
    if (_updateSubscription != null) return;

    _updateSubscription = RustoreUpdateClient.stateStream.listen((value) async {
      try {
        if (value.installStatus == INSTALL_STATUS_DOWNLOADED) {
          // Установка обновления с UI RuStore
          await RustoreUpdateClient.completeUpdateFlexible();
        }
      } catch (_) {}
    }, onError: (_) {});
  }
}
