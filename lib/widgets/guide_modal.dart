// widgets/guide_modal.dart
// Centered Guide / Welcome Carousel Modal with background blur effect

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class GuideModal extends StatefulWidget {
  final VoidCallback? onDismiss;

  const GuideModal({super.key, this.onDismiss});

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('welcome_banner_dismissed_v2') != true;
  }

  static Future<void> dismissPermanently() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('welcome_banner_dismissed_v2', true);
  }

  static Future<void> show(BuildContext context, {VoidCallback? onDismiss}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => GuideModal(onDismiss: onDismiss),
    );
  }

  @override
  State<GuideModal> createState() => _GuideModalState();
}

class _GuideModalState extends State<GuideModal>
    with SingleTickerProviderStateMixin {
  int _page = 0;
  late final PageController _pageController;

  static const _pages = [
    _GuidePageData(
      icon: AppIcons.shield,
      title: 'Zero-Knowledge Encryption',
      subtitle: 'ARGON2ID + XCHACHA20-POLY1305',
      body:
          'Your vault data is locally encrypted. Your master password NEVER leaves your device. '
          'Firewood cannot access, decrypt, or transmit your credentials.',
    ),
    _GuidePageData(
      icon: AppIcons.fingerprint,
      title: 'Biometric Security',
      subtitle: 'HARDWARE KEYSTORE INTEGRATION',
      body:
          'Unlock seamlessly with fingerprint or face biometric authentication. '
          'Keys are protected by the hardware security module.',
    ),
    _GuidePageData(
      icon: AppIcons.fire,
      title: 'Burner Password',
      subtitle: 'EMERGENCY DURESS WIPING',
      body:
          'Configure a duress password that permanently destroys all vault data if you are ever coerced into unlocking your device.',
    ),
    _GuidePageData(
      icon: AppIcons.lockClock,
      title: 'Auto-Lock & Inactivity',
      subtitle: 'SCREEN PRIVACY & CLIPBOARD AUTO-CLEAR',
      body:
          'Automatic locking on app minimization and clipboard auto-clearing protect your data from memory dumping and background snooping.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeAccent = Theme.of(context).colorScheme.primary;
    final isLast = _page == _pages.length - 1;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              decoration: BoxDecoration(
                color: const Color(0xFF16161A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.borderZinc,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          final isCurrent = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isCurrent ? 24 : 6,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? activeAccent
                                  : AppColors.borderZinc,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),

                      // Carousel Page Content
                      SizedBox(
                        height: 220,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemCount: _pages.length,
                          itemBuilder: (context, index) {
                            final page = _pages[index];
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Center(child: AppIcon(page.icon, size: 44)),
                                const SizedBox(height: 16),
                                Text(
                                  page.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.offWhite,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  page.subtitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: activeAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  page.body,
                                  textAlign: TextAlign.center,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12.5,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Controls
                      Row(
                        children: [
                          if (_page > 0)
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textMuted,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                              child: const Text('Back',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                            )
                          else
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textMuted,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                await GuideModal.dismissPermanently();
                                if (context.mounted)
                                  Navigator.of(context).pop();
                                widget.onDismiss?.call();
                              },
                              child: const Text('Skip',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          const Spacer(),
                          Container(
                            decoration: BoxDecoration(
                              color: activeAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  HapticFeedback.selectionClick();
                                  if (isLast) {
                                    await GuideModal.dismissPermanently();
                                    if (context.mounted)
                                      Navigator.of(context).pop();
                                    widget.onDismiss?.call();
                                  } else {
                                    _pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      curve: Curves.easeOutCubic,
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 22, vertical: 11),
                                  child: Text(
                                    isLast ? 'Get Started' : 'Next',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
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
          ),
        ),
      ),
    );
  }
}

class _GuidePageData {
  final dynamic icon;
  final String title;
  final String subtitle;
  final String body;

  const _GuidePageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
  });
}
