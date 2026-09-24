// widgets/welcome_banner.dart
// One-time welcome banner shown after the user creates their first vault.
// Displays app details, security overview, and privacy agreement.
// Stored in SharedPreferences – shown only once per install.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_icons.dart';
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
      icon: AppIcons.shield,
      title: 'Zero-Knowledge Encryption',
      body: 'Your vault data is encrypted with Argon2id + XChaCha20-Poly1305. '
          'Your master password NEVER leaves your device. Firewood cannot access your credentials.',
    ),
    _PageData(
      icon: AppIcons.fingerprint,
      title: 'Biometric Security',
      body: 'Unlock your vault with fingerprint or face recognition. '
          'Biometric unlock is gated by the Android Keystore — '
          'no master password is kept in app storage.',
    ),
    _PageData(
      icon: AppIcons.fire,
      title: 'Burner Password',
      body: 'Set a duress/parent password that permanently destroys ALL vault data '
          'when entered on the unlock screen. Use this if you are ever coerced '
          'into opening your vault.',
    ),
    _PageData(
      icon: AppIcons.shield,
      title: 'Privacy Agreement',
      body: 'Firewood stores all data locally on your device. Nothing is sent to '
          'any server. You are solely responsible for your master password. '
          'Lost passwords CANNOT be recovered.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final activeAccent = Theme.of(context).colorScheme.primary;
    final page = _pages[_page];
    final isLast = _page == _pages.length - 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceZinc,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeAccent.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            spreadRadius: 4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? activeAccent : AppColors.borderZinc,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Icon
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: activeAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: AppIcon(page.icon, color: activeAccent, size: 26)),
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.offWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // Body
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Navigation buttons
          Row(
            children: [
              if (_page > 0)
                TextButton(
                  onPressed: () => setState(() => _page--),
                  child: const Text('Back', style: TextStyle(color: AppColors.textMuted)),
                )
              else
                const SizedBox(width: 64),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  if (isLast) {
                    await WelcomeBanner.dismissPermanently();
                    widget.onDismiss?.call();
                  } else {
                    setState(() => _page++);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: activeAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: Text(
                  isLast ? 'Got it' : 'Next',
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
  final dynamic icon;
  final String title;
  final String body;

  const _PageData({
    required this.icon,
    required this.title,
    required this.body,
  });
}
