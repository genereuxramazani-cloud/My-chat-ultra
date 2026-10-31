import 'package:flutter/material.dart';
import 'services/theme_service.dart';

// ═══════════════════════════════════════
//   PALETTE FUTURISTE — MY CHAT ULTRA
// ═══════════════════════════════════════
const Color kWhite = Colors.white; // Blanc
const Color kBlack = Colors.black; // Noir
const Color kBg = Color(0xFF0A0A0F);
const Color kSurface = Color(0xFF12121A);
const Color kCard = Color(0xFF1A1A25);
const Color kCyan = Color(0xFF06B6D4);
const Color kViolet = Color(0xFF7C3AED);
const Color kPink = Color(0xFFFF2D78);
const Color kGold = Color(0xFFFFD700);
const Color kText = Colors.white;
const Color kTextDim = Color(0xFF6B7280);

// ═══════════════════════════════════════
// TYPOGRAPHY
// ═══════════════════════════════════════

TextStyle kTextHeadline = TextStyle(
  color: kText,
  fontSize: 15,
  fontWeight: FontWeight.w700,
);

TextStyle kTextCaption = TextStyle(
  color: kText,
  fontSize: 13,
  fontWeight: FontWeight.w500,
);

TextStyle kTextMeta = TextStyle(
  color: kTextDim,
  fontSize: 11,
);

// Small helper: use `.v(opacity)` instead of deprecated `.withOpacity()`
extension ColorOpacityHelper on Color {
  Color v(double opacity) => Color.fromRGBO(red, green, blue, opacity);
}

// ═══════════════════════════════════════
//   GRADIENTS
// ═══════════════════════════════════════

const LinearGradient kGradientCyan = LinearGradient(
  colors: [kCyan, kViolet],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient kGradientBg = LinearGradient(
  colors: [kBg, Color.fromRGBO(10, 10, 15, 0.55)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

const LinearGradient kGradientGold = LinearGradient(
  colors: [kGold, Color.fromRGBO(255, 215, 0, 0.8)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient kGradientBlackWhite = LinearGradient(
  colors: [kBlack, kWhite],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ═══════════════════════════════════════
//   THEME PRINCIPAL (Paramétré)
// ═══════════════════════════════════════

ThemeData buildAppTheme({Color? primary, Color? surface}) {
  final p = primary ?? kCyan;
  final s = surface ?? kSurface;
  
  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: kBg,
    primaryColor: p,
    colorScheme: ColorScheme.dark(
      primary: p,
      secondary: kViolet,
      surface: s,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: p,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
      iconTheme: IconThemeData(color: p),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: s,
      selectedItemColor: p,
      unselectedItemColor: kTextDim,
      type: BottomNavigationBarType.fixed,
      elevation: 20,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kCard,
      hintStyle: TextStyle(color: kTextDim),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: p, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Color.fromRGBO(p.red, p.green, p.blue, 0.4), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: p, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.symmetric(vertical: 15),
        textStyle:
            const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    ),
  );
}

// ═══════════════════════════════════════
//   WIDGET : CARTE GLASSMORPHISM
// ═══════════════════════════════════════

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  final double borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.fromRGBO(kCard.red, kCard.green, kCard.blue, 0.6),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Color.fromRGBO((borderColor ?? kCyan).red, (borderColor ?? kCyan).green, (borderColor ?? kCyan).blue, 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO((borderColor ?? kCyan).red, (borderColor ?? kCyan).green, (borderColor ?? kCyan).blue, 0.05),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════
//   WIDGET : BOUTON NÉON
// ═══════════════════════════════════════

class NeonButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;

  NeonButton({
    super.key,
    required this.label,
    required this.onTap,
    Color? color,
    this.icon,
  }) : color = color ?? kCyan;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Color.fromRGBO(color.red, color.green, color.blue, 0.3), blurRadius: 15, spreadRadius: 1),
          ],
          gradient: LinearGradient(
            colors: [Color.fromRGBO(color.red, color.green, color.blue, 0.15), Color.fromRGBO(color.red, color.green, color.blue, 0.05)],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8)
            ],
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
          ],
        ),
      ),
    );
  }
}
