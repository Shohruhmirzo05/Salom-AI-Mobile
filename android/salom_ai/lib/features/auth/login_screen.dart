import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/features/auth/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoadingGoogle = false;
  bool _isLoadingApple = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const SizedBox(height: 20),
                  _buildHeader(),
                  
                  const SizedBox(height: 24),
                  
                  // Wrap OAuth buttons in Glass Container
                  GlassContainer(
                    borderRadius: BorderRadius.circular(26),
                    blur: 10,
                    opacity: 0.1,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           _buildGoogleButton(),
                           // Apple Sign In not supported on Android yet
                           // const SizedBox(height: 14),
                           // _buildAppleButton(),
                        ],
                      ),
                    ),
                  ),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16, left: 6, right: 6),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                            color: AppTheme.danger,
                            fontSize: 12,
                        ),
                      ),
                    ),

                  const Spacer(),
                  
                  _buildFooter(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Keling, kirib olamiz",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Telefon raqamingiz bilan tezda kirishingiz mumkin.",
          style: TextStyle(
            fontSize: 15, // subheadline
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return InkWell(
      onTap: (_isLoadingGoogle || _isLoadingApple) ? null : _handleGoogleSignIn,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoadingGoogle)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              )
            else ...[
              Image.asset(
                'assets/images/google_icon.png',
                width: 24,
                height: 24,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              "Continue with Google",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(_isLoadingGoogle ? 0.6 : 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppleButton() {
    return InkWell(
      onTap: (_isLoadingGoogle || _isLoadingApple) ? null : _handleAppleSignIn,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.black, // Native Apple button style
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             if (_isLoadingApple)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              )
            else ...[
               // Using a generic apple icon from font or asset if available. 
               // Assuming standard icon font or just text for now as we didn't copy apple icon.
               // Users usually have CupertinoIcons.
              const Icon(Icons.apple, color: Colors.white, size: 24), 
              const SizedBox(width: 8),
            ],
            Text(
              "Sign in with Apple",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(_isLoadingApple ? 0.6 : 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      "Kirish orqali siz xizmat shartlari va maxfiylik siyosatiga rozilik bildirasiz.",
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12, 
        color: AppTheme.textSecondary,
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoadingGoogle = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      // Navigation handled by router
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGoogle = false;
        });
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoadingApple = true;
       _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).signInWithApple();
    } catch (e) {
       if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
       if (mounted) {
        setState(() {
          _isLoadingApple = false;
        });
      }
    }
  }
}
