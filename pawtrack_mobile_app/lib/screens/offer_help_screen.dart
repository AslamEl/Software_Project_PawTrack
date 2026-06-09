import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/toast.dart';

class OfferHelpScreen extends StatefulWidget {
  const OfferHelpScreen({super.key});

  @override
  State<OfferHelpScreen> createState() => _OfferHelpScreenState();
}

class _OfferHelpScreenState extends State<OfferHelpScreen> {
  final Set<String> _selectedTypes = {};
  DateTime? _availableDate;
  TimeOfDay? _availableTime;
  final _notesController = TextEditingController();
  bool _submitting = false;

  static const _helpTypes = [
    _HelpType('Feed', Icons.restaurant_rounded, Color(0xFFF58A1F)),
    _HelpType('Temporary Shelter', Icons.home_rounded, Color(0xFF2196F3)),
    _HelpType('Adoption', Icons.favorite_rounded, Color(0xFFE91E63)),
    _HelpType('Veterinary', Icons.medical_services_rounded, Color(0xFFE53935)),
    _HelpType('Transport', Icons.directions_car_rounded, Color(0xFF9C27B0)),
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.orange),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _availableDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.orange),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _availableTime = picked);
  }

  Future<void> _submit(String docId) async {
    if (_selectedTypes.isEmpty) {
      AppToast.warning(context, 'Please select at least one type of help');
      return;
    }
    setState(() => _submitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      DateTime? availability;
      if (_availableDate != null) {
        final time = _availableTime ?? const TimeOfDay(hour: 9, minute: 0);
        availability = DateTime(
          _availableDate!.year,
          _availableDate!.month,
          _availableDate!.day,
          time.hour,
          time.minute,
        );
      }

      await FirebaseFirestore.instance
          .collection('dog_reports')
          .doc(docId)
          .collection('help_offers')
          .add({
        'offeredBy': uid,
        'type': _selectedTypes.toList(),
        'availability': availability != null ? Timestamp.fromDate(availability) : null,
        'notes': _notesController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        AppToast.success(context, 'Thank you! Your help offer has been submitted.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        AppToast.error(context, 'Failed to submit: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docId = ModalRoute.of(context)!.settings.arguments as String;

    String dateLabel = 'Pick a date';
    if (_availableDate != null) {
      final d = _availableDate!;
      dateLabel = '${d.day}/${d.month}/${d.year}';
    }

    String timeLabel = 'Pick a time';
    if (_availableTime != null) {
      timeLabel = _availableTime!.format(context);
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Offer Help', style: AppTextStyles.headlineMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Help type ──────────────────────────────────────────────────────
            _SectionLabel('How would you like to help?'),
            const SizedBox(height: 4),
            Text('Select all that apply', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _helpTypes.map((t) {
                final selected = _selectedTypes.contains(t.label);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedTypes.remove(t.label);
                    } else {
                      _selectedTypes.add(t.label);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? t.color : AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? t.color : AppColors.border,
                        width: 1.5,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: t.color.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, color: selected ? Colors.white : t.color, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          t.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: selected ? Colors.white : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // ── Availability ───────────────────────────────────────────────────
            _SectionLabel('When are you available?'),
            const SizedBox(height: 4),
            Text('Optional — leave blank if flexible', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PickerButton(
                    icon: Icons.calendar_today_rounded,
                    label: dateLabel,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerButton(
                    icon: Icons.access_time_rounded,
                    label: timeLabel,
                    onTap: _availableDate != null ? _pickTime : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Notes ──────────────────────────────────────────────────────────
            _SectionLabel('Additional Notes'),
            const SizedBox(height: 4),
            Text('Any extra info, contact details, etc.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'I can come by on weekday evenings...',
                hintStyle: TextStyle(color: AppColors.muted.withOpacity(0.6), fontSize: 14),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : () => _submit(docId),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.volunteer_activism_rounded),
                label: Text(
                  _submitting ? 'Submitting…' : 'Submit Help Offer',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.orange.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: enabled ? AppColors.border : AppColors.border.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: enabled ? AppColors.orange : AppColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: enabled ? AppColors.ink : AppColors.muted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpType {
  final String label;
  final IconData icon;
  final Color color;
  const _HelpType(this.label, this.icon, this.color);
}
