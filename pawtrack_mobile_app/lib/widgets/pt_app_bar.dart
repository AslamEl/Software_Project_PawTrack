import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PtAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PtAppBar({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.card,
      title: Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      actions: [if (trailing != null) Padding(padding: const EdgeInsets.only(right: 12), child: trailing)],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
