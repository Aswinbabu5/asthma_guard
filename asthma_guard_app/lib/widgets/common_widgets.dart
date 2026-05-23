// lib/widgets/common_widgets.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

// ── Shared Grid Background ────────────────────────────────────────────
class GridBackground extends StatelessWidget {
  const GridBackground({super.key});
  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: CustomPaint(painter: _GridPainter()),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color       = AppColors.primary.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    const spacing = 48.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override bool shouldRepaint(_GridPainter o) => false;
}

// ── Radial Glow Decoration ────────────────────────────────────────────
class RadialGlow extends StatelessWidget {
  final Color color;
  final double size;
  final Alignment alignment;
  const RadialGlow({
    super.key,
    required this.color,
    this.size = 400,
    this.alignment = Alignment.topLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.18), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

// ── App Screen Shell ──────────────────────────────────────────────────
class AppShell extends StatelessWidget {
  final Widget body;
  const AppShell({super.key, required this.body});
  @override
  Widget build(BuildContext context) => Stack(children: [
    // Gradient bg
    Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.bg1, AppColors.bg0, AppColors.bg2],
        ),
      ),
    ),
    const RadialGlow(color: AppColors.primary, size: 480, alignment: Alignment.topRight),
    const RadialGlow(color: AppColors.accent,  size: 320, alignment: Alignment.bottomLeft),
    const GridBackground(),
    body,
  ]);
}

// ── Custom Text Field ─────────────────────────────────────────────────
class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onSubmit;
  final TextInputType keyboardType;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.onSubmit,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscure = true;
  bool _focused = false;
  late FocusNode _fn;

  @override
  void initState() {
    super.initState();
    _fn = FocusNode()..addListener(() {
      setState(() => _focused = _fn.hasFocus);
    });
  }

  @override
  void dispose() { _fn.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(widget.label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: _focused ? AppColors.primaryLight : AppColors.textSecondary,
                letterSpacing: 0.5)),
      ),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _focused ? [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 12, spreadRadius: 2),
          ] : [],
        ),
        child: TextField(
          controller:  widget.controller,
          focusNode:   _fn,
          obscureText: widget.obscure ? _obscure : false,
          onSubmitted: (_) => widget.onSubmit?.call(),
          keyboardType: widget.keyboardType,
          style: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon,
                color: _focused ? AppColors.primary : AppColors.textMuted, size: 20),
            suffixIcon: widget.obscure
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textMuted, size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
          ),
        ),
      ),
    ]);
  }
}

// ── Gradient Button ───────────────────────────────────────────────────
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final List<Color> colors;
  final double height;
  final double borderRadius;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.colors = const [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
    this.height = 56,
    this.borderRadius = 16,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp:   (_) { _ctrl.reverse(); widget.onPressed?.call(); },
      onTapCancel: ()=> _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: widget.onPressed == null
                  ? [AppColors.surface, AppColors.surfaceElevated]
                  : widget.colors,
            ),
            boxShadow: widget.onPressed != null ? [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 16, offset: const Offset(0, 6)),
            ] : [],
          ),
          alignment: Alignment.center,
          child: widget.loading
              ? const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Text(widget.label,
                  style: GoogleFonts.plusJakartaSans(
                      color: widget.onPressed != null
                          ? Colors.white : AppColors.textMuted,
                      fontSize: 15, fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
        ),
      ),
    );
  }
}

// ── Animated Card ─────────────────────────────────────────────────────
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final Duration delay;
  final Color? borderColor;
  final double borderRadius;
  final List<BoxShadow>? shadows;

  const AnimatedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.delay = Duration.zero,
    this.borderColor,
    this.borderRadius = 24,
    this.shadows,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
                color: widget.borderColor ?? AppColors.border),
            boxShadow: widget.shadows ?? [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String text;
  const SectionHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(children: [
        Container(
          width: 3, height: 14,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(text,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 2, color: AppColors.textSecondary)),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withValues(alpha: 0.3), Colors.transparent],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Premium Bottom Nav ────────────────────────────────────────────────
class PremiumNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const PremiumNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.air_rounded,      Icons.air,      'Live'),
      (Icons.history_rounded,  Icons.history,  'History'),
      (Icons.tune_rounded,     Icons.tune,     'Settings'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
            top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: _NavItem(
                  icon:     items[i].$1,
                  label:    items[i].$3,
                  active:   i == currentIndex,
                  onTap:    () => onTap(i),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon, required this.label,
    required this.active, required this.onTap,
  });
  @override State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp:   (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color:        widget.active ? AppColors.primaryGlow : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon,
                  size: 22,
                  color: widget.active ? AppColors.primary : AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(widget.label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5,
                    color: widget.active ? AppColors.primary : AppColors.textMuted)),
          ]),
        ),
      ),
    );
  }
}

// ── Alert Banner ──────────────────────────────────────────────────────
class AlertBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const AlertBanner({super.key, required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.success;
    final icon  = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(message),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: GoogleFonts.plusJakartaSans(
                    color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ]),
      ),
    );
  }
}

// ── Stat Chip ─────────────────────────────────────────────────────────
class StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  const StatChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
        ],
        Text(value,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w800,
                color: color, letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.textMuted, letterSpacing: 0.5)),
      ]),
    );
  }
}