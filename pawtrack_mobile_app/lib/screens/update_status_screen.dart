import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/toast.dart';

const _cloudinaryCloudName = 'dforjdpi8';
const _cloudinaryUploadPreset = 'pawtrack_unsigned';

class UpdateStatusScreen extends StatefulWidget {
  const UpdateStatusScreen({super.key});

  @override
  State<UpdateStatusScreen> createState() => _UpdateStatusScreenState();
}

class _UpdateStatusScreenState extends State<UpdateStatusScreen> {
  final Set<String> _selectedStatuses = {};
  final _messageController = TextEditingController();
  XFile? _photo;
  bool _submitting = false;

  static const _statuses = [
    'Hungry',
    'Injured',
    'Needs Rescue',
    'Stray',
    'Friendly',
    'Rescued',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) setState(() => _photo = picked);
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.orange),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.orange),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              if (_photo != null)
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: Color(0xFFE53935)),
                  title: const Text('Remove Photo', style: TextStyle(color: Color(0xFFE53935))),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _photo = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _uploadPhoto() async {
    if (_photo == null) return null;
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', _photo!.path));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (response.statusCode == 200) return json['secure_url'] as String;
    throw Exception('Photo upload failed: ${json['error']?['message'] ?? body}');
  }

  Future<void> _submit(String docId) async {
    if (_selectedStatuses.isEmpty) {
      AppToast.warning(context, 'Please select at least one status');
      return;
    }
    setState(() => _submitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String? photoUrl;
      if (_photo != null) {
        photoUrl = await _uploadPhoto();
      }

      final batch = FirebaseFirestore.instance.batch();
      final reportRef = FirebaseFirestore.instance.collection('dog_reports').doc(docId);
      final updateRef = reportRef.collection('status_updates').doc();

      batch.set(updateRef, {
        'updatedBy': uid,
        'newStatus': _selectedStatuses.first,
        'allStatuses': _selectedStatuses.toList(),
        'message': _messageController.text.trim(),
        'photoUrl': photoUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      batch.update(reportRef, {
        'status': _selectedStatuses.toList(),
        'isActive': !_selectedStatuses.contains('Rescued'),
      });

      await batch.commit();

      if (mounted) {
        AppToast.success(context, 'Status updated successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        AppToast.error(context, 'Failed to update: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docId = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Update Status', style: AppTextStyles.headlineMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status chips ───────────────────────────────────────────────────
            _SectionLabel('New Status'),
            const SizedBox(height: 4),
            Text('What is this dog\'s current situation?',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _statuses.map((s) {
                final selected = _selectedStatuses.contains(s);
                final isRescued = s == 'Rescued';
                final activeColor = isRescued ? const Color(0xFF43A047) : AppColors.orange;
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
                      color: selected ? activeColor : AppColors.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected ? activeColor : AppColors.border,
                        width: 1.5,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: activeColor.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
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

            // ── Update message ─────────────────────────────────────────────────
            _SectionLabel('Update Message'),
            const SizedBox(height: 4),
            Text('What has changed? Any observations?',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'The dog has been fed and is now resting near...',
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
            const SizedBox(height: 32),

            // ── Optional photo ─────────────────────────────────────────────────
            _SectionLabel('Update Photo'),
            const SizedBox(height: 4),
            Text('Optional — add a current photo of the dog',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _showPhotoOptions,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: _photo != null ? 180 : 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _photo != null ? AppColors.orange : AppColors.border,
                    width: _photo != null ? 1.5 : 1,
                    style: _photo != null ? BorderStyle.solid : BorderStyle.solid,
                  ),
                ),
                child: _photo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(_photo!.path), fit: BoxFit.cover),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(Icons.edit_rounded,
                                      color: Colors.white, size: 16),
                                  onPressed: _showPhotoOptions,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_rounded,
                              color: AppColors.muted, size: 28),
                          const SizedBox(height: 6),
                          Text('Tap to add photo',
                              style: TextStyle(color: AppColors.muted, fontSize: 13)),
                        ],
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
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _submitting ? 'Saving…' : 'Save Update',
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
