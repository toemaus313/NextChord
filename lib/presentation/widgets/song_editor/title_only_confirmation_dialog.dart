import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/song_metadata_service.dart';

/// Dialog for confirming title-only metadata lookup results
class TitleOnlyConfirmationDialog extends StatelessWidget {
  final SongMetadataLookupResult result;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const TitleOnlyConfirmationDialog({
    super.key,
    required this.result,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 650),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0468cc),
              Color.fromARGB(150, 3, 73, 153),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildContent(),
              ),
            ),

            // Buttons
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.24),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.music_note,
            color: Colors.white.withOpacity(0.9),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Confirm Song Information',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Description
        Text(
          'We found this song based on your title search. Please confirm if this is the correct song:',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 24),

        // Song details card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Title', result.correctedTitle ?? 'Unknown'),
              const SizedBox(height: 12),
              _buildDetailRow('Artist', result.correctedArtist ?? 'Unknown'),
              const SizedBox(height: 12),
              _buildDetailRow('Tempo', '${result.tempoBpm ?? 'Unknown'} BPM'),
              const SizedBox(height: 12),
              _buildDetailRow('Key', result.key ?? 'Unknown'),
              const SizedBox(height: 12),
              _buildDetailRow(
                  'Time Signature', result.timeSignature ?? 'Unknown'),
              const SizedBox(height: 12),
              _buildDetailRow('Source', result.source ?? 'Unknown'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Note about duration
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.blue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue.withOpacity(0.9),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Duration will be fetched after confirmation',
                  style: TextStyle(
                    color: Colors.blue.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.24),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Reject button
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: TextButton(
                onPressed: onReject,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white.withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  'Reject',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Accept button
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.8),
                    Colors.green.withOpacity(0.6),
                  ],
                ),
              ),
              child: TextButton(
                onPressed: onAccept,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  'Accept',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show the confirmation dialog
  static Future<bool> show({
    required BuildContext context,
    required SongMetadataLookupResult result,
  }) async {
    final completer = Completer<bool>();

    final title = result.correctedTitle ?? 'Unknown';
    final artist = result.correctedArtist ?? 'Unknown';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TitleOnlyConfirmationDialog(
        result: result,
        onAccept: () {
          Navigator.of(context).pop();
          completer.complete(true);
        },
        onReject: () {
          Navigator.of(context).pop();
          completer.complete(false);
        },
      ),
    );

    return completer.future;
  }
}
