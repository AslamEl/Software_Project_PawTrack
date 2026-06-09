import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../routes/app_routes.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class EmergencyAlertScreen extends StatefulWidget {
  const EmergencyAlertScreen({super.key});

  @override
  State<EmergencyAlertScreen> createState() => _EmergencyAlertScreenState();
}

class _EmergencyAlertScreenState extends State<EmergencyAlertScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docId = ModalRoute.of(context)!.settings.arguments as String;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dog_reports')
          .doc(docId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFFFFEBEB),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
          );
        }
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final dogName = data['dogName'] as String? ?? 'Unknown Dog';
        final photoUrl = data['photoUrl'] as String?;
        final urgency = (data['urgency'] as String? ?? 'high').toLowerCase();
        final statusList = data['status'];
        final statuses = statusList is List
            ? statusList.map((s) => s.toString()).toList()
            : <String>[];
        final notes = data['notes'] as String? ?? '';
        final geoPoint = data['location'] as GeoPoint?;

        final urgencyColor = urgency == 'high'
            ? const Color(0xFFE53935)
            : urgency == 'medium'
                ? AppColors.orange
                : const Color(0xFF43A047);
        final urgencyLabel = urgency == 'high'
            ? 'URGENT'
            : urgency == 'medium'
                ? 'MODERATE'
                : 'LOW';

        return Scaffold(
          backgroundColor: const Color(0xFFFFF5F5),
          body: Column(
            children: [
              // ── Top Alert Banner ─────────────────────────────────────────
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          urgencyColor,
                          Color.lerp(urgencyColor,
                              urgencyColor.withOpacity(0.85), _pulse.value)!,
                        ],
                      ),
                    ),
                    child: child,
                  );
                },
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Row(
                      children: [
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, _) => Transform.scale(
                            scale: 1.0 + _pulse.value * 0.15,
                            child: const Icon(Icons.warning_rounded,
                                color: Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🚨 $urgencyLabel — DOG NEEDS HELP',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'A dog near you requires immediate attention.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.90),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Scrollable body ──────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dog photo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: photoUrl != null && photoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: photoUrl,
                                width: double.infinity,
                                height: 220,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  height: 220,
                                  color: AppColors.border,
                                  child: const Center(
                                      child: CircularProgressIndicator(
                                          color: AppColors.orange)),
                                ),
                                errorWidget: (_, __, ___) => _PhotoPlaceholder(),
                              )
                            : _PhotoPlaceholder(),
                      ),
                      const SizedBox(height: 20),

                      // Name + urgency badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              dogName.isNotEmpty ? dogName : 'Unnamed Dog',
                              style: AppTextStyles.headlineLarge
                                  .copyWith(fontSize: 22),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: urgencyColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: urgencyColor.withOpacity(0.4)),
                            ),
                            child: Text(
                              urgencyLabel,
                              style: TextStyle(
                                color: urgencyColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Status chips
                      if (statuses.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: statuses
                              .map((s) => _StatusChip(label: s))
                              .toList(),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Notes
                      if (notes.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            notes,
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.muted),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Location info
                      if (geoPoint != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  color: urgencyColor, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '${geoPoint.latitude.toStringAsFixed(4)}, '
                                '${geoPoint.longitude.toStringAsFixed(4)}',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Action buttons
                      _ActionButton(
                        label: 'I Can Help',
                        icon: Icons.volunteer_activism_rounded,
                        color: const Color(0xFF43A047),
                        onPressed: () => Navigator.pushNamed(
                            context, AppRoutes.offerHelp,
                            arguments: docId),
                      ),
                      const SizedBox(height: 12),
                      _ActionButton(
                        label: 'View on Map',
                        icon: Icons.map_rounded,
                        color: AppColors.orange,
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.home,
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.muted,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            'Dismiss',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _PhotoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        Icons.pets_rounded,
        size: 64,
        color: AppColors.orange.withOpacity(0.4),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  Color get _color {
    switch (label.toLowerCase()) {
      case 'injured':
      case 'needs rescue': return const Color(0xFFE53935);
      case 'rescued':      return const Color(0xFF43A047);
      case 'hungry':       return AppColors.orange;
      case 'stray':        return const Color(0xFF78909C);
      case 'friendly':     return const Color(0xFF2196F3);
      default:             return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }
}
