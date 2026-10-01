// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../services/app_background_service.dart';
import '../../../widgets/app_background_layer.dart';

class EditBackgroundDemoPage extends StatefulWidget {
  const EditBackgroundDemoPage({super.key});

  @override
  State<EditBackgroundDemoPage> createState() => _EditBackgroundDemoPageState();
}

class _EditBackgroundDemoPageState extends State<EditBackgroundDemoPage>
    with SingleTickerProviderStateMixin {
  final AppBackgroundService _backgroundService = AppBackgroundService.instance;
  double _opacity = 0.3;
  double _blur = 0.0;
  Color _primaryColor = const Color(0xFFFF9D2E);
  String? _selectedImagePath;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
    _loadSettings();
    _backgroundService.addListener(_handleBackgroundChanged);
  }

  @override
  void dispose() {
    _backgroundService.removeListener(_handleBackgroundChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _handleBackgroundChanged() {
    if (!mounted) return;
    setState(() {
      if (_selectedImagePath == null || _selectedImagePath!.isEmpty) {
        _selectedImagePath = _backgroundService.backgroundFile?.path;
      }
      _opacity = _backgroundService.opacity;
      _blur = _backgroundService.blur;
      _primaryColor = _backgroundService.accentColor;
    });
  }

  Future<void> _loadSettings() async {
    await _backgroundService.initialize();
    _handleBackgroundChanged();
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final sourceFile = File(pickedFile.path);
    if (!sourceFile.existsSync()) return;

    final directory = await getApplicationDocumentsDirectory();
    await directory.create(recursive: true);

    final extension = p.extension(sourceFile.path);
    final previewPath = p.join(
      directory.path,
      'background_preview${extension.isEmpty ? '.png' : extension}',
    );
    final previewFile = File(previewPath);
    if (previewFile.existsSync()) {
      await previewFile.delete();
    }
    await sourceFile.copy(previewPath);

    if (!mounted) return;

    setState(() {
      _selectedImagePath = previewPath;
    });
  }

  Future<void> _saveBackground() async {
    await _backgroundService.saveSettings(
      imagePath: _selectedImagePath,
      opacity: _opacity,
      blur: _blur,
      accentColor: _primaryColor,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الخلفية بنجاح ✅')),
    );
    Navigator.pop(context);
  }

  Future<void> _removeBackground() async {
    await _backgroundService.removeBackground();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إزالة الخلفية المخصصة')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final previewImagePath =
        _selectedImagePath ?? _backgroundService.backgroundFile?.path;
    final previewFile = previewImagePath != null && previewImagePath.isNotEmpty
        ? File(previewImagePath)
        : null;
    final previewKey = previewFile != null && previewFile.existsSync()
        ? ValueKey(
            '${previewFile.path}:${previewFile.lastModifiedSync().microsecondsSinceEpoch}',
          )
        : const ValueKey('empty-preview');

    return AppBackgroundLayer(
      overrideBackgroundFile: previewFile,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('تخصيص الخلفية'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new),
          ),
        ),
        body: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickImage,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                      gradient: LinearGradient(
                        colors: isDark
                            ? [Colors.black87, Colors.black54]
                            : [Colors.grey[300]!, Colors.grey[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child:
                                previewFile != null && previewFile.existsSync()
                                    ? SizedBox.expand(
                                        key: previewKey,
                                        child: Image.file(
                                          previewFile,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const SizedBox.expand(
                                        key: ValueKey('empty-preview'),
                                        child: ColoredBox(
                                          color: Colors.transparent,
                                        ),
                                      ),
                          ),
                          BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: _blur,
                              sigmaY: _blur,
                            ),
                            child: Container(
                              color: Colors.black.withOpacity(_opacity),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'معاينة الخلفية',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    previewFile == null ||
                                            !previewFile.existsSync()
                                        ? 'اختر صورة لتطبيقها كخلفية'
                                        : 'تم اختيار صورة بنجاح',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildSliderRow('الشفافية', _opacity, (v) {
                      setState(() => _opacity = v);
                    }),
                    const SizedBox(height: 12),
                    _buildSliderRow('التمويه', _blur / 20, (v) {
                      setState(() => _blur = v * 20);
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildControlButton(
                      label: 'حفظ',
                      color: _primaryColor,
                      onPressed: _saveBackground,
                    ),
                    _buildControlButton(
                      label: 'إزالة',
                      color: Colors.grey.shade700,
                      onPressed: _removeBackground,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    Function(double) onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          flex: 5,
          child: Slider(
            value: value,
            onChanged: onChanged,
            min: 0,
            max: 1,
            activeColor: _primaryColor,
          ),
        ),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text('${(value * 100).toInt()}%'),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Text(label),
    );
  }
}
