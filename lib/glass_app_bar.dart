// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class GlassAppBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String image;
  final Function onTap;
  final Function onPressed;
  final List<Widget>? actions;

  const GlassAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actions,
    required this.onTap,
    required this.image,
    required this.onPressed,
    // required String imaage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.only(top: 15, left: 15, right: 15),
      child: Row(
        children: [
          // أيقونة رئيسية
          GestureDetector(
            onTap: () => onTap(),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Image.asset(image, width: 33),
              ),
            ),
          ),
          // Text(title),
          const SizedBox(width: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                  isDark
                      ? 'assets/images/sonva_w.png'
                      : 'assets/images/sonva_b.png',
                  width: 80),
              Text(
                subtitle,
                style: TextStyle(
                    color: isDark ? primaryColor : Colors.black87,
                    fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => onPressed(),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Icon(icon, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= Icon Button Reusable =================
Widget imageLogo(
  String imaage,
  ThemeData theme,
  bool isDark, {
  VoidCallback? onTap,
}) {
  return Material(
    color: isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.05),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap ?? () {},
      child: SizedBox(
        width: 44,
        height: 44,
        child: Image.asset('assets/images/Circle.png', width: 80),
      ),
    ),
  );
}
