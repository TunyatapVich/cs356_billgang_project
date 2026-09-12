import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class ScreenAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ScreenAppBar({
    super.key,
    required this.title,
    this.backHref,
    this.action,
    this.showBackButton = true,
  });

  final String title;
  final String? backHref;
  final Widget? action;
  final bool showBackButton;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bgLight,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlue),
              onPressed: () {
                if (backHref != null) {
                  context.go(backHref!);
                } else if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/');
                }
              },
            )
          : const SizedBox.shrink(),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        if (action != null)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: action!),
          ),
      ],
    );
  }
}
