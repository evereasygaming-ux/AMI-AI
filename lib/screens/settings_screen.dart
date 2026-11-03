import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ami_controller.dart';
import '../app_theme.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final AmiController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _models = [
    'gemini-3.5-flash-lite',
    'gemini-3.6-flash',
    'gemini-3.1-pro',
  ];

  static const _locales = {
    'auto': 'Auto (device language)',
    'en-IN': 'English (India)',
    'en-US': 'English (US)',
    'bn-IN': 'বাংলা (India)',
    'hi-IN': 'हिन्दी (India)',
  };

  late final TextEditingController _keyController;
  late final TextEditingController _groqKeyController;
  late final TextEditingController _cloudflareAccountController;
  late final TextEditingController _cloudflareTokenController;
  late final TextEditingController _modelController;
  late final TextEditingController _groqModelController;
  late final TextEditingController _cloudflareModelController;
  late String _provider;
  late String _voiceLocale;
  late bool _autoSpeak;
  late bool _autoScreen;
  late bool _floatingRobot;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.settings;
    _keyController = TextEditingController(text: settings.apiKey);
    _groqKeyController = TextEditingController(text: settings.groqApiKey);
    _cloudflareAccountController = TextEditingController(
      text: settings.cloudflareAccountId,
    );
    _cloudflareTokenController = TextEditingController(
      text: settings.cloudflareApiToken,
    );
    _modelController = TextEditingController(text: settings.model);
    _groqModelController = TextEditingController(text: settings.groqModel);
    _cloudflareModelController = TextEditingController(
      text: settings.cloudflareModel,
    );
    _provider = settings.provider;
    _voiceLocale = settings.voiceLocale;
    _autoSpeak = settings.autoSpeak;
    _autoScreen = settings.autoScreen;
    _floatingRobot = settings.floatingRobot;
  }

  @override
  void dispose() {
    _keyController.dispose();
    _groqKeyController.dispose();
    _cloudflareAccountController.dispose();
    _cloudflareTokenController.dispose();
    _modelController.dispose();
    _groqModelController.dispose();
    _cloudflareModelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final next = AmiSettings(
      apiKey: _keyController.text.trim(),
      model: _modelController.text.trim().isEmpty
          ? 'gemini-3.6-flash'
          : _modelController.text.trim(),
      provider: _provider,
      groqApiKey: _groqKeyController.text.trim(),
      groqModel: _groqModelController.text.trim().isEmpty
          ? 'qwen/qwen3.8-27b'
          : _groqModelController.text.trim(),
      cloudflareAccountId: _cloudflareAccountController.text.trim(),
      cloudflareApiToken: _cloudflareTokenController.text.trim(),
      cloudflareModel: _cloudflareModelController.text.trim().isEmpty
          ? '@cf/google/gemma-4-26b-a4b-it'
          : _cloudflareModelController.text.trim(),
      voiceLocale: _voiceLocale,
      autoSpeak: _autoSpeak,
      autoScreen: _autoScreen,
      floatingRobot: _floatingRobot,
      accessibilityConsent: widget.controller.settings.accessibilityConsent,
      screenActionConsent: widget.controller.settings.screenActionConsent,
      screenNodeStreamConsent:
          widget.controller.settings.screenNodeStreamConsent,
    );
    await widget.controller.saveSettings(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          next.hasApiKey
              ? 'Saved. AMI is ready — tap the orb and talk.'
              : 'Saved. Add the ${_provider == 'groq'
                    ? 'Groq API key'
                    : _provider == 'cloudflare'
                    ? 'Cloudflare Account ID and API token'
                    : 'Gemini API key'} to start chatting.',
        ),
      ),
    );
  }

  Future<void> _pasteKey() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() => _keyController.text = text);
  }

  Future<void> _toggleFloatingRobot(bool value) async {
    setState(() => _floatingRobot = value);
    final ok = await widget.controller.setFloatingRobot(value);
    if (!mounted) return;
    setState(() => _floatingRobot = widget.controller.settings.floatingRobot);
    if (!ok && value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.notice ?? 'Overlay permission is needed.',
          ),
        ),
      );
    }
  }

  Future<void> _openAccessibilitySettings() async {
    if (!widget.controller.settings.accessibilityConsent) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Allow screen interaction?'),
          content: const SingleChildScrollView(
            child: Text(
              'AMI can read visible screen text, control labels, and element positions. '
              'The screen tree stays on your phone. When screen sharing is active, its screenshot may be sent to the selected AI provider with your request. '
              'For an action request, AMI shows one tap or exact text entry for your approval before it runs. Password fields reject text entry. '
              'You can turn this access off any time in Android Accessibility settings.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Agree and continue'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      await widget.controller.saveSettings(
        widget.controller.settings.copyWith(accessibilityConsent: true),
      );
    }

    final opened = await widget.controller.openAccessibilitySettings();
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Android Accessibility settings.'),
        ),
      );
    }
  }

  Future<void> _setScreenNodeStreamConsent(bool enabled) async {
    if (enabled) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Stream visible screen text to AMI?'),
          content: const Text(
            'While enabled, AMI reads the active screen UI tree and updates its local state up to twice per second. The tree stays on this phone and is not sent to Gemini, Groq, or Cloudflare. Password field values are redacted. You can turn this off any time here.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Allow local stream'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    await widget.controller.setScreenNodeStreamConsent(enabled);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Wake AMI up and tune how she talks.',
          style: TextStyle(fontSize: 12.5, color: AmiColors.muted),
        ),
        const SizedBox(height: 22),
        _label('AI PROVIDER'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _provider,
          decoration: const InputDecoration(isDense: true),
          items: const [
            DropdownMenuItem(value: 'gemini', child: Text('Gemini (default)')),
            DropdownMenuItem(value: 'groq', child: Text('Groq')),
            DropdownMenuItem(
              value: 'cloudflare',
              child: Text('Cloudflare Workers AI'),
            ),
          ],
          onChanged: (value) => setState(() => _provider = value ?? 'gemini'),
        ),
        const SizedBox(height: 18),
        _label('API KEYS'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: glassPanel(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.key_rounded, size: 17, color: AmiColors.violet),
                  SizedBox(width: 8),
                  Text(
                    'API key',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Spacer(),
                  Text(
                    'stored on device',
                    style: TextStyle(fontSize: 9.5, color: AmiColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Gemini API key', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _keyController,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontSize: 13, letterSpacing: .3),
                decoration: InputDecoration(
                  hintText: 'AIza… your Gemini API key',
                  isDense: true,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _pasteKey,
                        icon: const Icon(Icons.content_paste_rounded, size: 17),
                        color: AmiColors.muted,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Paste',
                      ),
                      IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 17,
                        ),
                        color: AmiColors.muted,
                        visualDensity: VisualDensity.compact,
                        tooltip: _obscure ? 'Show' : 'Hide',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Create a free key at aistudio.google.com/apikey. Your key stays on this phone and is sent only to Google Gemini.',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AmiColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: glassPanel(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Groq API key', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: _groqKeyController,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  hintText: 'gsk_… your Groq API key',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Create a key at console.groq.com/keys. It stays on this phone and is sent only to Groq when Groq is selected.',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AmiColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: glassPanel(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cloudflare Account ID',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _cloudflareAccountController,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  hintText: 'Account ID',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 11),
              const Text(
                'Workers AI API token',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _cloudflareTokenController,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  hintText: 'Cloudflare API token',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Create a Workers AI API token in the Cloudflare dashboard. It stays on this phone and is sent to Cloudflare only when selected.',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AmiColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _label(
          _provider == 'groq'
              ? 'GROQ MODEL'
              : _provider == 'cloudflare'
              ? 'CLOUDFLARE MODEL'
              : 'GEMINI MODEL',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: glassPanel(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _provider == 'groq'
                    ? _groqModelController
                    : _provider == 'cloudflare'
                    ? _cloudflareModelController
                    : _modelController,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: _provider == 'groq'
                      ? 'qwen/qwen3.8-27b'
                      : _provider == 'cloudflare'
                      ? '@cf/google/gemma-4-26b-a4b-it'
                      : 'gemini-3.6-flash',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final model
                      in (_provider == 'groq'
                          ? const ['qwen/qwen3.8-27b']
                          : _provider == 'cloudflare'
                          ? const ['@cf/google/gemma-4-26b-a4b-it']
                          : _models))
                    GestureDetector(
                      onTap: () => setState(() {
                        (_provider == 'groq'
                                    ? _groqModelController
                                    : _provider == 'cloudflare'
                                    ? _cloudflareModelController
                                    : _modelController)
                                .text =
                            model;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (_provider == 'groq'
                                      ? _groqModelController.text
                                      : _provider == 'cloudflare'
                                      ? _cloudflareModelController.text
                                      : _modelController.text) ==
                                  model
                              ? AmiColors.cyan.withValues(alpha: .14)
                              : AmiColors.panelSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                (_provider == 'groq'
                                        ? _groqModelController.text
                                        : _provider == 'cloudflare'
                                        ? _cloudflareModelController.text
                                        : _modelController.text) ==
                                    model
                                ? AmiColors.cyan.withValues(alpha: .4)
                                : Colors.white.withValues(alpha: .06),
                          ),
                        ),
                        child: Text(
                          model,
                          style: TextStyle(
                            fontSize: 10.5,
                            color:
                                (_provider == 'groq'
                                        ? _groqModelController.text
                                        : _provider == 'cloudflare'
                                        ? _cloudflareModelController.text
                                        : _modelController.text) ==
                                    model
                                ? AmiColors.cyan
                                : AmiColors.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              const Text(
                'gemini-3.6-flash is the best balance of speed and screen understanding.',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AmiColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _label('VOICE'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: glassPanel(radius: 20),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Language',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _voiceLocale,
                    dropdownColor: AmiColors.panelSoft,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(fontSize: 12, color: AmiColors.text),
                    borderRadius: BorderRadius.circular(14),
                    items: [
                      for (final entry in _locales.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _voiceLocale = value);
                    },
                  ),
                ],
              ),
              const Divider(height: 22),
              _SwitchRow(
                title: 'Speak replies aloud',
                subtitle: 'AMI reads her answers with the voice orb.',
                value: _autoSpeak,
                onChanged: (value) => setState(() => _autoSpeak = value),
              ),
              const Divider(height: 22),
              _SwitchRow(
                title: 'Attach screen automatically',
                subtitle: 'When screen context is on, every question includes a screenshot.',
                value: _autoScreen,
                onChanged: (value) => setState(() => _autoScreen = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _label('FLOATING ROBOT'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: glassPanel(radius: 20),
          child: Column(
            children: [
              _SwitchRow(
                title: 'Floating robot',
                subtitle: 'A tiny 3D robot floats over other apps. Tap it to read your screen aloud.',
                value: _floatingRobot,
                onChanged: _toggleFloatingRobot,
              ),
              const Divider(height: 22),
              const _PrivacyLine(
                icon: Icons.layers_outlined,
                text: 'Needs the "Display over other apps" permission. Screen reading works while screen context is on.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _label('ACCESSIBILITY'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: glassPanel(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.accessibility_new_rounded,
                    size: 18,
                    color: AmiColors.cyan,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Screen interaction',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    !widget.controller.settings.accessibilityConsent
                        ? 'CONSENT NEEDED'
                        : widget.controller.accessibilityConnected
                        ? 'ACTIVE'
                        : widget.controller.accessibilityEnabled
                        ? 'ENABLED'
                        : 'OFF',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AmiColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              const Text(
                'Optional Android access for reading visible controls. AI-proposed taps or text entry require your approval each time. '
                'AMI asks for your consent before opening system settings.',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AmiColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Allow AI-proposed screen actions',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Every tap or exact text entry is shown here and needs your approval. Screen images go to the selected provider; the accessibility node tree stays on this phone. Password fields reject text entry.',
                  style: TextStyle(fontSize: 10.5, color: AmiColors.muted),
                ),
                value: widget.controller.settings.screenActionConsent,
                onChanged: widget.controller.setScreenActionConsent,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Stream screen UI tree to AMI',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Local Dart state only; password values are redacted. Updates at most every 500 ms.',
                  style: TextStyle(fontSize: 10.5, color: AmiColors.muted),
                ),
                value: widget.controller.settings.screenNodeStreamConsent,
                onChanged: _setScreenNodeStreamConsent,
              ),
              if (widget.controller.settings.screenNodeStreamConsent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Live UI nodes in AMI: ${widget.controller.screenNodes.length}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AmiColors.cyan,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openAccessibilitySettings,
                  icon: const Icon(Icons.settings_outlined, size: 17),
                  label: const Text('Open Android Accessibility settings'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _label('PRIVACY'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: glassPanel(radius: 20),
          child: const Column(
            children: [
              _PrivacyLine(
                icon: Icons.phone_android_rounded,
                text: 'Screen frames are captured on your phone. Only a frame attached to a question is sent to the selected provider.',
              ),
              SizedBox(height: 11),
              _PrivacyLine(
                icon: Icons.lock_outline_rounded,
                text: 'API keys are saved locally. Only the selected provider’s key is sent with its requests.',
              ),
              SizedBox(height: 11),
              _PrivacyLine(
                icon: Icons.memory_rounded,
                text: 'Chat history lives in memory. Closing AMI clears the conversation.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded, size: 19),
            label: const Text(
              'Save settings',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AmiColors.cyan.withValues(alpha: .18),
              foregroundColor: AmiColors.cyan,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: widget.controller.clearChat,
          icon: const Icon(Icons.delete_sweep_outlined, size: 17),
          label: const Text('Clear conversation'),
          style: TextButton.styleFrom(foregroundColor: AmiColors.muted),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'AMI v1.0  •  Gemini + Groq + Cloudflare',
            style: TextStyle(fontSize: 10, color: AmiColors.muted),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      letterSpacing: 2,
      fontWeight: FontWeight.w700,
      color: AmiColors.muted,
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AmiColors.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AmiColors.cyan,
          activeTrackColor: AmiColors.cyan.withValues(alpha: .25),
        ),
      ],
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AmiColors.cyan.withValues(alpha: .8)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: AmiColors.muted,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
