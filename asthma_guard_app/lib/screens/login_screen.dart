// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _loading = false;
  String? _errorMsg;
  String? _successMsg;
  String? _debugMsg;

  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _regUserCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 0.2).animate(_pulseCtrl);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _regUserCtrl.dispose();
    _regPassCtrl.dispose();
    super.dispose();
  }

  void _setError(String msg) {
    setState(() {
      _errorMsg = msg;
      _successMsg = null;
    });
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) setState(() => _errorMsg = null);
    });
  }

  void _goToDashboard() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  Future<void> _doLogin() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    if (user.isEmpty || pass.isEmpty) {
      return _setError('Please fill in all fields.');
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
      _debugMsg = null;
    });
    try {
      final res = await ApiService.login(user, pass);
      setState(() => _debugMsg = 'Response: $res');
      final success = res['success'] == true || res['token'] != null;
      if (success) {
        await AuthService.saveSession(res['token']?.toString() ?? 'session',
            res['name']?.toString() ?? user, user);
        _goToDashboard();
      } else {
        setState(() => _loading = false);
        _setError(res['message']?.toString() ?? 'Login failed. Got: $res');
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _debugMsg = 'Exception: $e';
      });
      _setError('$e');
    }
  }

  Future<void> _doRegister() async {
    final name = _nameCtrl.text.trim();
    final user = _regUserCtrl.text.trim();
    final pass = _regPassCtrl.text;
    if (name.isEmpty || user.isEmpty || pass.isEmpty) {
      return _setError('Please fill in all fields.');
    }
    if (pass.length < 6) {
      return _setError('Password must be at least 6 characters.');
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
      _debugMsg = null;
    });
    try {
      final res = await ApiService.register(name, user, pass);
      setState(() => _debugMsg = 'Response: $res');
      final success = res['success'] == true || res['token'] != null;
      if (success) {
        await AuthService.saveSession(
            res['token']?.toString() ?? 'session', name, user);
        setState(() {
          _loading = false;
          _successMsg = 'Account created! Entering dashboard...';
        });
        await Future.delayed(const Duration(milliseconds: 900));
        _goToDashboard();
      } else {
        setState(() => _loading = false);
        _setError(
            res['message']?.toString() ?? 'Registration failed. Got: $res');
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _debugMsg = 'Exception: $e';
      });
      _setError('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return Scaffold(
      backgroundColor: const Color(0xFF050D1A),
      body: Stack(children: [
        // Background — matches index.html body gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF050D1A), Color(0xFF060F1E), Color(0xFF050D1A)],
            ),
          ),
        ),
        // Radial glow top-left
        Positioned(
          top: -80,
          left: -80,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF2850B4).withOpacity(0.18),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        // Grid overlay
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),
        SafeArea(
          child: LayoutBuilder(builder: (ctx, constraints) {
            final isWide = constraints.maxWidth > 680;
            return isWide
                ? Row(children: [
                    Expanded(child: _buildBrandPanel()),
                    Expanded(child: _buildFormPanel()),
                  ])
                : SingleChildScrollView(
                    child: Column(children: [
                      _buildBrandPanelCompact(),
                      _buildFormPanel(),
                    ]),
                  );
          }),
        ),
      ]),
    );
  }

  // ── Brand panel — left column ────────────────────────────────────
  Widget _buildBrandPanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050D1A), Color(0xFF060F1E), Color(0xFF050D1A)],
        ),
        border: Border(
            right:
                BorderSide(color: const Color(0xFF5B8FFF).withOpacity(0.10))),
      ),
      padding: const EdgeInsets.all(48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Shield orb — .logo-orb style
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1E1630), Color(0xFF2E2050)]),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: const Color(0xFFC9A84C).withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF5B8FFF).withOpacity(0.10),
                  blurRadius: 30)
            ],
          ),
          child:
              const Center(child: Text('🛡️', style: TextStyle(fontSize: 36))),
        ),
        const SizedBox(height: 28),
        // Gradient title text
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFa0c8ff),
              Color(0xFF5B8FFF),
              Color(0xFFc0e0ff)
            ],
            stops: [0.1, 0.3, 0.7, 1.0],
          ).createShader(b),
          child: Text('ASTHMA\nGUARD AI',
              style: GoogleFonts.orbitron(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2)),
        ),
        const SizedBox(height: 6),
        Text('SENTINEL SYSTEM',
            style: GoogleFonts.rajdhani(
                fontSize: 11,
                letterSpacing: 4,
                color: const Color(0xFF9A90B8),
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        Text(
            'Real-time air quality and respiratory health monitoring for asthma patients.',
            style: GoogleFonts.rajdhani(
                fontSize: 15, color: const Color(0xFF7A6FA8), height: 1.6)),
        const Spacer(),
        _brandFeature(
            '🌬️', 'Air Quality Monitor', 'Live AQI with 6 pollutant sensors'),
        _brandFeature(
            '💗', 'Vitals Tracking', 'SpO2, heart rate & respiratory metrics'),
        _brandFeature('🚨', 'Emergency Alerts',
            'Critical level detection & notification'),
        const SizedBox(height: 28),
        // System operational badge — matches .live-badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF5B8FFF).withOpacity(0.06),
            borderRadius: BorderRadius.circular(50),
            border:
                Border.all(color: const Color(0xFF5B8FFF).withOpacity(0.20)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Opacity(
                opacity: _pulseAnim.value,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF34D4A0),
                      boxShadow: [
                        BoxShadow(color: Color(0x8034D4A0), blurRadius: 6)
                      ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('SYSTEM OPERATIONAL',
                style: GoogleFonts.rajdhani(
                    fontSize: 10,
                    letterSpacing: 2,
                    color: const Color(0xFF5B8FFF),
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBrandPanelCompact() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF050D1A),
      child: Row(children: [
        const Text('🛡️', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFF5B8FFF)],
            ).createShader(b),
            child: Text('ASTHMAGUARD AI',
                style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2)),
          ),
          Text('SENTINEL SYSTEM',
              style: GoogleFonts.rajdhani(
                  fontSize: 10,
                  letterSpacing: 3,
                  color: const Color(0xFF9A90B8))),
        ]),
      ]),
    );
  }

  Widget _brandFeature(String icon, String label, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.rajdhani(
                  color: const Color(0xFFC9A84C),
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          Text(sub,
              style: GoogleFonts.rajdhani(
                  color: const Color(0xFF7A6FA8), fontSize: 12)),
        ]),
      ]),
    );
  }

  // ── Form panel — right column ────────────────────────────────────
  Widget _buildFormPanel() {
    return Container(
      color: const Color(0xFF050D1A),
      padding: const EdgeInsets.all(32),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SECURE ACCESS PORTAL',
                style: GoogleFonts.rajdhani(
                    fontSize: 10,
                    letterSpacing: 4,
                    color: const Color(0xFF7A6FA8),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('WELCOME BACK',
                style: GoogleFonts.orbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFE8E0F5),
                    letterSpacing: 2)),
            const SizedBox(height: 6),
            Text('Sign in to your monitoring dashboard',
                style: GoogleFonts.rajdhani(
                    fontSize: 14, color: const Color(0xFF7A6FA8))),
            const SizedBox(height: 4),
            Text('→ ${ApiConfig.baseUrl}',
                style: GoogleFonts.spaceMono(
                    fontSize: 10, color: const Color(0xFF7A6FA8))),
            const SizedBox(height: 20),

            // Tabs
            Row(children: [
              _tab(
                  'SIGN IN',
                  _isLogin,
                  () => setState(() {
                        _isLogin = true;
                        _errorMsg = null;
                        _debugMsg = null;
                      })),
              _tab(
                  'REGISTER',
                  !_isLogin,
                  () => setState(() {
                        _isLogin = false;
                        _errorMsg = null;
                        _debugMsg = null;
                      })),
            ]),
            Container(height: 1, color: Colors.white.withOpacity(0.06)),
            const SizedBox(height: 20),

            // Banners
            if (_errorMsg != null) _alertBanner(_errorMsg!, isError: true),
            if (_successMsg != null) _alertBanner(_successMsg!, isError: false),

            // Debug
            if (_debugMsg != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Text(_debugMsg!,
                    style: GoogleFonts.spaceMono(
                        fontSize: 9, color: const Color(0xFF9A90B8))),
              ),

            // Fields
            if (_isLogin) ...[
              _field(
                  controller: _userCtrl,
                  label: 'USERNAME',
                  hint: 'Enter your username',
                  icon: '👤'),
              const SizedBox(height: 14),
              _field(
                  controller: _passCtrl,
                  label: 'PASSWORD',
                  hint: 'Enter your password',
                  icon: '🔒',
                  obscure: true),
            ] else ...[
              _field(
                  controller: _nameCtrl,
                  label: 'FULL NAME',
                  hint: 'Dr. John Smith',
                  icon: '🏷️'),
              const SizedBox(height: 12),
              _field(
                  controller: _regUserCtrl,
                  label: 'USERNAME',
                  hint: 'Choose a username',
                  icon: '👤'),
              const SizedBox(height: 12),
              _field(
                  controller: _regPassCtrl,
                  label: 'PASSWORD',
                  hint: 'Min 6 characters',
                  icon: '🔒',
                  obscure: true),
            ],
            const SizedBox(height: 16),
            _submitButton(),
          ]),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF5B8FFF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(label,
            style: GoogleFonts.rajdhani(
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: active
                    ? const Color(0xFF5B8FFF)
                    : const Color(0xFF7A6FA8))),
      ),
    );
  }

  Widget _alertBanner(String msg, {required bool isError}) {
    final color = isError ? const Color(0xFFF05060) : const Color(0xFF34D4A0);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text('${isError ? '⚠ ' : '✓ '}$msg',
          style: GoogleFonts.rajdhani(
              fontSize: 13,
              color:
                  isError ? const Color(0xFFE07080) : const Color(0xFF34D4A0))),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String icon,
    bool obscure = false,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.rajdhani(
              fontSize: 11,
              letterSpacing: 2,
              color: const Color(0xFF9A90B8),
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      TextField(
        controller: controller,
        obscureText: obscure,
        onSubmitted: (_) => _isLogin ? _doLogin() : _doRegister(),
        style:
            GoogleFonts.rajdhani(fontSize: 16, color: const Color(0xFFC9A84C)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.rajdhani(color: const Color(0xFF7A6FA8)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.03),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(icon, style: const TextStyle(fontSize: 16))),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: const Color(0xFF5B8FFF).withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: const Color(0xFF5B8FFF).withOpacity(0.50)),
          ),
        ),
      ),
    ]);
  }

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : (_isLogin ? _doLogin : _doRegister),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _loading
                  ? [const Color(0xFF3A2D1A), const Color(0xFF3B5FBF)]
                  : [const Color(0xFF5A3D1A), const Color(0xFF5B8FFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Text(
                    _isLogin ? 'ENTER DASHBOARD →' : 'CREATE ACCOUNT →',
                    style: GoogleFonts.orbitron(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Grid painter ─────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF508CFF).withOpacity(0.025)
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
  bool shouldRepaint(_GridPainter old) => false;
}
