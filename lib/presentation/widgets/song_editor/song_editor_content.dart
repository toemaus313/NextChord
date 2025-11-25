import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Main content editor for the song editor screen
///
/// Handles the large text input area with gesture support for zoom,
/// auto-completion, validation, and ChordPro text editing.
class SongEditorContent extends StatelessWidget {
  final TextEditingController bodyController;
  final FocusNode bodyFocusNode;
  final double editorFontSize;
  final Color textColor;
  final String? Function(String?) validator;
  final VoidCallback? onScaleStart;
  final Function(PointerScrollEvent)? onScrollWheelZoom;
  final Function(ScaleUpdateDetails)? onPinchToZoom;
  final bool Function()? shouldHandleTextSizingGesture;

  const SongEditorContent({
    Key? key,
    required this.bodyController,
    required this.bodyFocusNode,
    required this.editorFontSize,
    required this.textColor,
    required this.validator,
    this.onScaleStart,
    this.onScrollWheelZoom,
    this.onPinchToZoom,
    this.shouldHandleTextSizingGesture,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent &&
                (shouldHandleTextSizingGesture?.call() ?? false)) {
              onScrollWheelZoom?.call(event);
            }
          },
          child: GestureDetector(
            onScaleStart: (_) => onScaleStart?.call(),
            onScaleUpdate: (details) {
              if (shouldHandleTextSizingGesture?.call() ?? false) {
                onPinchToZoom?.call(details);
              }
            },
            child: TextFormField(
              controller: bodyController,
              focusNode: bodyFocusNode,
              style: TextStyle(
                fontSize: editorFontSize,
                fontFamily: 'monospace',
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText:
                    '[C]Amazing [G]grace, how [Am]sweet the [F]sound\n[C]That saved a [G]wretch like [C]me',
                hintStyle: TextStyle(
                  fontSize: editorFontSize - 1,
                  color: textColor.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              textCapitalization: TextCapitalization.sentences,
              validator: validator,
            ),
          ),
        ),
      ),
    );
  }
}
