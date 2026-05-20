import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/pt_primary_button.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SplashBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BrandRow(),
                  const SizedBox(height: 32),
                  Text(
                    'Every stray\nDeserves a \nHero.',
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(
                          color: AppColors.ink,
                          height: 1.2,
                          fontSize: 46,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'PawTrack turns quick reports into real help for dogs nearby.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 170,
                    child: PtPrimaryButton(
                      label: 'Get Started',
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.onboarding1);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: AppColors.card,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.orange.withOpacity(0.35),
                            blurRadius: 30,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/splash_hero.jpg',
                          fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
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
  }
}

class _BrandRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
              ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'PawTrack',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(color: AppColors.ink),
        ),
      ],
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -0.7),
            radius: 1.2,
            colors: [
              Color(0x33F58A1F),
              Color(0x00FFF3E8),
            ],
          ),
        ),
      ),
    );
  }
}
