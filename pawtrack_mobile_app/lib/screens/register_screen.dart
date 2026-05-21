import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/pt_input_field.dart';
import '../widgets/pt_primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _selectedRole = 0;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = '+94 ';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create account',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontSize: 26),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join PawTrack to help stray dogs',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 26),
                    PtInputField(
                      label: 'Full name',
                      hintText: 'John Doe',
                      textInputAction: TextInputAction.next,
                      controller: _nameController,
                    ),
                    const SizedBox(height: 16),
                    PtInputField(
                      label: 'Email address',
                      hintText: 'you@email.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _emailValidator,
                      controller: _emailController,
                    ),
                    const SizedBox(height: 16),
                    PtInputField(
                      label: 'Phone number',
                      hintText: '+94 7x xxx xxxx',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      controller: _phoneController,
                      validator: _phoneValidator,
                    ),
                    const SizedBox(height: 16),
                    PtInputField(
                      label: 'Password',
                      hintText: 'Create a password',
                      obscureText: true,
                      validator: _passwordValidator,
                      controller: _passwordController,
                      showVisibilityToggle: true,
                    ),
                    const SizedBox(height: 16),
                    PtInputField(
                      label: 'Confirm password',
                      hintText: 'Re-enter your password',
                      obscureText: true,
                      controller: _confirmPasswordController,
                      showVisibilityToggle: true,
                      validator: _confirmPasswordValidator,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'I want to join as...',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(
                        _roles.length,
                        (index) => ChoiceChip(
                          label: Text(_roles[index]),
                          selected: _selectedRole == index,
                          labelStyle: TextStyle(
                            color: _selectedRole == index
                                ? Colors.white
                                : AppColors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          selectedColor: AppColors.orange,
                          backgroundColor: AppColors.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedRole = index;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'By continuing, you agree to PawTrack\'s terms and privacy policy.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    PtPrimaryButton(
                      label: 'Create account',
                      onPressed: _isSubmitting ? null : () => _submitRegister(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(
                                context, AppRoutes.login);
                          },
                          child: const Text('Log in'),
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

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Email is required.';
    }
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!regex.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final password = value?.trim() ?? '';
    if (password.isEmpty) {
      return 'Password is required.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    final confirm = value?.trim() ?? '';
    if (confirm.isEmpty) {
      return 'Please confirm your password.';
    }
    if (confirm != _passwordController.text.trim()) {
      return 'Passwords do not match.';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) {
      return 'Phone number is required.';
    }
    final normalized = phone.replaceAll(RegExp(r'\s+'), '');
    if (!normalized.startsWith('+94')) {
      return 'Use Sri Lankan format starting with +94.';
    }
    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) {
      return 'Enter 9 digits after +94.';
    }
    return null;
  }

  Future<void> _submitRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showMessage('Please enter a valid email.');
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      final result = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await result.user?.updateDisplayName(_nameController.text.trim());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(result.user?.uid)
          .set({
        'uid': result.user?.uid,
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _roles[_selectedRole],
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.success);
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Registration failed.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

const List<String> _roles = [
  'Citizen',
  'Volunteer',
  'NGO',
];

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -0.6),
            radius: 1.4,
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
