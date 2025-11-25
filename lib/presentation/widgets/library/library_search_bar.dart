import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/song_provider.dart';

/// Widget that provides search functionality for the library
class LibrarySearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool showClearButton;

  const LibrarySearchBar({
    Key? key,
    required this.controller,
    this.hintText = 'Search songs...',
    this.showClearButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        return TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: showClearButton && controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      provider.searchSongs('');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          onChanged: (value) {
            provider.searchSongs(value);
          },
        );
      },
    );
  }
}
