import 'dart:io';

import 'package:my_mpt/core/services/google_play_update_ui.dart';
import 'package:my_mpt/core/services/rustore_update_ui.dart';

class AppUpdateUi {
  static bool _started = false;

  static Future<void> checkAndRunDeferredUpdate() async {
    if (!Platform.isAndroid) return;
    if (_started) return;
    _started = true;

    final googlePlayStarted =
        await GooglePlayUpdateUi.checkAndRunDeferredUpdate();
    if (googlePlayStarted) return;

    await RuStoreUpdateUi.checkAndRunDeferredUpdate();
  }
}
