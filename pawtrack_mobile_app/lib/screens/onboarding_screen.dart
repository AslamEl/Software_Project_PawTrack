import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/pt_primary_button.dart';
import '../widgets/pt_secondary_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    super.key,
    required this.title,
    required this.description,
    required this.stepLabel,
  });

  final String title;
  final String description;
  final String stepLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stepLabel,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(letterSpacing: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange.withOpacity(0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  _imageForStep(stepLabel),
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: PtSecondaryButton(
                      label: 'Skip',
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, AppRoutes.login);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PtPrimaryButton(
                      label: 'Next',
                      onPressed: () {
                        _handleNext(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNext(BuildContext context) {
    if (stepLabel.startsWith('01')) {
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding2);
      return;
    }
    if (stepLabel.startsWith('02')) {
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding3);
      return;
    }
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  String _imageForStep(String label) {
    if (label.startsWith('01')) {
      return 'assets/images/onboarding_1.jpg';
    }
    if (label.startsWith('02')) {
      return 'assets/images/onboarding_2.jpg';
    }
    return 'assets/images/onboarding_3.jpg';
  }
}
