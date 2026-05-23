// lib/screens/dashboard_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

// ── AQI helpers ──────────────────────────────────────────────────────
String aqiToLabel(int aqi) {
  if (aqi <= 50)  return 'Good';
  if (aqi <= 100) return 'Moderate';
  if (aqi <= 150) return 'Unhealthy for Sensitive Groups';
  if (aqi <= 200) return 'Unhealthy';
  if (aqi <= 300) return 'Very Unhealthy';
  return 'Hazardous';
}

String aqiShortLabel(int aqi) {
  if (aqi <= 50)  return 'GOOD';
  if (aqi <= 100) return 'MODERATE';
  if (aqi <= 150) return 'SENSITIVE';
  if (aqi <= 200) return 'UNHEALTHY';
  if (aqi <= 300) return 'VERY HIGH';
  return 'HAZARDOUS';
}

// ── Gauge painter ────────────────────────────────────────────────────
class _GaugePainter extends CustomPainter {
  final double aqi;
  _GaugePainter(this.aqi);

  static const _start = 0.75 * pi;
  static const _sweep = 1.5  * pi;

  Color _color(double f) {
    const stops = [
      [0.00, Color(0xFF4ECB8D)], [0.25, Color(0xFFD4B43A)],
      [0.50, Color(0xFFC07830)], [0.75, Color(0xFFC0394B)],
      [1.00, Color(0xFF8B5CF6)],
    ];
    for (int i = 0; i < stops.length - 1; i++) {
      final t0 = stops[i][0] as double, t1 = stops[i + 1][0] as double;
      if (f <= t1) {
        return Color.lerp(
            stops[i][1] as Color, stops[i + 1][1] as Color,
            (f - t0) / (t1 - t0))!;
      }
    }
    return const Color(0xFF8B5CF6);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r  = min(cx, cy) * 0.72;
    const lw = 14.0;
    final p  = Paint()
      ..style    = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    p ..color      = const Color(0xFF5B8FFF).withOpacity(0.10)
      ..strokeWidth = 1
      ..strokeCap   = StrokeCap.butt;
    canvas.drawCircle(Offset(cx, cy), r + 18, p);

    p ..color      = const Color(0xFF5B8FFF).withOpacity(0.07)
      ..strokeWidth = lw
      ..strokeCap   = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        _start, _sweep, false, p);

    for (int i = 0; i < 60; i++) {
      final f0 = i / 60;
      final a0 = _start + f0 * _sweep;
      final a1 = _start + (i + 1) / 60 * _sweep;
      p ..color      = _color(f0)
        ..strokeWidth = 3
        ..strokeCap   = StrokeCap.butt;
      canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r + 10),
          a0, a1 - a0, false, p);
    }

    final frac = aqi.clamp(0, 500) / 500;
    if (frac > 0) {
      p ..color      = _color(frac)
        ..strokeWidth = lw
        ..strokeCap   = StrokeCap.round;
      canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          _start, frac * _sweep, false, p);
    }

    for (int i = 0; i <= 4; i++) {
      final a = _start + (i / 4) * _sweep;
      p ..color      = const Color(0xFF5B8FFF).withOpacity(0.30)
        ..strokeWidth = 1.5
        ..strokeCap   = StrokeCap.round;
      canvas.drawLine(
        Offset(cx + cos(a) * (r - lw / 2 - 4), cy + sin(a) * (r - lw / 2 - 4)),
        Offset(cx + cos(a) * (r + lw / 2 + 4), cy + sin(a) * (r + lw / 2 + 4)),
        p,
      );
    }

    final na = _start + frac * _sweep;
    p ..color      = const Color(0xFF5B8FFF)
      ..strokeWidth = 2.5
      ..strokeCap   = StrokeCap.round;
    canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + cos(na) * (r - 8), cy + sin(na) * (r - 8)),
        p);

    canvas.drawCircle(Offset(cx, cy), 7,
        Paint()..color = const Color(0xFF5B8FFF));
    canvas.drawCircle(Offset(cx, cy), 3.5,
        Paint()..color = const Color(0xFF050D1A));
  }

  @override
  bool shouldRepaint(_GaugePainter o) => o.aqi != aqi;
}

