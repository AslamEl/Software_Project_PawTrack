import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/toast.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _selectedRole = 0;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  static const _roles = ['Citizen', 'Volunteer', 'NGO'];
  static const _roleIcons = [
    Icons.person_rounded,
    Icons.volunteer_activism_rounded,
    Icons.business_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _phoneCtrl.text = '+94 ';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Validators ─────────────────────────────────────────────────────────────

  String? _emailValidator(String? v) {
    final e = v?.trim() ?? '';
    if (e.isEmpty) return 'Email is required.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _passwordValidator(String? v) {
    final p = v?.trim() ?? '';
    if (p.isEmpty) return 'Password is required.';
    if (p.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  String? _confirmValidator(String? v) {
    if ((v?.trim() ?? '').isEmpty) return 'Please confirm your password.';
    if (v?.trim() != _passwordCtrl.text.trim()) return 'Passwords do not match.';
    return null;
  }

  String? _phoneValidator(String? v) {
    final phone = v?.trim() ?? '';
    if (phone.isEmpty) return 'Phone number is required.';
    final normalized = phone.replaceAll(RegExp(r'\s+'), '');
    if (!normalized.startsWith('+94')) return 'Use Sri Lankan format (+94).';
    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return 'Enter 9 digits after +94.';
    return null;
  }

  // ── Firebase logic (unchanged) ─────────────────────────────────────────────

  Future<void> _submitRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    try {
      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      await result.user?.updateDisplayName(_nameCtrl.text.trim());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(result.user?.uid)
          .set({
        'uid': result.user?.uid,
        'fullName': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'role': _roles[_selectedRole],
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } on FirebaseAuthException catch (e) {
      AppToast.error(context, e.message ?? 'Registration failed.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }



  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            left: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orange.withOpacity(0.09),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orange.withOpacity(0.06),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back + Logo row
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: AppColors.ink, size: 20),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 44,
                          height: 44,
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.orange.withOpacity(0.22),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Image.asset('assets/images/logo.png',
                              fit: BoxFit.contain),
                        ),
                        const Spacer(),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Create account',
                      style: AppTextStyles.headlineLarge.copyWith(fontSize: 26),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join PawTrack to help stray dogs.',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Full name
                    _FieldLabel('Full name'),
                    const SizedBox(height: 8),
                    _AuthField(
                      controller: _nameCtrl,
                      hint: 'John Doe',
                      icon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    _FieldLabel('Email address'),
                    const SizedBox(height: 8),
                    _AuthField(
                      controller: _emailCtrl,
                      hint: 'you@email.com',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _emailValidator,
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    _FieldLabel('Phone number'),
                    const SizedBox(height: 8),
                    _AuthField(
                      controller: _phoneCtrl,
                      hint: '+94 7x xxx xxxx',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: _phoneValidator,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    _FieldLabel('Password'),
                    const SizedBox(height: 8),
                    _AuthField(
                      controller: _passwordCtrl,
                      hint: 'Create a password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      validator: _passwordValidator,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.muted,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm password
                    _FieldLabel('Confirm password'),
                    const SizedBox(height: 8),
                    _AuthField(
                      controller: _confirmCtrl,
                      hint: 'Re-enter your password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscureConfirm,
                      validator: _confirmValidator,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.muted,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Role selector
                    _FieldLabel('I want to join as...'),
                    const SizedBox(height: 12),
                    Row(
                      children: List.generate(_roles.length, (i) {
                        final selected = _selectedRole == i;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedRole = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(
                                  right: i < _roles.length - 1 ? 10 : 0),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.orange
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.orange
                                      : AppColors.border,
                                  width: 1.5,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.orange
                                              .withOpacity(0.30),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    _roleIcons[i],
                                    color: selected
                                        ? Colors.white
                                        : AppColors.muted,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _roles[i],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? Colors.white
                                          : AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'By continuing, you agree to PawTrack\'s Terms & Privacy Policy.',
                      style: TextStyle(
                          color: AppColors.muted, fontSize: 12, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    _PrimaryBtn(
                      label: 'Create Account',
                      loading: _isSubmitting,
                      onPressed: _submitRegister,
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?  ',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacementNamed(
                              context, AppRoutes.login),
                          child: const Text(
                            'Sign in',
                            style: TextStyle(
                              color: AppColors.orange,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Local widget helpers ────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppColors.ink,
        ),
      );
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      style: const TextStyle(color: AppColors.ink, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.orange.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }
}
