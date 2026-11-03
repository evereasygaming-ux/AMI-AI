import 'package:flutter/material.dart';

import 'ami_controller.dart';
import 'app_theme.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AmiApp());
}

class AmiApp extends StatefulWidget {
  const AmiApp({super.key});

  @override
  State<AmiApp> createState() => _AmiAppState();
}

class _AmiAppState extends State<AmiApp> with WidgetsBindingObserver {
  late final AmiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AmiController();
    _controller.init();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.refreshScreenState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AMI AI',
      debugShowCheckedModeBanner: false,
      theme: buildAmiTheme(),
      home: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.booting) {
            return const _SplashScreen();
          }
          return AmiShell(controller: _controller);
        },
      ),
    );
  }
}

class AmiShell extends StatefulWidget {
  const AmiShell({super.key, required this.controller});

  final AmiController controller;

  @override
  State<AmiShell> createState() => _AmiShellState();
}

class _AmiShellState extends State<AmiShell> {
  int _index = 0;

  void _openTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF070B16),
              AmiColors.bg,
              Color(0xFF0A0716),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: [
              HomeScreen(
                controller: widget.controller,
                onOpenSettings: () => _openTab(2),
                onOpenChat: () => _openTab(1),
              ),
              ChatScreen(controller: widget.controller),
              SettingsScreen(controller: widget.controller),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _AmiNavBar(
        index: _index,
        onChanged: _openTab,
      ),
    );
  }
}

class _AmiNavBar extends StatelessWidget {
  const _AmiNavBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.blur_on_rounded, 'Orb'),
    (Icons.chat_bubble_outline_rounded, 'Chat'),
    (Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xF20B1120),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: i == index
                        ? LinearGradient(
                            colors: [
                              AmiColors.cyan.withValues(alpha: .18),
                              AmiColors.violet.withValues(alpha: .2),
                            ],
                          )
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _items[i].$1,
                        size: 21,
                        color: i == index
                            ? AmiColors.cyan
                            : AmiColors.muted.withValues(alpha: .8),
                      ),
                      if (i == index) ...[
                        const SizedBox(width: 8),
                        Text(
                          _items[i].$2,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AmiColors.text,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF12203C), AmiColors.bg],
            radius: .9,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AmiColors.cyan, AmiColors.violet],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AmiColors.cyan.withValues(alpha: .4),
                      blurRadius: 46,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'AMI',
                style: TextStyle(
                  fontSize: 30,
                  letterSpacing: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'AI MULTIMODAL INTELLIGENCE',
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 3,
                  color: AmiColors.muted,
                ),
              ),
              const SizedBox(height: 34),
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AmiColors.cyan.withValues(alpha: .8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
