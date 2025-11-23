import 'package:flutter/material.dart';

/// Input field for MIDI profile name
class ProfileNameInput extends StatelessWidget {
  final TextEditingController nameController;

  const ProfileNameInput({
    super.key,
    required this.nameController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const Text(
            'Name:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.9, // Reduced by 15% from 14
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: nameController,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.9), // Reduced by 15% from 14
              decoration: InputDecoration(
                hintText: 'Enter profile name',
                hintStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
