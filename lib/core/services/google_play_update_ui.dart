import 'dart:io';

import 'package:flutter/services.dart';

class GooglePlayUpdateUi {
  static const MethodChannel _channel = MethodChannel(
    'ru.merrcurys.my_mpt/google_play_update',
  );

  static bool _started = false;

  static Future<bool> checkAndRunDeferredUpdate() async {
    if (!Platform.isAndroid) return false;
    if (_started) return false;
    _started = true;

    try {
      return await _channel.invokeMethod<bool>('checkAndRunDeferredUpdate') ??
          false;
    } catch (_) {
      return false;
    }
  }
}
