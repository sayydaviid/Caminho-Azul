import 'package:flutter/material.dart';

class CustomInput extends StatelessWidget {
  const CustomInput({
    required this.label,
    this.hint,
    this.controller,
    this.icon,
    this.suffixIcon,
    this.onSuffixPressed,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType,
    super.key,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final IconData? icon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixPressed;
  final bool obscureText;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon, size: 19),
            suffixIcon: suffixIcon == null
                ? null
                : IconButton(
                    onPressed: onSuffixPressed,
                    icon: Icon(suffixIcon, size: 19),
                  ),
          ),
        ),
      ],
    );
  }
}
