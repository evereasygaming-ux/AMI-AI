import 'dart:convert';

import 'package:flutter/services.dart';

class AccessibilityManager {
  static const MethodChannel _controlChannel = MethodChannel(
    'ami/accessibility',
  );
  static const EventChannel _streamChannel = EventChannel(
    'ami/accessibility_stream',
  );

  Stream<List<Map<String, dynamic>>> get screenNodeTrees =>
      _streamChannel.receiveBroadcastStream().map((event) {
        if (event is! String) {
          throw const FormatException(
            'Accessibility stream payload must be JSON text.',
          );
        }
        final decoded = jsonDecode(event);
        if (decoded is! List) {
          throw const FormatException(
            'Accessibility stream JSON must be a list.',
          );
        }
        return decoded
            .whereType<Map>()
            .map((node) => node.map((key, value) => MapEntry('$key', value)))
            .toList(growable: false);
      });

  Future<bool> isEnabled() async {
    try {
      return await _controlChannel.invokeMethod<bool>('isEnabled') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> isConnected() async {
    try {
      return await _controlChannel.invokeMethod<bool>('isConnected') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> openSettings() async {
    try {
      return await _controlChannel.invokeMethod<bool>('openSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getScreenNodes() async {
    try {
      final nodes = await _controlChannel.invokeListMethod<dynamic>(
        'getScreenNodes',
      );
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
      return await _controlChannel.invokeMethod<bool>('tapAt', {
            'x': x,
            'y': y,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> typeText(String text) async {
    try {
      return await _controlChannel.invokeMethod<bool>('typeText', {
            'text': text,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
