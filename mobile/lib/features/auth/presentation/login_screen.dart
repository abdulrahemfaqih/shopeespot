import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    ref.read(authControllerProvider.notifier).clearError();
    if (_formKey.currentState?.validate() ?? false) {
      ref
          .read(authControllerProvider.notifier)
          .submit(
            email: _emailController.text,
            password: _passwordController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final authState = ref.watch(authControllerProvider);
    final isRegister = authState.isRegisterMode;

    return Scaffold(
      backgroundColor: tokens.surface,
      appBar: AppBar(
        title: Text(isRegister ? 'Daftar Akun' : 'Masuk SpotShopee'),
        backgroundColor: tokens.surface,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(tokens.space24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isRegister
                        ? 'Buat akun driver Anda'
                        : 'Masuk ke akun driver Anda',
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  SizedBox(height: tokens.space4),
                  Text(
                    isRegister
                        ? 'Simpan dan cadangkan spot secara aman.'
                        : 'Buka sesi untuk menyinkronkan spot & order.',
                    style: TextStyle(
                      fontSize: 14.0,
                      color: tokens.textSecondary,
                    ),
                  ),
                  SizedBox(height: tokens.space24),
                  if (authState.errorMessage != null) ...[
                    _buildErrorBanner(tokens, authState.errorMessage!),
                    SizedBox(height: tokens.space16),
                  ],
                  _buildEmailField(tokens),
                  SizedBox(height: tokens.space16),
                  _buildPasswordField(tokens),
                  SizedBox(height: tokens.space24),
                  AppButton.primary(
                    label: authState.isLoading
                        ? 'Memproses...'
                        : (isRegister ? 'Daftar' : 'Masuk'),
                    onPressed: authState.isLoading ? null : _handleSubmit,
                    isFullWidth: true,
                  ),
                  SizedBox(height: tokens.space16),
                  TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .toggleMode(),
                    child: Text(
                      isRegister
                          ? 'Sudah punya akun? Masuk'
                          : 'Belum punya akun? Daftar',
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: tokens.actionFill,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(AppTokens tokens, String message) {
    return Container(
      padding: EdgeInsets.all(tokens.space12),
      decoration: BoxDecoration(
        color: tokens.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: tokens.danger.withValues(alpha: 0.3),
          width: tokens.borderWidth,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: tokens.danger, size: 20.0),
          SizedBox(width: tokens.space8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.0,
                color: tokens.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField(AppTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email',
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            color: tokens.textSecondary,
          ),
        ),
        SizedBox(height: tokens.space4),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'driver@example.com',
            contentPadding: EdgeInsets.symmetric(
              horizontal: tokens.space12,
              vertical: tokens.space12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              borderSide: BorderSide(
                color: tokens.border,
                width: tokens.borderWidth,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              borderSide: BorderSide(
                color: tokens.border,
                width: tokens.borderWidth,
              ),
            ),
          ),
          validator: (val) {
            final text = val?.trim() ?? '';
            if (text.isEmpty || !text.contains('@')) {
              return 'Masukkan email yang valid';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField(AppTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kata sandi',
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            color: tokens.textSecondary,
          ),
        ),
        SizedBox(height: tokens.space4),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleSubmit(),
          decoration: InputDecoration(
            hintText: 'Minimal 8 karakter',
            contentPadding: EdgeInsets.symmetric(
              horizontal: tokens.space12,
              vertical: tokens.space12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              borderSide: BorderSide(
                color: tokens.border,
                width: tokens.borderWidth,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              borderSide: BorderSide(
                color: tokens.border,
                width: tokens.borderWidth,
              ),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: tokens.textSecondary,
                size: 20.0,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          validator: (val) {
            final text = val ?? '';
            if (text.length < 8) {
              return 'Kata sandi minimal 8 karakter';
            }
            return null;
          },
        ),
      ],
    );
  }
}
