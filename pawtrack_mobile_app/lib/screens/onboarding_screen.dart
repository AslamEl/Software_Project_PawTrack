import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animCtrl;
  late Animation<double> _fade;

  static const _slides = [
    _Slide(
      image: 'assets/images/onboarding_1.jpg',
      tag: 'Community',
      title: 'Track.\nRescue.\nRepeat.',
      body:
          'Join the PawTrack community to help stray dogs find safety faster than ever before.',
    ),
    _Slide(
      image: 'assets/images/onboarding_2.jpg',
      tag: 'Quick & Easy',
      title: 'Report\nin Seconds.',
      body:
          'Snap a photo, add notes, and pin the exact location on a live map — all in under a minute.',
    ),
    _Slide(
      image: 'assets/images/onboarding_3.jpg',
      tag: 'Make Impact',
      title: 'Be a\nLocal Hero.',
      body:
          'Offer food, shelter, or adoption with a single tap. Earn badges for every life you help.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  void _skip() {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: Stack(
          children: [
            // Background blob
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.orange.withOpacity(0.09),
                ),
              ),
            ),
            Column(
              children: [
                // Image area — PageView
                SizedBox(
                  height: size.height * 0.52,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) {
                      setState(() => _currentPage = i);
                      _animCtrl.reset();
                      _animCtrl.forward();
                    },
                    itemCount: _slides.length,
                    itemBuilder: (_, i) => _ImagePage(slide: _slides[i]),
                  ),
                ),
                // Bottom content
                Expanded(
                  child: FadeTransition(
                    opacity: _fade,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dot indicators
                          Row(
                            children: List.generate(
                              _slides.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(right: 6),
                                width: i == _currentPage ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: i == _currentPage
                                      ? AppColors.orange
                                      : AppColors.orange.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Tag chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _slides[_currentPage].tag,
                              style: const TextStyle(
                                color: AppColors.orangeDeep,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Title
                          Text(
                            _slides[_currentPage].title,
                            style: AppTextStyles.headlineLarge.copyWith(
                              fontSize: 30,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Body
                          Text(
                            _slides[_currentPage].body,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                          const Spacer(),
                          // Buttons row
                          Row(
                            children: [
                              TextButton(
                                onPressed: _skip,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.muted,
                                ),
                                child: const Text(
                                  'Skip',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _next,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 28, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppColors.orange,
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.orange.withOpacity(0.35),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _currentPage == _slides.length - 1
                                            ? 'Get Started'
                                            : 'Next',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePage extends StatelessWidget {
  const _ImagePage({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withOpacity(0.22),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Image.asset(
            slide.image,
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        ),
      ),
    );
  }
}

class _Slide {
  final String image;
  final String tag;
  final String title;
  final String body;
  const _Slide({
    required this.image,
    required this.tag,
    required this.title,
    required this.body,
  });
}
