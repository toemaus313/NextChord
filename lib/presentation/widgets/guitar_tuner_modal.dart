import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio/guitar_tuner_service.dart';
import 'semicircle_tuner_display.dart';
import 'templates/concise_modal_template.dart';
import '../providers/appearance_provider.dart';

/// **Concise Modal Template Implementation** - Guitar Tuner
///
/// This demonstrates how to use the ConciseModalTemplate for consistent,
/// compact modal design across the application.
class GuitarTunerModal extends StatefulWidget {
  const GuitarTunerModal({Key? key}) : super(key: key);

  /// Show the Guitar Tuner modal using the concise template
  static Future<void> show(BuildContext context) {
    final appearanceProvider =
        Provider.of<AppearanceProvider>(context, listen: false);
    return ConciseModalTemplate.showConciseModal<void>(
      context: context,
      barrierDismissible: false,
      appearanceProvider: appearanceProvider,
      child: const GuitarTunerModal(),
    );
  }

  @override
  State<GuitarTunerModal> createState() => _GuitarTunerModalState();
}

class _GuitarTunerModalState extends State<GuitarTunerModal>
    with ConciseModalContentMixin {
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
    if (_isInitializing) {}

    if (_initError != null) {}

    return ChangeNotifierProvider.value(
      value: _tunerService,
      child: Consumer<GuitarTunerService>(
        builder: (context, tunerService, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, tunerService),
              // Make the body scrollable without forcing tight expansion,
              // to avoid RenderFlex layout assertions in constrained dialogs.
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: buildConciseContent(
                    children: addConciseSpacing([
                      _buildTunerDisplay(tunerService),
                      _buildStringSelector(tunerService),
                      _buildControlButtons(tunerService),
                    ]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, GuitarTunerService tunerService) {
    return Row(
      children: [
        // Close button (upper left) - using concise template styling
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
        // Status indicator - preserve unique functionality
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
    // Make the tuner display responsive so it fits on smaller screens
    final screenWidth = MediaQuery.of(context).size.width;
    // Leave some horizontal margin inside the modal; clamp to a sensible max
    final displayWidth = screenWidth.clamp(0, 400).toDouble() - 32;

    return Center(
      child: Column(
        children: [
          // Semicircle tuner display with moving dots
          SemicircleTunerDisplay(
            tuningResult: tunerService.currentResult,
            width: displayWidth,
            height: 110,
          ),
        ],
      ),
    );
  }

  Widget _buildStringSelector(GuitarTunerService tunerService) {
    return Center(
      child: Container(
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
            // Use Wrap instead of Row so string buttons can flow on small screens
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 8,
              runSpacing: 8,
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
                    mainAxisSize: MainAxisSize.min,
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
