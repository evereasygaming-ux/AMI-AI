import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenCaptureException implements Exception {
  ScreenCaptureException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ScreenCaptureService {
  ScreenCaptureService() {
    _channel.setMethodCallHandler(_handleNativeCall);
    unawaitedRefresh();
  }

  static const _channel = MethodChannel('ami/screen');

  final ValueNotifier<bool> isSharing = ValueNotifier<bool>(false);
  void Function()? onDelayedCaptureReady;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'screenState':
        isSharing.value = call.arguments == true;
        break;
      case 'captureReady':
        onDelayedCaptureReady?.call();
        break;
    }
    return null;
  }

  void unawaitedRefresh() {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final active = await _channel.invokeMethod<bool>('isScreenCapturing');
      isSharing.value = active ?? false;
    } catch (_) {
      isSharing.value = false;
    }
  }

  Future<bool> start() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestScreenCapture') ?? false;
      if (!granted) {
        isSharing.value = false;
        return false;
      }
      for (var attempt = 0; attempt < 8; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 180));
        final active =
            await _channel.invokeMethod<bool>('isScreenCapturing') ?? false;
        if (active) {
          isSharing.value = true;
          return true;
        }
      }
      isSharing.value = false;
      return false;
    } on PlatformException catch (error) {
      throw ScreenCaptureException(
        error.message ?? 'Screen sharing could not be started.',
      );
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopScreenCapture');
    } on PlatformException {
      // The service is already gone; nothing else to do.
    }
    isSharing.value = false;
  }

  Future<Uint8List?> capture() async {
    try {
      return await _channel.invokeMethod<Uint8List>('captureScreen');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> captureAfter(Duration delay) async {
    try {
      return await _channel.invokeMethod<bool>(
            'captureScreenAfter',
            {'delayMs': delay.inMilliseconds},
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<Uint8List?> takePendingCapture() async {
    try {
      return await _channel.invokeMethod<Uint8List>('takePendingCapture');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  void dispose() {
    onDelayedCaptureReady = null;
    _channel.setMethodCallHandler(null);
  }
}
