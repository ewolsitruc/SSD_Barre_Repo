import 'package:flutter/material.dart';

class LabeledTextFormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscureText;

  const LabeledTextFormField({
    super.key,
    required this.label,
    required this.controller,
    this.readOnly = false,
    this.maxLines = 1,
    this.keyboardType,
    this.obscureText = false, // ADD THIS LINE
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        obscureText: obscureText, // ADD THIS LINE
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
