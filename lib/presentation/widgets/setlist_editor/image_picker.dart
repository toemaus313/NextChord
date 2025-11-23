import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Image picker and display component for setlist covers
class SetlistImagePicker extends StatelessWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  final bool isLoading;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;

  const SetlistImagePicker({
    super.key,
    this.imagePath,
    this.imageBytes,
    required this.isLoading,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cover Image',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Image preview
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withAlpha(20)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildImage(),
                ),
              ),
              const SizedBox(width: 16),
              // Image controls
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add a cover image for your setlist',
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recommended: 200x200px',
                      style: TextStyle(
                        color: Colors.white.withAlpha(120),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (imagePath != null && imageBytes != null) ...[
                          // Remove button
                          OutlinedButton.icon(
                            onPressed: isLoading ? null : onRemoveImage,
                            icon: const Icon(Icons.delete, size: 16),
                            label: const Text('Remove'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.withAlpha(200),
                              side:
                                  BorderSide(color: Colors.red.withAlpha(100)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Pick button
                        ElevatedButton.icon(
                          onPressed: isLoading ? null : onPickImage,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.photo_library, size: 16),
                          label: Text(imagePath != null ? 'Change' : 'Add'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withAlpha(20),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white38),
        ),
      );
    }

    if (imageBytes != null) {
      return Image.memory(
        imageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
      );
    }

    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withAlpha(10),
            Colors.white.withAlpha(5),
          ],
        ),
      ),
      child: const Icon(
        Icons.image,
        size: 32,
        color: Colors.white38,
      ),
    );
  }
}

/// Dialog for cropping and editing images
class ImageEditDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const ImageEditDialog({super.key, required this.imageBytes});

  @override
  State<ImageEditDialog> createState() => _ImageEditDialogState();
}

class _ImageEditDialogState extends State<ImageEditDialog> {
  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0468cc),
              Color.fromARGB(150, 3, 73, 153),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Image',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            // Image preview
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withAlpha(20)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(_getColorMatrix()),
                    child: Image.memory(
                      widget.imageBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            // Controls
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSlider('Brightness', _brightness, (value) {
                    setState(() => _brightness = value);
                  }),
                  const SizedBox(height: 8),
                  _buildSlider('Contrast', _contrast, (value) {
                    setState(() => _contrast = value);
                  }),
                  const SizedBox(height: 8),
                  _buildSlider('Saturation', _saturation, (value) {
                    setState(() => _saturation = value);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(
      String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: -1,
            max: 1,
            divisions: 20,
            onChanged: onChanged,
            activeColor: Colors.white,
            inactiveColor: Colors.white.withAlpha(50),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  List<double> _getColorMatrix() {
    return [
      1 + _contrast,
      0,
      0,
      0,
      _brightness * 255,
      0,
      1 + _contrast,
      0,
      0,
      _brightness * 255,
      0,
      0,
      1 + _contrast,
      0,
      _brightness * 255,
      0,
      0,
      0,
      1 + _saturation,
      0,
    ];
  }
}
