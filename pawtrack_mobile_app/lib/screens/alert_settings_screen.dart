import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/toast.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class AlertSettingsScreen extends StatefulWidget {
  const AlertSettingsScreen({super.key});

  @override
  State<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends State<AlertSettingsScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _notificationsEnabled = true;
  double _alertRadius = 10.0;    // km
  String _statusFilter = 'all';  // 'all' | 'injured'
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
          _alertRadius = ((data['alertRadius'] ?? 10) as num).toDouble();
          _statusFilter = data['alertStatusFilter'] ?? 'all';
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Sync FCM token subscription when toggling on
      if (_notificationsEnabled) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_uid)
              .set({'fcmToken': token}, SetOptions(merge: true));
        }
      }
      await FirebaseFirestore.instance.collection('users').doc(_uid).set(
        {
          'notificationsEnabled': _notificationsEnabled,
          'alertRadius': _alertRadius,
          'alertStatusFilter': _statusFilter,
        },
        SetOptions(merge: true),
      );
      if (mounted) AppToast.success(context, 'Alert settings saved.');
    } catch (e) {
      if (mounted) AppToast.error(context, 'Failed to save settings.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text('Alert Settings',
            style: AppTextStyles.headlineLarge.copyWith(fontSize: 20)),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel('Push Notifications'),
                  const SizedBox(height: 10),
                  _SettingCard(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.notifications_rounded,
                              color: AppColors.orange, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enable notifications',
                                style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Receive alerts for dogs nearby.',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: AppColors.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _notificationsEnabled,
                          onChanged: (v) =>
                              setState(() => _notificationsEnabled = v),
                          activeColor: AppColors.orange,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _SectionLabel('Alert Radius'),
                  const SizedBox(height: 10),
                  _SettingCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.radar_rounded,
                                  color: Color(0xFF2196F3), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Notify me within',
                                style: AppTextStyles.titleMedium
                                    .copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              '${_alertRadius.toInt()} km',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.orange,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppColors.orange,
                            inactiveTrackColor:
                                AppColors.orange.withOpacity(0.18),
                            thumbColor: AppColors.orange,
                            overlayColor: AppColors.orange.withOpacity(0.15),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _alertRadius,
                            min: 1,
                            max: 50,
                            divisions: 49,
                            onChanged: _notificationsEnabled
                                ? (v) => setState(() => _alertRadius = v)
                                : null,
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('1 km',
                                  style: TextStyle(
                                      color: AppColors.muted, fontSize: 11)),
                              Text('50 km',
                                  style: TextStyle(
                                      color: AppColors.muted, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _SectionLabel('Status Filter'),
                  const SizedBox(height: 10),
                  _SettingCard(
                    child: Column(
                      children: [
                        _FilterOption(
                          icon: Icons.pets_rounded,
                          iconColor: AppColors.orange,
                          title: 'All statuses',
                          subtitle: 'Notify for any dog report near you.',
                          value: 'all',
                          groupValue: _statusFilter,
                          enabled: _notificationsEnabled,
                          onChanged: (v) =>
                              setState(() => _statusFilter = v!),
                        ),
                        const Divider(
                            height: 1,
                            color: AppColors.border,
                            indent: 54),
                        _FilterOption(
                          icon: Icons.medical_services_rounded,
                          iconColor: const Color(0xFFE53935),
                          title: 'Injured only',
                          subtitle: 'Only alert for injured or rescued dogs.',
                          value: 'injured',
                          groupValue: _statusFilter,
                          enabled: _notificationsEnabled,
                          onChanged: (v) =>
                              setState(() => _statusFilter = v!),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.orange.withOpacity(0.5),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Settings',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.muted,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
        fontSize: 11,
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => onChanged(value) : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: enabled ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: enabled ? onChanged : null,
              activeColor: AppColors.orange,
            ),
          ],
        ),
      ),
    );
  }
}
