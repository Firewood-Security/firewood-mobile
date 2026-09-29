// screens/password_generator_screen.dart
// Dedicated standalone password, passphrase and PIN generator screen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../services/accent_color_service.dart';
import '../services/generator_service.dart';
import '../services/lock_service.dart';
import '../theme/app_button.dart';
import '../theme/app_feedback.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/vault_components.dart';
import '../widgets/password_strength_meter.dart';

enum GeneratorMode { password, passphrase, pin }

class PasswordGeneratorScreen extends ConsumerStatefulWidget {
  const PasswordGeneratorScreen({super.key});

  @override
  ConsumerState<PasswordGeneratorScreen> createState() =>
      _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState
    extends ConsumerState<PasswordGeneratorScreen> {
  GeneratorMode _mode = GeneratorMode.password;

  // Password options
  double _passwordLength = 16;
  bool _includeUpper = true;
  bool _includeLower = true;
  bool _includeDigits = true;
  bool _includeSymbols = true;
  bool _excludeAmbiguous = false;

  // Passphrase options
  double _wordCount = 4;
  String _separator = '-';
  bool _capitalizePassphrase = true;
  bool _includePassphraseNumber = true;

  // PIN options
  double _pinLength = 6;

  String _generatedSecret = '';

  @override
  void initState() {
    super.initState();
    AccentColorService.currentColor.addListener(_onAccentColorChanged);
    _regenerate();
  }

  void _onAccentColorChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AccentColorService.currentColor.removeListener(_onAccentColorChanged);
    super.dispose();
  }

  void _regenerate() {
    String result = '';
    switch (_mode) {
      case GeneratorMode.password:
        result = GeneratorService.generatePassword(
          length: _passwordLength.round(),
          includeUppercase: _includeUpper,
          includeLowercase: _includeLower,
          includeDigits: _includeDigits,
          includeSymbols: _includeSymbols,
          excludeAmbiguous: _excludeAmbiguous,
        );
        break;
      case GeneratorMode.passphrase:
        result = GeneratorService.generatePassphrase(
          wordCount: _wordCount.round(),
          separator: _separator,
          capitalize: _capitalizePassphrase,
          includeNumber: _includePassphraseNumber,
        );
        break;
      case GeneratorMode.pin:
        result = GeneratorService.generatePIN(
          length: _pinLength.round(),
        );
        break;
    }
    setState(() => _generatedSecret = result);
  }

  double get _secretFontSize {
    final len = _generatedSecret.length;
    if (len <= 12) return 22;
    if (len <= 18) return 18;
    if (len <= 26) return 15;
    if (len <= 34) return 13;
    return 11.5;
  }

