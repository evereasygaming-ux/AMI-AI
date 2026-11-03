import 'package:ami_ai/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings copyWith keeps and overrides values', () {
    const base = AmiSettings(apiKey: 'test-key');
    final updated = base.copyWith(model: 'gemini-2.5-flash');

    expect(updated.apiKey, 'test-key');
    expect(updated.model, 'gemini-2.5-flash');
    expect(updated.hasApiKey, isTrue);
  });
}
