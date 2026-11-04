import 'package:flutter/services.dart';

class DeviceActionBridge {
  static const _channel = MethodChannel('ami/device_actions');

  Future<bool> launchApp(String appName) =>
      _invoke('launchApp', {'appName': appName});

  Future<bool> openSettingsPage(String page) =>
      _invoke('openSettingsPage', {'page': page});

  Future<bool> scheduleReminder({
    required String title,
    required DateTime scheduledAt,
  }) => _invoke('scheduleReminder', {
    'id': scheduledAt.microsecondsSinceEpoch.toString(),
    'title': title,
    'triggerAtMillis': scheduledAt.millisecondsSinceEpoch,
  });

  Future<bool> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
