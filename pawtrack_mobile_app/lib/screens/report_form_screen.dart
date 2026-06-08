import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'status_tagging_screen.dart';

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  XFile? _photo;
  final _dogNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  LatLng? _location;
  bool _loadingLocation = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _dogNameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _loadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _loadingLocation = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _loadingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _location = LatLng(pos.latitude, pos.longitude);
          _loadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file != null) setState(() => _photo = file);
  }

  void _showPhotoPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _next() {
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a photo of the dog')),
      );
      return;
    }
    if (_location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for location. Please try again in a moment.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusTaggingScreen(
          photo: _photo!,
          dogName: _dogNameCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          location: _location!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Report a Dog', style: AppTextStyles.headlineMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label('Photo *'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showPhotoPicker,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: _photo != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(_photo!.path), fit: BoxFit.cover),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _showPhotoPicker,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_rounded,
                            size: 44,
                            color: AppColors.orange.withOpacity(0.6),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tap to add a photo',
                            style: TextStyle(color: AppColors.muted, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Camera or Gallery',
                            style: TextStyle(color: AppColors.muted.withOpacity(0.6), fontSize: 12),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            _Label('Dog Name (optional)'),
            const SizedBox(height: 8),
            _InputField(controller: _dogNameCtrl, hint: 'e.g. Brownie'),
            const SizedBox(height: 20),
            _Label('Notes'),
            const SizedBox(height: 8),
            _InputField(
              controller: _notesCtrl,
              hint: 'Describe the dog\'s condition, behavior, surroundings…',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            _Label('Location'),
            const SizedBox(height: 8),
            if (_loadingLocation)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Getting your location…', style: TextStyle(color: AppColors.muted)),
                  ],
                ),
              )
            else if (_location != null) ...[
              Row(
                children: [
                  const Icon(Icons.my_location_rounded, size: 14, color: AppColors.orange),
                  const SizedBox(width: 6),
                  Text(
                    '${_location!.latitude.toStringAsFixed(5)}, ${_location!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _getLocation,
                    child: const Text(
                      'Refresh',
                      style: TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 180,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _location!,
                      initialZoom: 15,
                      onTap: (_, point) => setState(() => _location = point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.pawtrack.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _location!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: AppColors.orange,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap the map to fine-tune the pin',
                style: TextStyle(color: AppColors.muted.withOpacity(0.7), fontSize: 12),
              ),
            ] else
              GestureDetector(
                onTap: _getLocation,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.location_off_rounded, color: AppColors.muted),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Could not get location. Tap to retry.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                      Icon(Icons.refresh_rounded, color: AppColors.orange, size: 20),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  'Next: Tag Status',
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppColors.ink,
        ),
      );
}

class _InputField extends StatelessWidget {
  const _InputField({required this.controller, required this.hint, this.maxLines = 1});
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.ink, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
          filled: true,
          fillColor: AppColors.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
          ),
        ),
      );
}
