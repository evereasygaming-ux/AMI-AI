import 'package:flutter/services.dart';

class AccessibilityBridge {
  static const _channel = MethodChannel('ami/accessibility');

  Future<bool> isEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> isConnected() async {
    try {
      return await _channel.invokeMethod<bool>('isConnected') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> openSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getScreenNodes() async {
    try {
      final nodes = await _channel.invokeListMethod<dynamic>('getScreenNodes');
      return (nodes ?? const [])
          .whereType<Map>()
          .map((node) => node.map((key, value) => MapEntry('$key', value)))
          .toList();
    } on PlatformException {
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  Future<bool> tapAt(double x, double y) async {
    try {
      return await _channel.invokeMethod<bool>(
            'tapAt',
            {'x': x, 'y': y},
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> typeText(String text) async {
    try {
      return await _channel.invokeMethod<bool>(
            'typeText',
            {'text': text},
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
