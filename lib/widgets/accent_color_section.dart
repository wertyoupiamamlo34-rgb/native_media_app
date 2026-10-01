// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AccentColorSection extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onChanged;
  final Color accent;
  final String title;
  final IconData icon;
  final String description;
  final bool showDescription;
  final List<Color> palette;

  static const paletteColors = [
    Color(0xFF8B3DFF),
    Color(0xFF287BFF),
    Color(0xFF20D9C9),
    Color(0xFFFF3D91),
    Color(0xFFFF3D45),
    Color(0xFFFF9D2E),
  ];

  const AccentColorSection({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.accent,
    this.title = 'اختر اللون المفضل',
    this.icon = Icons.palette_outlined,
    this.description =
        'سيتم تطبيق هذا اللون على الأزرار والعناوين وشريط التقدم \n يمكنك تغييره لاحقاً من الإعدادات',
    this.showDescription = true,
    this.palette = paletteColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.titleMedium?.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: palette.map((color) {
              final isSelected = color.value == selected.value;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(color);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  width: isSelected ? 44 : 40,
                  height: isSelected ? 44 : 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.06),
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.55),
                              blurRadius: 18,
                              spreadRadius: 1,
                            )
                          ]
                        : [
                            BoxShadow(
                              color: color.withOpacity(0.18),
                              blurRadius: 8,
                            )
                          ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          if (showDescription) ...[
            const SizedBox(height: 14),
            Text(
              description,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color ??
                    Colors.white60,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
