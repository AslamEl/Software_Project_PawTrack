import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../routes/app_routes.dart';
import '../utils/toast.dart';

// Replace with your Cloudinary cloud name and unsigned upload preset
const _cloudinaryCloudName = 'dforjdpi8';
const _cloudinaryUploadPreset = 'pawtrack_unsigned';

class StatusTaggingScreen extends StatefulWidget {
  final XFile photo;
  final String dogName;
  final String notes;
  final LatLng location;

  const StatusTaggingScreen({
    super.key,
    required this.photo,
    required this.dogName,
    required this.notes,
    required this.location,
  });

  @override
  State<StatusTaggingScreen> createState() => _StatusTaggingScreenState();
}

class _StatusTaggingScreenState extends State<StatusTaggingScreen> {
  final Set<String> _selectedStatuses = {};
  String _urgency = 'low';
  bool _submitting = false;

  static const _statuses = [
    'Hungry',
    'Injured',
    'Needs Rescue',
    'Stray',
    'Friendly',
  ];

  static const _urgencies = [
    _Urgency('low', 'Low', Color(0xFF4CAF50)),
    _Urgency('medium', 'Medium', AppColors.orange),
    _Urgency('high', 'High', Color(0xFFE53935)),
  ];

  Future<String> _uploadToCloudinary() async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', widget.photo.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return json['secure_url'] as String;
    }
    throw Exception('Photo upload failed: ${json['error']?['message'] ?? body}');
  }

  Future<void> _submit() async {
    if (_selectedStatuses.isEmpty) {
      AppToast.warning(context, 'Please select at least one status');
      return;
    }
    setState(() => _submitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Write to Firestore immediately — photo uploads in background
      final Map<String, dynamic> data = {
        'reportedBy': uid,
        'timestamp': FieldValue.serverTimestamp(),
        'location': GeoPoint(widget.location.latitude, widget.location.longitude),
        'photoUrl': null,
        'notes': widget.notes,
        'status': _selectedStatuses.toList(),
        'urgency': _urgency,
        'isActive': true,
      };
      if (widget.dogName.isNotEmpty) data['dogName'] = widget.dogName;

      final docRef =
          await FirebaseFirestore.instance.collection('dog_reports').add(data);

      // Navigate to confirmed screen right away
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.reportConfirmed,
          ModalRoute.withName(AppRoutes.home),
        );
      }

      // Upload photo in background and patch the document
      _uploadAndPatch(docRef.id);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        AppToast.error(context, 'Failed to submit: $e');
      }
    }
  }

  Future<void> _uploadAndPatch(String docId) async {
    try {
      final photoUrl = await _uploadToCloudinary();
      await FirebaseFirestore.instance
          .collection('dog_reports')
          .doc(docId)
          .update({'photoUrl': photoUrl});
    } catch (_) {
      // Report exists without photo — silent fail
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Tag Status', style: AppTextStyles.headlineMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step indicator
            _StepIndicator(step: 2, total: 2),
            const SizedBox(height: 24),

            const Text(
              'What best describes this dog?',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select all that apply',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _statuses.map((s) {
                final selected = _selectedStatuses.contains(s);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedStatuses.remove(s);
                    } else {
                      _selectedStatuses.add(s);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.orange : AppColors.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected ? AppColors.orange : AppColors.border,
                        width: 1.5,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: AppColors.orange.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          s,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : AppColors.ink,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            const Text(
              'Urgency Level',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'How urgently does this dog need help?',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: _urgencies.map((u) {
                final selected = _urgency == u.value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _urgency = u.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected ? u.color : AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? u.color : AppColors.border,
                          width: 1.5,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(color: u.color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                            : [],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.flag_rounded,
                            color: selected ? Colors.white : u.color,
                            size: 22,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            u.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : u.color,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.orange.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Submit Report',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Urgency {
  final String value;
  final String label;
  final Color color;
  const _Urgency(this.value, this.label, this.color);
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: active ? AppColors.orange : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
