import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../core/wellness_service.dart';

/// Guided 4-4-6 breathing, 4 rounds (about 1 minute).
class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});
  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> with SingleTickerProviderStateMixin {
  static const _phases = [('Breathe in', 4), ('Hold', 4), ('Breathe out', 6)];
  static const _rounds = 4;

  late final AnimationController _c = AnimationController(vsync: this);
  int _round = 0;
  int _phase = 0;
  int _left = 0;
  bool _running = false;
  bool _finished = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      _finished = false;
      _round = 0;
      _phase = 0;
    });
    _runPhase();
  }

  void _runPhase() {
    final (_, secs) = _phases[_phase];
    _left = secs;
    HapticFeedback.lightImpact();
    if (_phase == 0) {
      _c.animateTo(1, duration: Duration(seconds: secs), curve: Curves.easeInOut);
    } else if (_phase == 2) {
      _c.animateTo(0, duration: Duration(seconds: secs), curve: Curves.easeInOut);
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        _next();
      }
    });
    setState(() {});
  }

  Future<void> _next() async {
    if (_phase < _phases.length - 1) {
      _phase++;
      _runPhase();
      return;
    }
    _round++;
    if (_round >= _rounds) {
      setState(() {
        _running = false;
        _finished = true;
      });
      try {
        final (gained, _) = await WellnessService.breathingDone();
        if (mounted && gained > 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Well done. +$gained XP')));
        }
      } catch (_) {}
      return;
    }
    _phase = 0;
    _runPhase();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final label = _finished ? 'Well done 💗' : (_running ? _phases[_phase].$1 : 'Ready when you are');
    return Scaffold(
      backgroundColor: const Color(0xFF2F2A4F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Breathe', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Column(children: [
          const Spacer(),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final size = 140 + 140 * _c.value;
              return Container(
                width: 300,
                height: 300,
                alignment: Alignment.center,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(colors: [Color(0xFFB9AEF5), AppColors.secondary]),
                    boxShadow: [
                      BoxShadow(color: AppColors.secondary.withValues(alpha: 0.5), blurRadius: 40 + 40 * _c.value),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _running ? '$_left' : '🌬️',
                    style: const TextStyle(fontSize: 44, color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(label, style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            _running ? 'Round ${_round + 1} of $_rounds' : 'In for 4, hold for 4, out for 6. About 1 minute.',
            style: t.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.ink),
              onPressed: _running ? null : _start,
              child: Text(_finished ? 'Go again' : 'Start'),
            ),
          ),
        ]),
      ),
    );
  }
}
