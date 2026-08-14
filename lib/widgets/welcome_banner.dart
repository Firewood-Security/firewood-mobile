// widgets/welcome_banner.dart
// Refined one-time tutorial banner shown after vault creation.
// Features solid opaque 3D tactile card background, step progress, crisp contrast, and quick dismissal.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class WelcomeBanner extends StatefulWidget {
  final VoidCallback? onDismiss;

  const WelcomeBanner({super.key, this.onDismiss});

  /// Returns true if the welcome banner should be shown (first-time user).
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('welcome_banner_dismissed_v2') != true;
  }

  /// Mark the banner as dismissed so it never shows again.
  static Future<void> dismissPermanently() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('welcome_banner_dismissed_v2', true);
  }

  @override
  State<WelcomeBanner> createState() => _WelcomeBannerState();
}

class _WelcomeBannerState extends State<WelcomeBanner> {
  int _page = 0;

  static const _pages = [
    _PageData(
      icon: Icons.shield_rounded,
      title: 'Zero-Knowledge Encryption',
      body: 'Your vault data is encrypted with Argon2id + XChaCha20-Poly1305. '
          'Your master password NEVER leaves your device. Firewood cannot access your credentials.',
    ),
    _PageData(
      icon: Icons.fingerprint_rounded,
      title: 'Biometric Security',
      body: 'Unlock your vault instantly with fingerprint or face recognition. '
          'Biometric keys are stored safely in hardware-backed Keystore – '
          'never saved in plaintext.',
    ),
    _PageData(
      icon: Icons.local_fire_department_rounded,
      title: 'Burner Password',
      body: 'Set a duress/parent password that permanently destroys ALL vault data '
          'when entered on the unlock screen. Use this if you are ever coerced.',
    ),
    _PageData(
      icon: Icons.privacy_tip_rounded,
      title: 'Privacy Agreement',
      body: 'Firewood operates 100% offline on your device. Zero telemetry, zero analytics. '
          'You are solely responsible for your master password.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    final isLast = _page == _pages.length - 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Solid opaque 3D Dark Zinc base to ensure zero transparency/bleed-through
        color: const Color(0xFF1E1E22),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF25252A),
            Color(0xFF18181C),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.orangeAccent.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.85),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Header Row: Step Pill + Dismiss Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.orangeContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.orangeAccent.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      color: AppColors.orangeAccent,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'TUTORIAL • STEP ${_page + 1} OF ${_pages.length}',
                      style: const TextStyle(
                        color: AppColors.orangeOnContainer,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                onPressed: () async {
                  await WelcomeBanner.dismissPermanently();
                  widget.onDismiss?.call();
                },
                tooltip: 'Dismiss Tutorial',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              final isActive = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 24 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.orangeAccent : AppColors.borderZinc,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.orangeAccent.withValues(alpha: 0.5),
                            blurRadius: 6,
                          )
                        ]
                      : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 18),

          // Icon Badge with 3D Gradient
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.orangeBright,
                  AppColors.orangeDark,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orangeAccent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(page.icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.offWhite,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),

          // Body Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              page.body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Navigation Action Buttons
          Row(
            children: [
              if (_page > 0)
                OutlinedButton(
                  onPressed: () => setState(() => _page--),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.borderZinc),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                )
              else
                TextButton(
                  onPressed: () async {
                    await WelcomeBanner.dismissPermanently();
                    widget.onDismiss?.call();
                  },
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () async {
                  if (isLast) {
                    await WelcomeBanner.dismissPermanently();
                    widget.onDismiss?.call();
                  } else {
                    setState(() => _page++);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orangeAccent,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shadowColor: AppColors.orangeAccent.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                iconAlignment: IconAlignment.end,
                icon: Icon(
                  isLast ? Icons.check_circle_outline : Icons.arrow_forward_rounded,
                  size: 16,
                ),
                label: Text(
                  isLast ? 'Get Started' : 'Next',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageData {
  final IconData icon;
  final String title;
  final String body;

  const _PageData({
    required this.icon,
    required this.title,
    required this.body,
  });
}
