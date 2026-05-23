// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ipCtrl = TextEditingController();
  bool  _testing   = false;
  bool? _connected;
  String _userName = '', _username = '';

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _ipCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final ip   = await ApiConfig.getSavedIp();
    final name = await AuthService.getName()    ?? '';
    final user = await AuthService.getUsername() ?? '';
    setState(() { _ipCtrl.text = ip; _userName = name; _username = user; });
  }

  Future<void> _saveIp() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) return;
    await ApiConfig.updateIp(ip);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Server IP updated to $ip',
          style: GoogleFonts.rajdhani(fontSize: 14)),
      backgroundColor: const Color(0xFF34D4A0),
    ));
    _testConnection();
  }

  Future<void> _testConnection() async {
    setState(() { _testing = true; _connected = null; });
    final ok = await ApiService.testConnection();
    setState(() { _testing = false; _connected = ok; });
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
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
      title: Text('SETTINGS',
          style: GoogleFonts.orbitron(
              fontSize: 14, fontWeight: FontWeight.w900,
              color: const Color(0xFFC8C0E0), letterSpacing: 3)),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: Color(0x145B8FFF)),
      ),
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
      ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Account
          _secHead('ACCOUNT'),
          const SizedBox(height: 10),
          _SectionCard(child: Column(children: [
            _InfoRow(icon: Icons.person_outline,    label: 'Name',     value: _userName),
            const Divider(color: Color(0x1AB496FF), height: 20),
            _InfoRow(icon: Icons.alternate_email,   label: 'Username', value: _username),
          ])),
          const SizedBox(height: 20),

          // Server
          _secHead('SERVER CONFIGURATION'),
          const SizedBox(height: 10),
          _SectionCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Raspberry Pi / Laptop IP Address',
                  style: GoogleFonts.rajdhani(
                      fontSize: 13, color: const Color(0xFF9A90B8),
                      letterSpacing: 1)),
              const SizedBox(height: 10),
              TextField(
                controller: _ipCtrl,
                keyboardType: TextInputType.url,
                style: GoogleFonts.spaceMono(
                    color: const Color(0xFFC8C0E0), fontSize: 15),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.settings_ethernet,
                      color: Color(0xFF5B8FFF)),
                  hintText: '192.168.1.105',
                  labelText: 'IP Address',
                  labelStyle: GoogleFonts.rajdhani(
                      color: const Color(0xFF9A90B8)),
                  hintStyle: GoogleFonts.spaceMono(
                      color: const Color(0xFF7A6FA8)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: const Color(0xFF5B8FFF).withOpacity(0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: const Color(0xFF5B8FFF).withOpacity(0.50)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveIp,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text('SAVE IP',
                        style: GoogleFonts.orbitron(
                            fontSize: 11, letterSpacing: 2)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B8FFF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF5B8FFF)))
                      : const Icon(Icons.wifi_find, size: 18,
                          color: Color(0xFF5B8FFF)),
                  label: Text('TEST',
                      style: GoogleFonts.orbitron(
                          fontSize: 11, color: const Color(0xFF5B8FFF),
                          letterSpacing: 2)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF5B8FFF)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                  ),
                ),
              ]),
              if (_connected != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: (_connected!
                        ? const Color(0xFF34D4A0)
                        : const Color(0xFFF05060)).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (_connected!
                          ? const Color(0xFF34D4A0)
                          : const Color(0xFFF05060)).withOpacity(0.30),
                    ),
                  ),
                  child: Row(children: [
                    Icon(
                      _connected!
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      color: _connected!
                          ? const Color(0xFF34D4A0)
                          : const Color(0xFFF05060),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _connected!
                            ? 'Server is reachable ✓'
                            : 'Cannot reach server. Check IP and Flask.',
                        style: GoogleFonts.rajdhani(
                          color: _connected!
                              ? const Color(0xFF34D4A0)
                              : const Color(0xFFF05060),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 10),
              Text('Current: ${ApiConfig.baseUrl}',
                  style: GoogleFonts.spaceMono(
                      fontSize: 9, color: const Color(0xFF7A6FA8))),
            ],
          )),
          const SizedBox(height: 20),

          // How to find IP
          _secHead('HOW TO FIND YOUR SERVER IP'),
          const SizedBox(height: 10),
          const _SectionCard(child: Column(children: [
            _HelpRow(os: 'Windows',      cmd: 'ipconfig'),
            _HelpRow(os: 'Linux / Mac',  cmd: 'hostname -I'),
            _HelpRow(os: 'Raspberry Pi', cmd: 'hostname -I'),
          ])),
          const SizedBox(height: 24),

          // Logout
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Color(0xFFF05060), size: 18),
            label: Text('LOGOUT',
                style: GoogleFonts.orbitron(
                    fontSize: 12, color: const Color(0xFFF05060),
                    letterSpacing: 2)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFF05060)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 20),
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
              fontSize: 11, letterSpacing: 4,
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
          _navItem(Icons.history_outlined,   'HISTORY',  '/history'),
          _navItem(Icons.settings_outlined,  'SETTINGS', '/settings', active: true),
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
                    color: active
                        ? const Color(0xFF5B8FFF)
                        : const Color(0xFF7A6FA8))),
          ]),
        ),
      ),
    );
  }
}

// ── Section card container ────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF0E0C1A).withOpacity(0.92),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x1AB496FF)),
    ),
    child: child,
  );
}

// ── Info row ──────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: const Color(0xFF5B8FFF), size: 18),
    const SizedBox(width: 12),
    Text('$label: ',
        style: GoogleFonts.rajdhani(
            color: const Color(0xFF9A90B8), fontSize: 14)),
    Text(value,
        style: GoogleFonts.rajdhani(
            color: const Color(0xFFF0EAFF),
            fontSize: 14, fontWeight: FontWeight.w700)),
  ]);
}

// ── Help row ──────────────────────────────────────────────────────────
class _HelpRow extends StatelessWidget {
  final String os, cmd;
  const _HelpRow({required this.os, required this.cmd});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      SizedBox(
        width: 110,
        child: Text(os,
            style: GoogleFonts.rajdhani(
                color: const Color(0xFF9A90B8),
                fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x1AB496FF)),
        ),
        child: Text(cmd,
            style: GoogleFonts.spaceMono(
                fontSize: 12, color: const Color(0xFF34D4A0))),
      ),
    ]),
  );
}

// ── Grid painter ──────────────────────────────────────────────────────
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