  @override
  Widget build(BuildContext context) {
    final activeAccent = Theme.of(context).colorScheme.primary;

    return ValueListenableBuilder<Color>(
      valueListenable: AccentColorService.currentColor,
      builder: (context, accentColor, _) {
        return Scaffold(
          backgroundColor: AppColors.backgroundZinc,
          appBar: VaultAppBar(
            leading: IconButton(
              icon: const AppIcon(AppIcons.arrowLeft,
                  color: AppColors.offWhite, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            title: '',
          ),
          body: Column(
            children: [
              // 1. Pinned 100% full-width header (same process as bundle view)
              _buildGeneratorHeader(activeAccent),
              // 2. Scrollable generator content (swipe horizontally to switch tabs)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (details) {
                    final dx = details.velocity.pixelsPerSecond.dx;
                    if (dx < -350) {
                      _swipeMode(1);
                    } else if (dx > 350) {
                      _swipeMode(-1);
                    }
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mode Selector Segmented Pill Bar
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceZinc,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.borderZinc
                                    .withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              _buildModeOption(
                                mode: GeneratorMode.password,
                                label: 'Password',
                                icon: HugeIcons.strokeRoundedLock,
                                activeAccent: activeAccent,
                              ),
                              _buildModeOption(
                                mode: GeneratorMode.passphrase,
                                label: 'Passphrase',
                                icon: HugeIcons.strokeRoundedText,
                                activeAccent: activeAccent,
                              ),
                              _buildModeOption(
                                mode: GeneratorMode.pin,
                                label: 'PIN',
                                icon: HugeIcons.strokeRoundedPinCode,
                                activeAccent: activeAccent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Generated Output Box
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceZinc,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.borderZinc,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'GENERATED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const AppIcon(
                                        HugeIcons.strokeRoundedRefresh,
                                        size: 18,
                                        color: AppColors.textMuted),
                                    tooltip: 'Regenerate',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      _regenerate();
                                    },
                                  ),
                                  IconButton(
                                    icon: AppIcon(HugeIcons.strokeRoundedCopy01,
                                        size: 18, color: activeAccent),
                                    tooltip: 'Copy',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      ref
                                          .read(lockServiceProvider)
                                          .copySecret(_generatedSecret);
                                      HapticFeedback.selectionClick();
                                      AppToast.show(
                                        context,
                                        message: 'Copied to clipboard',
                                        type: ToastType.success,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              Container(
                                constraints:
                                    const BoxConstraints(minHeight: 48),
                                alignment: Alignment.center,
                                child: SelectableText(
                                  _generatedSecret,
                                  style: TextStyle(
                                    fontSize: _secretFontSize,
                                    fontFamily: 'Monospace',
                                    fontWeight: FontWeight.bold,
                                    color: activeAccent,
                                    letterSpacing:
                                        _mode == GeneratorMode.pin ? 3.5 : 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Real-Time Strength Meter
                              PasswordStrengthMeter(
                                password: _generatedSecret,
                                compact: true,
                                showRecommendation: false,
                              ),

                              const SizedBox(height: 12),
                              AppButton(
                                icon: HugeIcons.strokeRoundedCopy01,
                                label: 'Copy Password',
                                fontSize: 13.5,
                                fullWidth: true,
                                height: 44,
                                onPressed: () {
                                  ref
                                      .read(lockServiceProvider)
                                      .copySecret(_generatedSecret);
                                  HapticFeedback.selectionClick();
                                  AppToast.show(
                                    context,
                                    message: 'Copied to clipboard',
                                    type: ToastType.success,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Dynamic Options based on selected Mode
                        if (_mode == GeneratorMode.password) ...[
                          _buildSliderRow(
                            title: 'Length',
                            value: '${_passwordLength.round()} chars',
                            activeAccent: activeAccent,
                          ),
                          Slider(
                            value: _passwordLength,
                            min: 6,
                            max: 64,
                            activeColor: activeAccent,
                            onChanged: (val) {
                              setState(() => _passwordLength = val);
                              _regenerate();
                            },
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceZinc,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.borderZinc
                                      .withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              children: [
                                _buildElementToggle(
                                  icon:
                                      HugeIcons.strokeRoundedArrangeByLettersAZ,
                                  label: 'A–Z',
                                  description: 'Uppercase letters',
                                  value: _includeUpper,
                                  activeAccent: activeAccent,
                                  onChanged: (v) {
                                    setState(() => _includeUpper = v);
                                    _regenerate();
                                  },
                                ),
                                _toggleDivider(),
                                _buildElementToggle(
                                  icon:
                                      HugeIcons.strokeRoundedArrangeByLettersZA,
                                  label: 'a–z',
                                  description: 'Lowercase letters',
                                  value: _includeLower,
                                  activeAccent: activeAccent,
                                  onChanged: (v) {
                                    setState(() => _includeLower = v);
                                    _regenerate();
                                  },
                                ),
                                _toggleDivider(),
                                _buildElementToggle(
                                  icon:
                                      HugeIcons.strokeRoundedArrangeByNumbers19,
                                  label: '0–9',
                                  description: 'Numbers',
                                  value: _includeDigits,
                                  activeAccent: activeAccent,
                                  onChanged: (v) {
                                    setState(() => _includeDigits = v);
                                    _regenerate();
                                  },
                                ),
                                _toggleDivider(),
                                _buildElementToggle(
                                  icon: HugeIcons.strokeRoundedAsterisk,
                                  label: '!#\$',
                                  description: 'Symbols',
                                  value: _includeSymbols,
                                  activeAccent: activeAccent,
                                  onChanged: (v) {
                                    setState(() => _includeSymbols = v);
                                    _regenerate();
                                  },
                                ),
                                _toggleDivider(),
                                _buildElementToggle(
                                  icon: HugeIcons.strokeRoundedBlocked,
                                  label: 'Safe',
                                  description:
                                      'Exclude ambiguous (l, 1, I, O, 0)',
                                  value: _excludeAmbiguous,
                                  activeAccent: activeAccent,
                                  onChanged: (v) {
                                    setState(() => _excludeAmbiguous = v);
                                    _regenerate();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ] else if (_mode == GeneratorMode.passphrase) ...[
                          _buildSliderRow(
                            title: 'Word Count',
                            value: '${_wordCount.round()} words',
                            activeAccent: activeAccent,
                          ),
                          Slider(
                            value: _wordCount,
                            min: 3,
                            max: 8,
                            divisions: 5,
                            activeColor: activeAccent,
                            onChanged: (val) {
                              setState(() => _wordCount = val);
                              _regenerate();
                            },
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                const Text(
                                  'SEPARATOR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const Spacer(),
                                for (final sep in ['-', '.', '_', ' '])
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _separator = sep);
                                      _regenerate();
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      width: 40,
                                      height: 32,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        gradient: _separator == sep
                                            ? LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  activeAccent,
                                                  AppColors.shade(
                                                      activeAccent, -0.08),
                                                ],
                                              )
                                            : null,
                                        color: _separator == sep
                                            ? null
                                            : AppColors.surfaceZinc,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _separator == sep
                                              ? AppColors.orangeDark
                                              : AppColors.borderZinc,
                                          width: 1,
                                        ),
                                        boxShadow: _separator == sep
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.shade(
                                                      activeAccent, -0.18),
                                                  offset: const Offset(0, 2.5),
                                                  blurRadius: 0,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        sep == ' ' ? 'SPC' : sep,
                                        style: TextStyle(
                                          color: _separator == sep
                                              ? Colors.white
                                              : AppColors.offWhite,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceZinc,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.borderZinc
                                      .withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              children: [
                                _buildElementToggle(
                                  icon: HugeIcons.strokeRoundedTextFont,
                                  label: 'Title Case',
                                  description: 'Capitalize each word',
                                  value: _capitalizePassphrase,
                                  activeAccent: activeAccent,
                                  onChanged: (v) {
                                    setState(() => _capitalizePassphrase = v);
                                    _regenerate();
                                  },
                                ),
                                _toggleDivider(),
                                _buildElementToggle(
                                  icon:
                                      HugeIcons.strokeRoundedArrangeByNumbers19,
                                  label: 'Numbers',
                                  description: 'Append trailing numbers',
                                  value: _includePassphraseNumber,
                                  activeAccent: activeAccent,
                                  onChanged: (v) {
                                    setState(
                                        () => _includePassphraseNumber = v);
                                    _regenerate();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ] else if (_mode == GeneratorMode.pin) ...[
                          _buildSliderRow(
                            title: 'PIN Digits',
                            value: '${_pinLength.round()} digits',
                            activeAccent: activeAccent,
                          ),
                          Slider(
                            value: _pinLength,
                            min: 4,
                            max: 12,
                            divisions: 8,
                            activeColor: activeAccent,
                            onChanged: (val) {
                              setState(() => _pinLength = val);
                              _regenerate();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Swipe horizontally across generator tabs (Password ↔ Passphrase ↔ PIN).
  void _swipeMode(int direction) {
    const modes = GeneratorMode.values;
    final next = (_mode.index + direction) % modes.length;
    final target = modes[next < 0 ? next + modes.length : next];
    if (target == _mode) return;
    HapticFeedback.selectionClick();
    setState(() => _mode = target);
    _regenerate();
  }

  String get _modeLabel {
    switch (_mode) {
      case GeneratorMode.password:
        return 'Password';
      case GeneratorMode.passphrase:
        return 'Passphrase';
      case GeneratorMode.pin:
        return 'PIN';
    }
  }

  String get _modeSizeLabel {
    switch (_mode) {
      case GeneratorMode.password:
        return '${_passwordLength.round()} chars';
      case GeneratorMode.passphrase:
        return '${_wordCount.round()} words';
      case GeneratorMode.pin:
        return '${_pinLength.round()} digits';
    }
  }

  /// Pinned 100% full-width header — same process as the bundle view:
  /// cutout icon + title + metric pills over a bottom-bordered surface.
  Widget _buildGeneratorHeader(Color activeAccent) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceZinc,
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderZinc.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Transparent 3D cutout icon (no background color container)
          Image.asset(
            'assets/icons/cutouts_dark/password-generator.png',
            width: 44,
            height: 44,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => AppIcon(
              HugeIcons.strokeRoundedKey01,
              size: 32,
              color: activeAccent,
            ),
          ),
          const SizedBox(width: 12),
          // Title + pills
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Password Generator',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.offWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Pill 1: current mode + size
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: activeAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: activeAccent.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '$_modeLabel • $_modeSizeLabel',
                        style: TextStyle(
                          color: activeAccent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    // Pill 2: offline guarantee
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.cardZinc,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.borderZinc.withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(
                            HugeIcons.strokeRoundedShield01,
                            size: 10,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'OFFLINE',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

  Widget _buildModeOption({
    required GeneratorMode mode,
    required String label,
    required dynamic icon,
    required Color activeAccent,
  }) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _mode = mode);
          _regenerate();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      activeAccent,
                      AppColors.shade(activeAccent, -0.08),
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.orangeDark : Colors.transparent,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.shade(activeAccent, -0.18),
                      offset: const Offset(0, 2.5),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 52,
      color: AppColors.borderZinc.withValues(alpha: 0.4),
    );
  }

  Widget _buildElementToggle({
    required dynamic icon,
    required String label,
    required String description,
    required bool value,
    required Color activeAccent,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            AppIcon(icon,
                size: 18, color: value ? activeAccent : AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.offWhite,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              activeColor: activeAccent,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String title,
    required String value,
    required Color activeAccent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.offWhite,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: activeAccent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.orangeDark),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
