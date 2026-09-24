// screens/about_screen.dart
// Dedicated About Screen with App Specs, Zero-Knowledge Architecture & Developer Information

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundZinc,
      appBar: AppBar(
        title: const Text('About Firewood', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.backgroundZinc,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.offWhite),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceZinc,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderZinc),
                  ),
                  child: Text(
                    'Version 1.0.0 • Zero-Knowledge Vault',
                    style: TextStyle(fontSize: 11, color: AppColors.orangeAccent, fontWeight: FontWeight.w600),
                  ),
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
                style: TextStyle(color: AppColors.offWhite, fontSize: 13, height: 1.5),
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
                subtitle: 'Master password never leaves device RAM. Client-side XChaCha20-Poly1305 encryption.',
              ),
              const Divider(color: AppColors.borderZinc, height: 1),
              _FeatureTile(
                icon: AppIcons.timer,
                title: 'Integrated TOTP Authenticator',
                subtitle: 'Generate 2-factor authentication codes with built-in countdown timers.',
              ),
              const Divider(color: AppColors.borderZinc, height: 1),
              _FeatureTile(
                icon: AppIcons.shield,
                title: 'Mini ML Security Advisor',
                subtitle: 'On-device Decision Tree classifier tracking vault health and recommending security tips.',
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
                subtitle: 'Master key derived using Argon2id with 16-byte random salt to resist GPU brute-force attacks.',
              ),
              const Divider(color: AppColors.borderZinc, height: 1),
              _FeatureTile(
                icon: AppIcons.lock,
                title: 'XChaCha20-Poly1305 Field Cipher',
                subtitle: 'Individual fields encrypted with 256-bit stream cipher and Poly1305 authentication tags.',
              ),
              const Divider(color: AppColors.borderZinc, height: 1),
              _FeatureTile(
                icon: AppIcons.cloud,
                title: 'Offline Storage Isolation',
                subtitle: 'Zero cloud dependencies. All data stored strictly in local Isar NoSQL encrypted database.',
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
                details: 'Cloud Infrastructure & Security Architecture.',
                githubUrl: 'https://github.com/yahyaoncloud',
                websiteUrl: 'https://yahyaoncloud.vercel.app',
              ),
              const Divider(color: AppColors.borderZinc, height: 1),
              _DeveloperTile(
                name: 'Firas Rasheed',
                role: 'Backend Engineer',
                icon: AppIcons.typeDeveloperSecret,
                details: 'Backend Architecture & Database Optimization.',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Open Source & Privacy Policy Links
          _AboutCard(
            children: [
              ListTile(
                leading: AppIcon(AppIcons.shield, color: AppColors.orangeAccent, size: 20),
                title: const Text('Privacy Policy', style: TextStyle(color: AppColors.offWhite, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('100% Offline • Zero Analytics • Zero Data Collection', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                trailing: AppIcon(AppIcons.chevronRight, color: AppColors.textMuted, size: 18),
                onTap: () => _showPrivacyDialog(context),
              ),
              const Divider(color: AppColors.borderZinc, height: 1),
              ListTile(
                leading: AppIcon(AppIcons.file, color: AppColors.orangeAccent, size: 20),
                title: const Text('License & Legal', style: TextStyle(color: AppColors.offWhite, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('MIT Open Source License', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                trailing: AppIcon(AppIcons.chevronRight, color: AppColors.textMuted, size: 18),
                onTap: () => _showLicenseDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 32),

          const Center(
            child: Text(
              'Crafted for Total Privacy & Security',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
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
        title: const Text('Privacy Policy', style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
        content: const Text(
          'Firewood is completely offline. It contains zero trackers, zero analytics, and zero cloud backends.\n\nAll passwords, notes, credit cards, and secrets are stored exclusively on your device, encrypted with your master key.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangeAccent, foregroundColor: Colors.white),
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
        title: const Text('MIT License', style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
        content: const Text(
          'Copyright (c) 2026 Firewood Contributors.\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files to deal in the Software without restriction.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangeAccent, foregroundColor: Colors.white),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        style: const TextStyle(
          fontSize: 11,
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
  final String details;
  final String? githubUrl;
  final String? websiteUrl;

  const _DeveloperTile({
    required this.name,
    required this.role,
    required this.icon,
    required this.details,
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
                Text(name, style: const TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(role, style: TextStyle(color: AppColors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(details, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4)),
                if (githubUrl != null || websiteUrl != null) const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (githubUrl != null)
                      InkWell(
                        onTap: () => _openUrl(githubUrl!),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.cardZinc,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.borderZinc),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIcon(AppIcons.typeDeveloperSecret, size: 12, color: AppColors.orangeAccent),
                              const SizedBox(width: 4),
                              Text('github.com/yahyaoncloud', style: TextStyle(fontSize: 10, color: AppColors.orangeAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    if (websiteUrl != null)
                      InkWell(
                        onTap: () => _openUrl(websiteUrl!),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.cardZinc,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.borderZinc),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIcon(AppIcons.globe, size: 12, color: AppColors.orangeAccent),
                              const SizedBox(width: 4),
                              Text('yahyaoncloud.vercel.app', style: TextStyle(fontSize: 10, color: AppColors.orangeAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
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
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
