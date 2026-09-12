import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

String getShortName(String? name, String? email) {
  final raw = (name != null && name.trim().isNotEmpty)
      ? name.trim()
      : (email != null && email.isNotEmpty)
          ? email.split('@')[0].trim()
          : 'Member';
  final firstWord = raw.split(RegExp(r'\s+'))[0];
  return firstWord;
}

String getInitial(String? name, String? email) {
  final s = getShortName(name, email);
  return s.isNotEmpty ? s[0].toUpperCase() : 'M';
}

enum AvatarSize {
  tiny(22, 10),
  small(30, 12),
  normal(40, 15),
  large(88, 28);

  final double dimension;
  final double fontSize;
  const AvatarSize(this.dimension, this.fontSize);
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.name,
    this.email,
    this.avatarUrl,
    this.size = AvatarSize.normal,
    this.borderColor,
    this.borderWidth = 0,
  });

  final String? name;
  final String? email;
  final String? avatarUrl;
  final AvatarSize size;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final hasUrl = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    final initial = getInitial(name, email);

    Widget inner;
    if (hasUrl) {
      inner = Image.network(
        avatarUrl!,
        width: size.dimension,
        height: size.dimension,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallback(initial),
      );
    } else {
      inner = _fallback(initial);
    }

    return Container(
      width: size.dimension,
      height: size.dimension,
      decoration: BoxDecoration(
        color: AppColors.dimBlue,
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(
                color: borderColor ?? Colors.white,
                width: borderWidth,
              )
            : null,
      ),
      child: ClipOval(child: inner),
    );
  }

  Widget _fallback(String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.primaryBlue,
          fontSize: size.fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class AvatarStackItem {
  final String? name;
  final String? email;
  final String? avatarUrl;

  const AvatarStackItem({this.name, this.email, this.avatarUrl});
}

class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.users,
    this.max = 4,
    this.size = AvatarSize.tiny,
  });

  final List<AvatarStackItem> users;
  final int max;
  final AvatarSize size;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();

    final shown = users.take(max).toList();
    final extra = users.length - shown.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < shown.length; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
            child: UserAvatar(
              name: shown[i].name,
              email: shown[i].email,
              avatarUrl: shown[i].avatarUrl,
              size: size,
              borderWidth: 1.5,
              borderColor: Colors.white,
            ),
          ),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Container(
              height: size.dimension,
              constraints: BoxConstraints(minWidth: size.dimension),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(size.dimension / 2),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                '+$extra',
                style: const TextStyle(
                  color: AppColors.textGray,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
