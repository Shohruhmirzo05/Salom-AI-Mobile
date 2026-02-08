import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/core/constants/localization.dart';
import 'package:google_fonts/google_fonts.dart';

Future<Map<String, String>?> showVoiceConfigSheet(
  BuildContext context, {
  required String language,
  required String voice,
  required String role,
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => VoiceConfigView(
      language: language,
      voice: voice,
      role: role,
    ),
  );
}

class VoiceConfigView extends ConsumerStatefulWidget {
  final String language;
  final String voice;
  final String role;

  const VoiceConfigView({
    super.key,
    required this.language,
    required this.voice,
    required this.role,
  });

  @override
  ConsumerState<VoiceConfigView> createState() => _VoiceConfigViewState();
}

class _VoiceConfigViewState extends ConsumerState<VoiceConfigView> {
  late String _language;
  late String _voice;
  late String _role;

  final _languages = [
    {'code': 'uz', 'name': "O'zbekcha"},
    {'code': 'ru', 'name': 'Ruscha'},
    {'code': 'en', 'name': 'Inglizcha'},
  ];

  final _voices = [
    {'code': 'default', 'name': 'Default'},
    {'code': 'male', 'name': 'Erkak'},
    {'code': 'female', 'name': 'Ayol'},
  ];

  final _roles = [
    {'code': 'assistant', 'name': 'Yordamchi'},
    {'code': 'teacher', 'name': "O'qituvchi"},
    {'code': 'friend', 'name': "Do'st"},
  ];

  @override
  void initState() {
    super.initState();
    _language = widget.language;
    _voice = widget.voice;
    _role = widget.role;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            ref.tr('voice_settings'),
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // Language
          _buildSection(ref.tr('language'), _languages, _language, (v) => setState(() => _language = v)),
          const SizedBox(height: 16),

          // Voice
          _buildSection(ref.tr('voice_type'), _voices, _voice, (v) => setState(() => _voice = v)),
          const SizedBox(height: 16),

          // Role
          _buildSection(ref.tr('voice_role'), _roles, _role, (v) => setState(() => _role = v)),
          const SizedBox(height: 24),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'language': _language,
                  'voice': _voice,
                  'role': _role,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(ref.tr('apply')),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<Map<String, String>> options,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((opt) {
            final isSelected = opt['code'] == selected;
            return ChoiceChip(
              label: Text(opt['name']!),
              selected: isSelected,
              onSelected: (_) => onChanged(opt['code']!),
              selectedColor: AppTheme.accentPrimary,
              backgroundColor: Colors.white.withOpacity(0.08),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
