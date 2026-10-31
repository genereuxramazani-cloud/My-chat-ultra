import 'package:flutter/material.dart';
import '../theme.dart';

/// Widget réutilisable pour afficher la photo de profil de l'utilisateur
/// avec fallback aux initiales si pas de photo
class UserAvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String identifier; // phone or name
  final double size;
  final Color? borderColor;
  final double borderWidth;
  final Animation<double>? pulseAnimation;
  final VoidCallback? onTap;
  final bool showBorder;

  const UserAvatarWidget({
    super.key,
    this.avatarUrl,
    required this.identifier,
    this.size = 40,
    this.borderColor,
    this.borderWidth = 1.5,
    this.pulseAnimation,
    this.onTap,
    this.showBorder = false,
  });

  String _getInitials() {
    if (identifier.isEmpty) return '?';
    return identifier[0].toUpperCase();
  }

  Color _getBackgroundColor() {
    // Génère une couleur basée sur le hash de l'identifiant
    final hash = identifier.hashCode.abs();
    final colors = [kCyan, kViolet, kGold, kPink];
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = borderColor ?? _getBackgroundColor();

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getBackgroundColor().withOpacity(0.2),
        border: showBorder || borderColor != null
            ? Border.all(
                color: color,
                width: borderWidth,
              )
            : null,
      ),
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildInitialsFallback(color);
                },
              ),
            )
          : _buildInitialsFallback(color),
    );

    // Si pulseAnimation est fournie, on l'applique
    if (pulseAnimation != null) {
      avatar = AnimatedBuilder(
        animation: pulseAnimation!,
        builder: (_, __) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(pulseAnimation!.value),
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(pulseAnimation!.value * 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildInitialsFallback(color);
                    },
                  ),
                )
              : _buildInitialsFallback(color),
        ),
      );
    }

    // Si onTap est fourni, on ajoute GestureDetector
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildInitialsFallback(Color color) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
      ),
      child: Center(
        child: Text(
          _getInitials(),
          style: TextStyle(
            color: color,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
