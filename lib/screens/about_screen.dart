// screens/about_screen.dart
// Dedicated About Screen with App Specs, Zero-Knowledge Architecture & Developer Information

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_button.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundZinc,
      appBar: AppBar(
        title: const Text('About Firewood',
            style: TextStyle(
                color: AppColors.offWhite,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        backgroundColor: AppColors.backgroundZinc,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.offWhite),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          // App Logo & Header
          // App Logo & Header (Minimalist, No Glows)
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/FWS.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Firewood',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.offWhite,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Zero-Knowledge Vault',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Product Overview
          const _AboutSectionTitle(title: 'OVERVIEW'),
          _AboutCard(
            children: [
              const Text(
                'Firewood is an open-source, zero-knowledge password vault engineered for absolute offline privacy.',
                style: TextStyle(
                    color: AppColors.offWhite, fontSize: 13, height: 1.5),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Core Features Section
          const _AboutSectionTitle(title: 'CORE FEATURES'),
          _AboutCard(
            children: [
              _FeatureTile(
                icon: AppIcons.shield,
                title: 'Zero-Knowledge Security',
                subtitle:
                    'Master password never leaves device RAM. Client-side XChaCha20-Poly1305 encryption.',
              ),
              const Divider(color: AppColors.borderZinc, height: 1),
              _FeatureTile(
                icon: AppIcons.timer,
                title: 'Integrated TOTP Authenticator',
                subtitle:
                    'Generate 2-factor authentication codes with built-in countdown timers.',
              ),
              const Divider(color: AppColors.borderZinc, height: 1),
              _FeatureTile(
                icon: AppIcons.shield,
                title: 'Mini ML Security Advisor',
                subtitle:
                    'On-device Decision Tree classifier tracking vault health and recommending security tips.',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Security Architecture Section
          const _AboutSectionTitle(title: 'SECURITY ARCHITECTURE'),
          _AboutCard(
            children: [
              _FeatureTile(
                icon: AppIcons.key,
                title: 'Argon2id Key Derivation',
                subtitle:
                    'Master key derived using Argon2id with 16-byte random salt to resist GPU brute-force attacks.',
              ),
              const Divider(color: AppColors.borderZinc, height: 1),
              _FeatureTile(
                icon: AppIcons.lock,
                title: 'XChaCha20-Poly1305 Field Cipher',
                subtitle:
                    'Individual fields encrypted with 256-bit stream cipher and Poly1305 authentication tags.',
              ),
              const Divider(color: AppColors.borderZinc, height: 1),
              _FeatureTile(
                icon: AppIcons.cloud,
                title: 'Offline Storage Isolation',
                subtitle:
                    'Zero cloud dependencies. All data stored strictly in local Isar NoSQL encrypted database.',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Developer Information Card
          const _AboutSectionTitle(title: 'DEVELOPERS'),
          _AboutCard(
            children: [
              _DeveloperTile(
                name: 'Yahya',
                role: 'Cloud Engineer',
                icon: AppIcons.cloud,
                githubUrl: 'https://github.com/yahyaoncloud',
                websiteUrl: 'https://yahyaoncloud.vercel.app',
              ),
              const Divider(color: AppColors.borderZinc, height: 1),
              _DeveloperTile(
                name: 'Firas Rasheed',
                role: 'Backend Engineer',
                icon: AppIcons.typeDeveloperSecret,
                githubUrl: 'https://github.com/Firewood-Security',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Support & Bug Reports Section
          const _AboutSectionTitle(title: 'SUPPORT & BUG REPORTS'),
          _AboutCard(
            children: [
              const Text(
                'Encountered an issue, need assistance, or have feedback? Submit a support ticket directly to the Firewood engineering team.',
                style: TextStyle(
                  color: AppColors.offWhite,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              AppButton(
                label: 'Email Support Ticket',
                icon: HugeIcons.strokeRoundedMail01,
                variant: AppButtonVariant.primary,
                fullWidth: true,
                height: 44,
                onPressed: () => _sendSupportEmail(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Open Source & Privacy Policy Links
          _AboutCard(
            children: [
              ListTile(
                leading: AppIcon(AppIcons.shield,
                    color: AppColors.orangeAccent, size: 20),
                title: const Text('Privacy Policy',
                    style: TextStyle(
                        color: AppColors.offWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                subtitle: const Text(
                    '100% Offline • Zero Analytics • Zero Data Collection',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                trailing: AppIcon(AppIcons.chevronRight,
                    color: AppColors.textMuted, size: 18),
                onTap: () => _showPrivacyDialog(context),
              ),
              const Divider(color: AppColors.borderZinc, height: 1),
              ListTile(
                leading: AppIcon(AppIcons.file,
                    color: AppColors.orangeAccent, size: 20),
                title: const Text('License & Legal',
                    style: TextStyle(
                        color: AppColors.offWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                subtitle: const Text('MIT Open Source License',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                trailing: AppIcon(AppIcons.chevronRight,
                    color: AppColors.textMuted, size: 18),
                onTap: () => _showLicenseDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 32),

          const Center(
            child: Text(
              'Crafted for Total Privacy & Security',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  static void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        title: const Text('Privacy Policy',
            style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
        content: const Text(
          'Firewood is completely offline. It contains zero trackers, zero analytics, and zero cloud backends.\n\nAll passwords, notes, credit cards, and secrets are stored exclusively on your device, encrypted with your master key.',
          style:
              TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangeAccent,
                foregroundColor: Colors.white,
                shadowColor: AppColors.shade(AppColors.orangeAccent, -0.18)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void _showLicenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        title: const Text('MIT License',
            style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
        content: const Text(
          'Copyright (c) 2026 Firewood Contributors.\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files to deal in the Software without restriction.',
          style:
              TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangeAccent,
                foregroundColor: Colors.white,
                shadowColor: AppColors.shade(AppColors.orangeAccent, -0.18)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<void> _sendSupportEmail(BuildContext context) async {
    final os = Platform.operatingSystem;
    final osVersion = Platform.operatingSystemVersion;
    final subject = Uri.encodeComponent('[Firewood Support] Issue Report');
    final body = Uri.encodeComponent(
      'Device & App Details:\n'
      '• App Version: 1.0.0\n'
      '• OS: $os ($osVersion)\n\n'
      'Description of Issue / Feedback:\n'
      '[Please describe your issue or question here]\n\n'
      'Steps to Reproduce (if applicable):\n'
      '1. \n'
      '2. \n',
    );
    final emailUri = Uri.parse(
        'mailto:support@firewoodsecurity.com?subject=$subject&body=$body');
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        throw 'Cannot launch mailto';
      }
    } catch (_) {
      if (context.mounted) {
        Clipboard.setData(
            const ClipboardData(text: 'support@firewoodsecurity.com'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support email copied: support@firewoodsecurity.com'),
          ),
        );
      }
    }
  }
}

class _AboutSectionTitle extends StatelessWidget {
  final String title;
  const _AboutSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.syncopate(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final List<Widget> children;
  const _AboutCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceZinc,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _DeveloperTile extends StatelessWidget {
  final String name;
  final String role;
  final dynamic icon;
  final String? githubUrl;
  final String? websiteUrl;

  const _DeveloperTile({
    required this.name,
    required this.role,
    required this.icon,
    this.githubUrl,
    this.websiteUrl,
  });

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.cardZinc,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderZinc),
            ),
            child: Center(
              child: AppIcon(icon, size: 20, color: AppColors.orangeAccent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.offWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: TextStyle(
                    color: AppColors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (githubUrl != null)
                IconButton(
                  icon: const AppIcon(AppIcons.github,
                      size: 20, color: AppColors.offWhite),
                  tooltip: 'GitHub',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _openUrl(githubUrl!),
                ),
              if (websiteUrl != null)
                IconButton(
                  icon: AppIcon(AppIcons.globe,
                      size: 20, color: AppColors.orangeAccent),
                  tooltip: 'Website',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _openUrl(websiteUrl!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String subtitle;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.offWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
