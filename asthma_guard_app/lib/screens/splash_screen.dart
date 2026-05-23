// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    _init();
  }

  Future<void> _init() async {
    await ApiConfig.loadSavedIp();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final loggedIn = await AuthService.isLoggedIn();
    Navigator.pushReplacementNamed(context, loggedIn ? '/dashboard' : '/login');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050D1A),
      body: Stack(children: [
        // Background gradient — matches index.html body
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF050D1A), Color(0xFF050D1A), Color(0xFF060F1E)],
            ),
          ),
        ),
        // Radial glow top-left — matches body radial-gradient
        Positioned(
          top: -80, left: -80,
          child: Container(
            width: 500, height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF2850B4).withOpacity(0.22),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        // Radial glow bottom-right
        Positioned(
          bottom: -100, right: -60,
          child: Container(
            width: 400, height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF14788C).withOpacity(0.15),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        // Grid overlay — body::after
        Positioned.fill(child: CustomPaint(painter: _SplashGridPainter())),
        // Content
        Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Shield container — .logo-orb style from index.html header
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A1438), Color(0xFF2A1F4A)],
                    ),
                    border: Border.all(
                        color: const Color(0xFF5B8FFF).withOpacity(0.30),
                        width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF5B8FFF).withOpacity(0.15),
                          blurRadius: 30),
                    ],
                  ),
                  child: const Center(
                    child: Text('🛡️', style: TextStyle(fontSize: 52)),
                  ),
                ),
                const SizedBox(height: 28),
                // Gradient title — matches brand h1 in index.html
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFa0c8ff),
                      Color(0xFF5B8FFF),
                      Color(0xFFc0e0ff),
                    ],
                    stops: [0.1, 0.3, 0.7, 1.0],
                  ).createShader(bounds),
                  child: Text('ASTHMA GUARD',
                      style: GoogleFonts.orbitron(
                          fontSize: 26, fontWeight: FontWeight.w900,
                          letterSpacing: 3, color: Colors.white)),
                ),
                const SizedBox(height: 8),
                // Subtitle — matches brand p in index.html
                Text('SENTINEL AI · REAL-TIME PROTECTION',
                    style: GoogleFonts.rajdhani(
                        fontSize: 12, letterSpacing: 4,
                        color: const Color(0xFF9A90B8))),
                const SizedBox(height: 48),
                // Loading indicator
                const SizedBox(
                  width: 48,
                  child: LinearProgressIndicator(
                    backgroundColor: Color(0x1AB496FF),
                    valueColor: AlwaysStoppedAnimation(Color(0xFF5B8FFF)),
                    minHeight: 2,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Grid background painter — matches body::after CSS grid ───────────
class _SplashGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color       = const Color(0xFF508CFF).withOpacity(0.025)
      ..strokeWidth = 1;
    const spacing = 44.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_SplashGridPainter old) => false;
}