import 'package:flutter/services.dart';

class OverlayService {
  OverlayService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'orbTap') {
        onOrbTap?.call();
      }
      return null;
    });
  }

  static const _channel = MethodChannel('ami/overlay');

  void Function()? onOrbTap;

  Future<bool> isPermissionGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isOverlayPermissionGranted') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestOverlayPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> start() async {
    try {
      return await _channel.invokeMethod<bool>('startOverlay') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopOverlay');
    } catch (_) {}
  }

  Future<bool> isRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isOverlayRunning') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> takePendingAction() async {
    try {
      return await _channel.invokeMethod<String>('takeOrbAction');
    } catch (_) {
      return null;
    }
  }
}
