// lib/screens/history_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

// ── AQI line chart painter — matches index.html visual style ─────────
class _AqiChartPainter extends CustomPainter {
  final List<Reading> readings;
  _AqiChartPainter(this.readings);

  @override
  void paint(Canvas canvas, Size size) {
    if (readings.isEmpty) return;

    final maxAqi = readings.map((r) => r.aqi).reduce(max).toDouble().clamp(100, 500);
    const minAqi = 0.0;
    final range  = maxAqi - minAqi;
    final w = size.width, h = size.height;
    const padL = 36.0, padB = 4.0, padT = 4.0;

    double dx(int i) =>
        padL + (i / (readings.length - 1).clamp(1, 999)) * (w - padL);
    double dy(double v) =>
        padT + (1 - (v - minAqi) / range) * (h - padT - padB);

    // Grid lines — rgba(91,143,255,0.08)
    final gridPaint = Paint()
      ..color       = const Color(0xFF5B8FFF).withOpacity(0.08)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = padT + (i / 4) * (h - padT - padB);
      canvas.drawLine(Offset(padL, y), Offset(w, y), gridPaint);
      final label = ((1 - i / 4) * maxAqi).toInt().toString();
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: const TextStyle(
                fontSize: 8, color: Color(0xFF7A6FA8), fontFamily: 'monospace')),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - 5));
    }

    // Gradient fill below line
    if (readings.length > 1) {
      final fillPath = Path();
      fillPath.moveTo(dx(0), dy(readings[0].aqi.toDouble()));
      for (int i = 1; i < readings.length; i++) {
        final x0 = dx(i - 1), y0 = dy(readings[i - 1].aqi.toDouble());
        final x1 = dx(i),     y1 = dy(readings[i].aqi.toDouble());
        final mx = (x0 + x1) / 2;
        fillPath.cubicTo(mx, y0, mx, y1, x1, y1);
      }
      fillPath.lineTo(dx(readings.length - 1), h);
      fillPath.lineTo(dx(0), h);
      fillPath.close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF5B8FFF).withOpacity(0.18),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );
    }

    // Line — #5b8fff
    if (readings.length > 1) {
      final linePath = Path();
      linePath.moveTo(dx(0), dy(readings[0].aqi.toDouble()));
      for (int i = 1; i < readings.length; i++) {
        final x0 = dx(i - 1), y0 = dy(readings[i - 1].aqi.toDouble());
        final x1 = dx(i),     y1 = dy(readings[i].aqi.toDouble());
        final mx = (x0 + x1) / 2;
        linePath.cubicTo(mx, y0, mx, y1, x1, y1);
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color      = const Color(0xFF5B8FFF)
          ..strokeWidth = 2.5
          ..style      = PaintingStyle.stroke
          ..strokeCap  = StrokeCap.round,
      );
    }

    // Dots — AQI-colored
    for (int i = 0; i < readings.length; i++) {
      final color = AppTheme.aqiColor(readings[i].aqi);
      canvas.drawCircle(
          Offset(dx(i), dy(readings[i].aqi.toDouble())), 3.5,
          Paint()..color = color);
      canvas.drawCircle(
          Offset(dx(i), dy(readings[i].aqi.toDouble())), 2,
          Paint()..color = const Color(0xFF060C18));
    }
  }

  @override
  bool shouldRepaint(_AqiChartPainter old) => old.readings != readings;
}