// ── Dashboard ────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Timer? _sessionTimer;
  Map<String, dynamic>? _data;
  bool _showEmergency = false;
  bool _acknowledged = false;
  String? _token;
  int _sessionSeconds = 0;
  bool _initializing = true;

  late AnimationController _emergencyCtrl;
  late Animation<double>   _emergencyAnim;

  @override
  void initState() {
    super.initState();
    _emergencyCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _emergencyAnim = Tween(begin: 0.0, end: 1.0).animate(_emergencyCtrl);
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _sessionSeconds++);
    });
    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    _token = await AuthService.getToken();
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sessionTimer?.cancel();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final d = await ApiService.getStatus(token: _token);
    if (!mounted) return;
    setState(() {
      _data = d;
      _initializing = false;
      final aqi = (d?['aqi'] as num?)?.toInt() ?? 0;
      final isDanger = AppTheme.aqiLevel(aqi) == 'danger';
      if (!isDanger) _acknowledged = false; // reset when air clears
      if (!_acknowledged) _showEmergency = isDanger;
    });
  }

  double _num(String k) => ((_data?[k]) as num?)?.toDouble() ?? 0.0;
  int    _aqi()         => ((_data?['aqi']) as num?)?.toInt() ?? 0;
  String _level()       => _initializing ? 'initializing' : AppTheme.aqiLevel(_aqi());

  Color _heroColor() {
    if (_initializing) return const Color(0xFF00E5FF);
    switch (_level()) {
      case 'safe':     return const Color(0xFF34D4A0);
      case 'moderate': return const Color(0xFFF0A443);
      default:         return const Color(0xFFF05060);
    }
  }

  String _sessionLabel() {
    final h = (_sessionSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_sessionSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_sessionSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050D1A),
      body: Stack(children: [
        // Background gradient
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
        // Grid overlay
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),
        // Emergency red overlay
        if (_showEmergency)
          AnimatedBuilder(
            animation: _emergencyAnim,
            builder: (_, __) => Container(
              color: Colors.red.withOpacity(_emergencyAnim.value * 0.06),
            ),
          ),
        SafeArea(
          child: Column(children: [
            _buildNavBar(),
            // Thin accent line under nav
            Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  Color(0xFF00E5FF),
                  Color(0xFF5B8FFF),
                  Colors.transparent,
                ]),
              ),
            ),
            if (_level() == 'moderate') _buildModerateBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildRiskHero(),
                  const SizedBox(height: 24),
                  _buildSensorSection(),
                  const SizedBox(height: 20),
                  _buildVitalsSection(),
                  const SizedBox(height: 20),
                  _buildActionsSection(),
                ]),
              ),
            ),
          ]),
        ),
        if (_showEmergency) _buildEmergencyModal(),
      ]),
      bottomNavigationBar: _buildNavBarBottom(),
    );
  }

  // ── Top Nav Bar — matches screenshot header ───────────────────────
  Widget _buildNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.transparent,
      child: Row(children: [
        // Shield icon
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1630), Color(0xFF2A1F4A)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFC9A84C).withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(color: const Color(0xFF5B8FFF).withOpacity(0.15),
                  blurRadius: 16),
            ],
          ),
          child: const Center(child: Text('🛡️', style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFa0c8ff),
                       Color(0xFF5b8fff), Color(0xFFc0e0ff)],
              stops: [0.1, 0.3, 0.7, 1.0],
            ).createShader(b),
            child: Text('ASTHMA GUARD',
                style: GoogleFonts.orbitron(
                    fontSize: 16, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: 2)),
          ),
          Text('SENTINEL AI · REAL-TIME PROTECTION',
              style: GoogleFonts.rajdhani(
                  fontSize: 10, letterSpacing: 3,
                  color: const Color(0xFF9A90B8))),
        ]),
        const Spacer(),
        // Live monitoring badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withOpacity(0.06),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF00E5FF),
                boxShadow: [BoxShadow(color: Color(0x8000E5FF), blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 6),
            Text('LIVE MONITORING',
                style: GoogleFonts.spaceMono(
                    fontSize: 9, color: const Color(0xFF00E5FF),
                    letterSpacing: 1)),
          ]),
        ),
        const SizedBox(width: 10),
        // Session timer
        Text(_sessionLabel(),
            style: GoogleFonts.spaceMono(
                fontSize: 14, color: const Color(0xFF7A6FA8),
                letterSpacing: 1)),
      ]),
    );
  }

  // ── Bottom nav bar ────────────────────────────────────────────────
  Widget _buildNavBarBottom() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B1525),
        border: Border(top: BorderSide(color: Color(0x1A00E5FF))),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          _navItem(Icons.dashboard_outlined, 'LIVE',     '/dashboard'),
          _navItem(Icons.history_outlined,   'HISTORY',  '/history'),
          _navItem(Icons.settings_outlined,  'SETTINGS', '/settings'),
        ]),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, String route) {
    final active = route == '/dashboard';
    return Expanded(
      child: InkWell(
        onTap: () { if (!active) Navigator.pushReplacementNamed(context, route); },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                color: active ? const Color(0xFF00E5FF) : const Color(0xFF7A6FA8),
                size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Orbitron', fontSize: 8, letterSpacing: 2,
                    color: active ? const Color(0xFF00E5FF) : const Color(0xFF7A6FA8))),
          ]),
        ),
      ),
    );
  }

  // ── Moderate Banner ───────────────────────────────────────────────
  Widget _buildModerateBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: const BoxDecoration(
        color: Color(0xFF060C1C),
        border: Border(bottom: BorderSide(color: Color(0x59F0A443), width: 1.5)),
      ),
      child: Row(children: [
        const Text('⚡', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: const TextSpan(children: [
              TextSpan(
                  text: 'MODERATE AIR QUALITY ALERT  ',
                  style: TextStyle(
                      fontFamily: 'Rajdhani', fontWeight: FontWeight.w700,
                      color: Color(0xFFF0A443), fontSize: 14)),
              TextSpan(
                  text: 'Sensitive groups may experience symptoms.',
                  style: TextStyle(
                      fontFamily: 'Rajdhani', color: Color(0xFF8A7840),
                      fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Risk Hero — matches screenshot exactly ────────────────────────
  Widget _buildRiskHero() {
    final aqi       = _aqi();
    final heroColor = _heroColor();
    final level     = _level();

    final riskText = _initializing
        ? 'INITIALIZING'
        : ((_data?['risk'] as String?) ?? level.toUpperCase());

    final desc = _initializing
        ? 'Connecting to IoT sensors and AI prediction engine...'
        : {
            'safe':     'Air quality is within safe parameters. All activities permitted.',
            'moderate': 'Air quality is moderate. Sensitive groups should limit outdoor activities.',
            'danger':   'Dangerous air quality detected. Immediate action required.',
          }[level] ?? '';

    final tags = _initializing
        ? ['🛡️ All Clear', '✅ Safe to Breathe', '🌿 Normal Activity OK']
        : {
            'safe':     ['🛡️ All Clear', '✅ Safe to Breathe', '🌿 Normal Activity OK'],
            'moderate': ['⚠️ Moderate Risk', '😷 Consider Mask', '🚶 Limit Outdoors'],
            'danger':   ['🚨 DANGER', '🏠 Stay Indoors', '💊 Use Inhaler'],
          }[level] ?? [];

    final borderColor = _initializing
        ? const Color(0xFF00E5FF).withOpacity(0.20)
        : level == 'safe'
            ? const Color(0xFF34D4A0).withOpacity(0.20)
            : level == 'moderate'
                ? const Color(0xFFF0A443).withOpacity(0.22)
                : const Color(0xFFF05060).withOpacity(0.32);

    final barGradient = _initializing
        ? const LinearGradient(colors: [Colors.transparent, Color(0xFF00E5FF), Color(0xFF5B8FFF), Colors.transparent])
        : level == 'safe'
            ? const LinearGradient(colors: [Colors.transparent, Color(0xFF34D4A0), Color(0xFF5B8FFF), Colors.transparent])
            : level == 'moderate'
                ? const LinearGradient(colors: [Colors.transparent, Color(0xFFF0A443), Color(0xFF5B8FFF), Colors.transparent])
                : const LinearGradient(colors: [Colors.transparent, Color(0xFFF05060), Color(0xFFa02030), Colors.transparent]);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1422).withOpacity(0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: level == 'danger'
            ? [BoxShadow(color: heroColor.withOpacity(0.10), blurRadius: 28)]
            : null,
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Accent bar
        Container(height: 3, decoration: BoxDecoration(gradient: barGradient)),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Left
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: heroColor,
                      boxShadow: [BoxShadow(color: heroColor.withOpacity(0.6), blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('CURRENT ASTHMA RISK ASSESSMENT',
                      style: GoogleFonts.rajdhani(
                          fontSize: 11, letterSpacing: 3,
                          color: const Color(0xFF9A90B8),
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 10),
                // Big risk text
                Text(riskText,
                    style: GoogleFonts.orbitron(
                        fontSize: _initializing ? 34 : 28,
                        fontWeight: FontWeight.w900,
                        color: heroColor,
                        letterSpacing: 2,
                        shadows: [Shadow(color: heroColor.withOpacity(0.5), blurRadius: 20)])),
                const SizedBox(height: 10),
                Text(desc,
                    style: GoogleFonts.rajdhani(
                        fontSize: 14, color: const Color(0xFFC8C0E0),
                        height: 1.6),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                // Tags row
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x265B8FFF)),
                    ),
                    child: Text(t,
                        style: GoogleFonts.rajdhani(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: const Color(0xFFC8C0E0))),
                  )).toList(),
                ),
              ]),
            ),
          ),
          // Right — AQI gauge
          Container(
            width: 150,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0x1E000000),
              border: Border(left: BorderSide(color: Color(0x0DFFFFFF))),
            ),
            child: Column(children: [
              if (!_initializing) ...[
                SizedBox(
                  width: 120, height: 120,
                  child: Stack(alignment: Alignment.center, children: [
                    CustomPaint(
                        painter: _GaugePainter(aqi.toDouble()),
                        size: const Size(120, 120)),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(height: 18),
                      Text('$aqi',
                          style: GoogleFonts.orbitron(
                              fontSize: 24, fontWeight: FontWeight.w900,
                              color: heroColor)),
                      Text('AQI',
                          style: GoogleFonts.rajdhani(
                              fontSize: 11, letterSpacing: 4,
                              color: const Color(0xFF7A6FA8),
                              fontWeight: FontWeight.w700)),
                      Text(aqiShortLabel(aqi),
                          style: GoogleFonts.rajdhani(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              letterSpacing: 1, color: heroColor)),
                    ]),
                  ]),
                ),
              ] else ...[
                // Initializing AQI placeholder — matches screenshot
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D4A0),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: const Color(0xFF34D4A0).withOpacity(0.5), blurRadius: 8)],
                  ),
                ),
                const SizedBox(height: 8),
                Text('AQI',
                    style: GoogleFonts.rajdhani(
                        fontSize: 11, letterSpacing: 4,
                        color: const Color(0xFF7A6FA8),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  width: 20, height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D4A0).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text('LAST UPDATE',
                  style: GoogleFonts.rajdhani(
                      fontSize: 10, letterSpacing: 3,
                      color: const Color(0xFF9A90B8), fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(_initializing ? '--:--:--' : (_data?['timestamp'] ?? '--:--:--'),
                  style: GoogleFonts.spaceMono(
                      fontSize: 11, color: const Color(0xFFE8E0F5),
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ]),
    );
  }

  // ── LIVE SENSOR MATRIX — 4-column grid matching screenshot ───────
  Widget _buildSensorSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secHead('LIVE SENSOR MATRIX'),
      const SizedBox(height: 12),
      Column(
        children: [
          Row(children: [
            Expanded(child: _sensorCard('🌫️', 'PM 2.5',      'μg/m³', _num('pm25'),     250,  const Color(0xFF00D4FF))),
            const SizedBox(width: 10),
            Expanded(child: _sensorCard('🌁', 'PM 10',        'μg/m³', _num('pm10'),     430,  const Color(0xFFa78bfa))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _sensorCard('🔴', 'NO₂',          'ppm',   _num('no2'),      2,    const Color(0xFFfb7185))),
            const SizedBox(width: 10),
            Expanded(child: _sensorCard('🟡', 'SO₂',          'ppm',   _num('so2'),      1,    const Color(0xFFfbbf24))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _sensorCard('💨', 'CO',            'ppm',   _num('co'),       50,   const Color(0xFFf97316))),
            const SizedBox(width: 10),
            Expanded(child: _sensorCard('🌀', 'OZONE O₃',     'ppm',   _num('o3'),       0.5,  const Color(0xFF34d399))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _sensorCard('🌡️', 'TEMPERATURE',  '°C',    _num('temp'),     50,   const Color(0xFFf43f5e))),
            const SizedBox(width: 10),
            Expanded(child: _sensorCard('💧', 'HUMIDITY',      '%',     _num('humidity'), 100,  const Color(0xFF0ea5e9))),
          ]),
        ],
      ),
    ]);
  }

  // ── Sensor card — matches screenshot card style exactly ───────────
  Widget _sensorCard(String icon, String name, String unit,
      double value, double max, Color color) {
    final pct = (value / max).clamp(0.0, 1.0);
    final display = value >= 10
        ? value.toStringAsFixed(1)
        : value.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1525),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A00E5FF)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withOpacity(0.7), blurRadius: 6)],
            ),
          ),
        ]),
        const SizedBox(height: 5),
        Text(name,
            style: GoogleFonts.rajdhani(
                fontSize: 11, letterSpacing: 1.5,
                color: const Color(0xFFB0A8CC), fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis, maxLines: 1),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(display,
              style: GoogleFonts.orbitron(
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: const Color(0xFFF0EAFF))),
        ),
        Text(unit,
            style: GoogleFonts.rajdhani(
                fontSize: 12, color: const Color(0xFF9A90B8),
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: pct,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Patient Vitals section ────────────────────────────────────────
  Widget _buildVitalsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secHead('PATIENT VITALS — MAX30100'),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _vitalCard('🩸', 'Blood Oxygen Saturation', 'SpO₂',
            _num('spo2').toStringAsFixed(1), '%', const Color(0xFFa855f7))),
        const SizedBox(width: 12),
        Expanded(child: _vitalCard('❤️', 'Heart Rate', 'BPM',
            _num('heart_rate').toInt().toString(), 'bpm', const Color(0xFFec4899))),
      ]),
    ]);
  }

  Widget _vitalCard(String emoji, String title, String shortLabel,
      String value, String unit, Color color) {
    final pct = shortLabel == 'SpO₂'
        ? (_num('spo2') / 100).clamp(0.0, 1.0)
        : (_num('heart_rate') / 200).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1525),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.rajdhani(
                      fontSize: 11, letterSpacing: 2,
                      color: const Color(0xFF9A90B8)),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(
                        text: value,
                        style: GoogleFonts.orbitron(
                            fontSize: 26, fontWeight: FontWeight.w900,
                            color: color)),
                    TextSpan(
                        text: ' $unit',
                        style: GoogleFonts.orbitron(
                            fontSize: 12, color: color.withOpacity(0.6))),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 2),
            Text(shortLabel,
                style: GoogleFonts.rajdhani(
                    fontSize: 10, letterSpacing: 1,
                    color: const Color(0xFF9A90B8))),
          ]),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 5,
          ),
        ),
      ]),
    );
  }

  // ── Recommended Actions ───────────────────────────────────────────
  Widget _buildActionsSection() {
    final level = _level();
    final items = {
      'initializing': [
        {'n': '01', 'title': 'System Connecting',     'desc': 'Establishing connection to IoT sensors and AI prediction engine.'},
        {'n': '02', 'title': 'Keep Medication Ready', 'desc': 'Always have rescue inhaler within reach as standard practice.'},
        {'n': '03', 'title': 'Monitor Readings',      'desc': 'Dashboard will update every 2 seconds once connected.'},
      ],
      'safe': [
        {'n': '01', 'title': 'Continue Normal Activities', 'desc': 'Air quality is safe. No restrictions for anyone including asthma patients.'},
        {'n': '02', 'title': 'Keep Medication Accessible', 'desc': 'Always have rescue inhaler within reach as standard practice.'},
        {'n': '03', 'title': 'Monitor Readings',           'desc': 'Dashboard updates every 2 seconds. Watch for spikes in PM2.5 or NO₂.'},
        {'n': '04', 'title': 'Stay Hydrated',              'desc': 'Good hydration supports respiratory health and pollutant clearance.'},
      ],
      'moderate': [
        {'n': '01', 'title': 'Wear N95 Mask',          'desc': 'Sensitive groups consider wearing a high-filtration mask outdoors.'},
        {'n': '02', 'title': 'Limit Outdoor Activity', 'desc': 'Reduce prolonged outdoor exertion, especially for asthma patients.'},
        {'n': '03', 'title': 'Keep Inhaler Ready',     'desc': 'Keep rescue inhaler accessible at all times.'},
        {'n': '04', 'title': 'Close Windows',          'desc': 'Keep windows closed to reduce indoor pollutant levels.'},
      ],
      'danger': [
        {'n': '01', 'title': 'Stay Indoors Now',       'desc': 'Avoid all outdoor activities immediately. Seal doors and windows.'},
        {'n': '02', 'title': 'Use Inhaler Immediately','desc': 'Administer bronchodilator and prescribed preventive medications now.'},
        {'n': '03', 'title': 'Call Your Doctor',       'desc': 'Alert your healthcare provider. Have emergency contacts ready.'},
        {'n': '04', 'title': 'Prepare for Emergency',  'desc': 'Be ready to seek emergency medical care if symptoms worsen.'},
      ],
    }[level] ?? [];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secHead('RECOMMENDED ACTIONS'),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1525),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x1A00E5FF)),
        ),
        child: Column(
          children: items.asMap().entries.map((e) {
            final i    = e.key;
            final item = e.value;
            final isFirst = i == 0;
            return Container(
              margin: EdgeInsets.only(bottom: i < items.length - 1 ? 10 : 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isFirst
                    ? const Color(0xFF34D4A0).withOpacity(0.06)
                    : const Color(0xFF5B8FFF).withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isFirst
                        ? const Color(0xFF34D4A0).withOpacity(0.20)
                        : const Color(0xFF5B8FFF).withOpacity(0.10)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['n']!,
                    style: GoogleFonts.orbitron(
                        fontSize: 13, fontWeight: FontWeight.w900,
                        color: const Color(0xFF5B8FFF))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['title']!,
                        style: GoogleFonts.rajdhani(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: const Color(0xFFF0EAFF))),
                    const SizedBox(height: 3),
                    Text(item['desc']!,
                        style: GoogleFonts.rajdhani(
                            fontSize: 13, color: const Color(0xFFC8C0E0),
                            height: 1.5)),
                  ]),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  // ── Section heading ───────────────────────────────────────────────
  Widget _secHead(String text) {
    return Row(children: [
      Text(text,
          style: GoogleFonts.rajdhani(
              fontSize: 12, letterSpacing: 4,
              color: const Color(0xFF9A90B8), fontWeight: FontWeight.w700)),
      const SizedBox(width: 10),
      Expanded(
        child: Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x405B8FFF), Colors.transparent],
            ),
          ),
        ),
      ),
    ]);
  }

  // ── Emergency Modal ───────────────────────────────────────────────
  Widget _buildEmergencyModal() {
    return Material(
      color: Colors.black.withOpacity(0.92),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF080206),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFF05060).withOpacity(0.55), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFC0394B).withOpacity(0.18),
                    blurRadius: 50, spreadRadius: 5),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedBuilder(
                animation: _emergencyAnim,
                builder: (_, __) => Transform.scale(
                  scale: 1.0 + 0.18 * _emergencyAnim.value,
                  child: const Text('🚨', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _emergencyAnim,
                builder: (_, __) => Opacity(
                  opacity: 0.6 + 0.4 * _emergencyAnim.value,
                  child: Text('CRITICAL ALERT',
                      style: GoogleFonts.orbitron(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          color: const Color(0xFFF05060), letterSpacing: 3)),
                ),
              ),
              const SizedBox(height: 2),
              Text('Dangerous Air Quality Detected',
                  style: GoogleFonts.rajdhani(
                      fontSize: 12, letterSpacing: 2,
                      color: const Color(0xFFFF8FA3))),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D55).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.30)),
                ),
                child: Text('AQI ${_aqi()} — SEVERE RISK',
                    style: GoogleFonts.orbitron(
                        fontSize: 14, color: Colors.white, letterSpacing: 2)),
              ),
              const SizedBox(height: 16),
              for (final item in [
                ['🫁', 'Acute Bronchospasm',          'Airways constrict violently. Asthma attack is highly probable.'],
                ['💔', 'Cardiovascular Stress',        'PM2.5 enters bloodstream. Heart attack risk elevated.'],
                ['🧠', 'Neurological Impairment',      'Oxygen deprivation may cause dizziness and confusion.'],
                ['👶', 'Vulnerable Groups at Risk',    'Children, elderly, and pregnant individuals must evacuate.'],
              ])
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF1E3C).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFF1E3C).withOpacity(0.10)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item[0], style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item[1],
                            style: GoogleFonts.rajdhani(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: const Color(0xFFFFD0DA))),
                        Text(item[2],
                            style: GoogleFonts.rajdhani(
                                fontSize: 12, color: const Color(0xFF9A6070),
                                height: 1.4)),
                      ]),
                    ),
                  ]),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6, runSpacing: 6,
                alignment: WrapAlignment.center,
                children: ['💊 Use Inhaler Now', '🏠 Move Indoors',
                  '😷 Wear N95', '📞 Call Doctor'].map((pill) =>
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34D4A0).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: const Color(0xFF34D4A0).withOpacity(0.25)),
                    ),
                    child: Text(pill,
                        style: GoogleFonts.rajdhani(
                            fontSize: 13, color: const Color(0xFF34D4A0),
                            fontWeight: FontWeight.w600)),
                  ),
                ).toList(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() { _showEmergency = false; _acknowledged = true; }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF6A1020), Color(0xFFF05060)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      alignment: Alignment.center,
                      child: Text('ACKNOWLEDGE & MONITOR',
                          style: GoogleFonts.orbitron(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              letterSpacing: 2, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Grid background painter ───────────────────────────────────────────
class _GridPainter extends CustomPainter {
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
  bool shouldRepaint(_GridPainter old) => false;
}