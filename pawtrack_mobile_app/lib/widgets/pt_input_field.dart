import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PtInputField extends StatelessWidget {
  const PtInputField({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.obscureText = false,
  });

  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(hintText: hintText),
        ),
      ],
    );
  }
}
