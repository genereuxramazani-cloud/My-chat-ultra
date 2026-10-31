import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

class GlassAddButton extends StatelessWidget {
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double size;
  final double iconSize;
  final bool busy;
  final List<Color> colors;
  final Color borderColor;

  const GlassAddButton({
    super.key,
    required this.onTap,
    this.padding = EdgeInsets.zero,
    this.size = 52,
    this.iconSize = 20,
    this.busy = false,
    this.colors = const [kViolet, kPink],
    this.borderColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnTap = busy ? null : onTap;
    return Padding(
      padding: padding,
      child: GestureDetector(
        onTap: effectiveOnTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.20),
                    colors.first.withOpacity(0.35),
                    colors.last.withOpacity(0.28),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: borderColor.withOpacity(0.28),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: colors.first.withOpacity(0.16),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: busy
                    ? SizedBox(
                        width: iconSize,
                        height: iconSize,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Container(
                        width: size * 0.46,
                        height: size * 0.46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.14),
                        ),
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: iconSize,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}