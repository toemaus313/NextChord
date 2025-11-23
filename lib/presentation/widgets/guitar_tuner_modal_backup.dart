import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio/guitar_tuner_service.dart';
import 'semicircle_tuner_display.dart';

/// Modal-style dialog for guitar tuning with semicircle dot display
///
/// **App Modal Design Standard**:
/// - maxWidth: 480, maxHeight: 650 (constrained dialog)
/// - Gradient: Color(0xFF0468cc) to Color.fromARGB(150, 3, 73, 153)
/// - Border radius: 22, Shadow: blurRadius 20, offset (0, 10)
/// - Text: Primary white, secondary white70, borders white24
/// - Buttons: Rounded borders (999), padding (21, 11), fontSize 14
/// - Spacing: 8px between sections, 16px padding
class GuitarTunerModal extends StatefulWidget {
  const GuitarTunerModal({Key? key}) : super(key: key);

  /// Show the Guitar Tuner modal
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: const GuitarTunerModal(),
      ),
    );
  }

  @override
  State<GuitarTunerModal> createState() => _GuitarTunerModalState();
}

class _GuitarTunerModalState extends State<GuitarTunerModal> {
  late final GuitarTunerService _tunerService;
  bool _isInitializing = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _tunerService = GuitarTunerService();
    _initializeTuner();
  }

  @override
  void dispose() {
    _tunerService.stopListening();
    super.dispose();
  }

  Future<void> _initializeTuner() async {
    try {
      final success = await _tunerService.initialize();

      if (mounted) {
        setState(() {
          _isInitializing = false;
          if (!success) {
            _initError =
                _tunerService.errorMessage ?? 'Failed to initialize tuner';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = 'Initialization error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return _buildLoadingDialog();
    }

    if (_initError != null) {
      return _buildErrorDialog();
    }

    return ChangeNotifierProvider.value(
      value: _tunerService,
      child: Consumer<GuitarTunerService>(
        builder: (context, tunerService, child) {
          return Center(
            child: ConstrainedBox(
              // App Modal Design Standard: Constrained dialog size
              constraints: const BoxConstraints(
                maxWidth: 480,
                minWidth: 320,
                maxHeight: 650,
              ),
              child: Container(
                decoration: BoxDecoration(
                  // App Modal Design Standard: Gradient background
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0468cc),
                      Color.fromARGB(150, 3, 73, 153)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(100),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                // App Modal Design Standard: Consistent padding
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(context, tunerService),
                    const SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTunerDisplay(tunerService),
                            const SizedBox(height: 16),
                            _buildStringSelector(tunerService),
                            const SizedBox(height: 16),
                            _buildControlButtons(tunerService),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingDialog() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0468cc), Color.fromARGB(150, 3, 73, 153)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Initializing Tuner...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorDialog() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0468cc), Color.fromARGB(150, 3, 73, 153)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tuner Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _initError!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
              child: const Text('Close', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, GuitarTunerService tunerService) {
    return Row(
      children: [
        // Close button (upper left)
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: const BorderSide(color: Colors.white24),
            ),
          ),
          child: const Text('Close', style: TextStyle(fontSize: 14)),
        ),
        const Spacer(),
        const Text(
          'Guitar Tuner',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        // Status indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(tunerService),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _getStatusText(tunerService),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTunerDisplay(GuitarTunerService tunerService) {
    return Column(
      children: [
        // Semicircle tuner display with moving dots
        SemicircleTunerDisplay(
          tuningResult: tunerService.currentResult,
          width: 400,
          height: 120,
        ),
      ],
    );
  }

  Widget _buildStringSelector(GuitarTunerService tunerService) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Standard Tuning',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: GuitarTunerService.standardTuning.map((string) {
              final isActive =
                  tunerService.currentResult?.closestString?.stringNumber ==
                      string.stringNumber;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? Colors.white : Colors.white24,
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      string.name,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${string.frequency.toStringAsFixed(1)}Hz',
                      style: TextStyle(
                        color: isActive ? Colors.white70 : Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(GuitarTunerService tunerService) {
    // Check if permissions are granted
    final canStart = tunerService.hasPermission;

    return Column(
      children: [
        // Error message if no microphone or permission issues
        if (tunerService.errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withAlpha(100)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tunerService.errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Start/Stop button
            TextButton.icon(
              onPressed: canStart
                  ? (tunerService.isListening
                      ? () => tunerService.stopListening()
                      : () => tunerService.startListening())
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: canStart ? Colors.white : Colors.white38,
                padding:
                    const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: canStart ? Colors.white24 : Colors.white12,
                  ),
                ),
              ),
              icon: Icon(
                tunerService.isListening ? Icons.stop : Icons.play_arrow,
                size: 18,
              ),
              label: Text(
                tunerService.isListening ? 'Stop' : 'Start',
                style: const TextStyle(fontSize: 14),
              ),
            ),

            // Permission button (if no permission)
            if (!tunerService.hasPermission)
              TextButton.icon(
                onPressed: () => tunerService.initialize(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
                icon: const Icon(Icons.mic, size: 18),
                label: const Text('Allow Microphone',
                    style: TextStyle(fontSize: 14)),
              ),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(GuitarTunerService tunerService) {
    if (!tunerService.hasPermission) return Colors.red;
    if (tunerService.isListening) return Colors.green;
    return Colors.orange;
  }

  String _getStatusText(GuitarTunerService tunerService) {
    if (!tunerService.hasPermission) return 'No Permission';
    if (tunerService.isListening) return 'Listening';
    return 'Ready';
  }
}