// ── History Screen ───────────────────────────────────────────────────
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Reading> _readings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        setState(() { _error = 'Not logged in.'; _loading = false; });
        return;
      }
      final data = await ApiService.getHistory(token, limit: 30);
      setState(() {
        _readings = data.map((e) => Reading.fromJson(e)).toList().reversed.toList();
        _loading  = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF060C18),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0E1A),
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 16,
            color: Color(0xFF9A90B8)),
        onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
      ),
      title: Text('HISTORY',
          style: GoogleFonts.orbitron(
              fontSize: 14, fontWeight: FontWeight.w900,
              color: const Color(0xFFC8C0E0), letterSpacing: 3)),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(
            height: 1, thickness: 1, color: Color(0x145B8FFF)),
      ),
      actions: [
        IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF5B8FFF), size: 20),
            onPressed: _load),
      ],
    ),
    body: Stack(children: [
      // Background
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF071020), Color(0xFF060C18), Color(0xFF060E1C)],
          ),
        ),
      ),
      // Grid
      Positioned.fill(child: CustomPaint(painter: _GridPainter())),
      // Content
      _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5B8FFF)))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: GoogleFonts.rajdhani(
                          color: const Color(0xFFF05060), fontSize: 16)))
              : _readings.isEmpty
                  ? Center(
                      child: Text('No readings yet',
                          style: GoogleFonts.rajdhani(
                              color: const Color(0xFF7A6FA8), fontSize: 16)))
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildChart(),
                        const SizedBox(height: 24),
                        _secHead('RECENT READINGS'),
                        const SizedBox(height: 12),
                        ..._readings.reversed.take(20).map(_buildRow),
                      ],
                    ),
    ]),
    bottomNavigationBar: _buildNavBar(),
  );

  // ── Section heading ────────────────────────────────────────────────
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

  // ── Chart ──────────────────────────────────────────────────────────
  Widget _buildChart() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0C1A).withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1AB496FF)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('AQI OVER TIME',
            style: GoogleFonts.rajdhani(
                fontSize: 12, letterSpacing: 4,
                color: const Color(0xFF9A90B8), fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('Last ${_readings.length} readings',
            style: GoogleFonts.spaceMono(
                fontSize: 10, color: const Color(0xFF7A6FA8))),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: CustomPaint(
            painter: _AqiChartPainter(_readings),
            size: const Size(double.infinity, 180),
          ),
        ),
        const SizedBox(height: 12),
        // Legend
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final e in [
            ['Good',     const Color(0xFF34D4A0)],
            ['Moderate', const Color(0xFFF0A443)],
            ['Danger',   const Color(0xFFF05060)],
          ]) ...[
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: e[1] as Color),
            ),
            const SizedBox(width: 4),
            Text(e[0] as String,
                style: GoogleFonts.rajdhani(
                    fontSize: 11, color: const Color(0xFF7A6FA8))),
            const SizedBox(width: 14),
          ]
        ]),
      ]),
    );
  }

  // ── Nav bar ────────────────────────────────────────────────────────
  Widget _buildNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0E0C1A),
        border: Border(top: BorderSide(color: Color(0x1AB496FF))),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          _navItem(Icons.dashboard_outlined, 'LIVE',     '/dashboard'),
          _navItem(Icons.history_outlined,   'HISTORY',  '/history', active: true),
          _navItem(Icons.settings_outlined,  'SETTINGS', '/settings'),
        ]),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, String route,
      {bool active = false}) {
    return Expanded(
      child: InkWell(
        onTap: () { if (!active) Navigator.pushReplacementNamed(context, route); },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                color: active ? const Color(0xFF5B8FFF) : const Color(0xFF7A6FA8),
                size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Orbitron', fontSize: 8, letterSpacing: 2,
                    color: active ? const Color(0xFF5B8FFF) : const Color(0xFF7A6FA8))),
          ]),
        ),
      ),
    );
  }

  // ── Reading row ────────────────────────────────────────────────────
  Widget _buildRow(Reading r) {
    final color = AppTheme.aqiColor(r.aqi);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0C1A).withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Center(
            child: Text('${r.aqi}',
                style: GoogleFonts.orbitron(
                    fontSize: 12, fontWeight: FontWeight.w900, color: color)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.risk.toUpperCase(),
                style: GoogleFonts.rajdhani(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: const Color(0xFFE8E0F5))),
            Text(r.timestamp,
                style: GoogleFonts.spaceMono(
                    fontSize: 10, color: const Color(0xFF7A6FA8))),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${r.spo2.toStringAsFixed(0)}% SpO₂',
              style: GoogleFonts.spaceMono(
                  fontSize: 10, color: const Color(0xFFa855f7))),
          Text('${r.heartRate.toStringAsFixed(0)} bpm',
              style: GoogleFonts.spaceMono(
                  fontSize: 10, color: const Color(0xFFec4899))),
        ]),
      ]),
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