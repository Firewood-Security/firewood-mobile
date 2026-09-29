// widgets/vault_components.dart
// Production-grade reusable component primitives for the Dark Zinc Technical Vault Design System

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../services/reauth_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/vault_design_system.dart';
import '../models/item_type.dart';
import '../services/item_service.dart';

// --- 0. HOME NAVBAR (flat dark bar, logo only) ---
class CurvedNavbarSeparator extends StatelessWidget
    implements PreferredSizeWidget {
  final Widget? leading;
  final List<Widget>? actions;
  final Color backgroundColor;

  const CurvedNavbarSeparator({
    super.key,
    this.leading,
    this.actions,
    this.backgroundColor = AppColors.backgroundZinc,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final totalHeight = kToolbarHeight + topPadding;
    // Logo fills 72% of the usable toolbar height, capped for visual balance
    final logoSize = (kToolbarHeight * 0.72).clamp(28.0, 44.0);

    return Container(
      height: totalHeight,
      color: backgroundColor,
      child: Stack(
        children: [
          // Content layer
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // LEFT: leading (if any) + logo only — no text
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (leading != null) leading!,
                        Image.asset(
                          'assets/FWS.png',
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                    // RIGHT: action buttons
                    if (actions != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actions!,
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

// --- 1. VAULT APP BAR ---
class VaultAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showLogo;

  const VaultAppBar({
    super.key,
    this.title = '',
    this.leading,
    this.actions,
    this.showLogo = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (showLogo) {
      return CurvedNavbarSeparator(
        leading: leading,
        actions: actions,
      );
    }

    return AppBar(
      backgroundColor: AppColors.surfaceZinc,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading,
      centerTitle: false,
      title: Text(
        title,
        style: GoogleFonts.syncopate(
          textStyle: const TextStyle(
            color: AppColors.offWhite,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: actions,
    );
  }
}

// --- 2. VAULT SECTION LABEL ---
class VaultSectionLabel extends StatelessWidget {
  final String label;
  final EdgeInsetsGeometry padding;

  const VaultSectionLabel(
    this.label, {
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        label.toUpperCase(),
        style: VaultTypography.sectionLabel,
      ),
    );
  }
}

// --- 3. VAULT METRIC CARD ---
class VaultMetricCard extends StatefulWidget {
  final String label;
  final String value;
  final String unit;
  final Color accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onHold3Seconds;
  final bool showAlertDot;

  const VaultMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.accentColor,
    this.onTap,
    this.onHold3Seconds,
    this.showAlertDot = false,
  });

  @override
  State<VaultMetricCard> createState() => _VaultMetricCardState();
}

class _VaultMetricCardState extends State<VaultMetricCard> {
  Timer? _holdTimer;
  bool _holdTriggered = false;

  void _startHoldTimer() {
    if (widget.onHold3Seconds == null) return;
    _holdTriggered = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _holdTriggered = true;
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.vibrate();
      });
      widget.onHold3Seconds!();
    });
  }

  void _cancelHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceZinc,
          borderRadius: BorderRadius.circular(VaultRadii.lg),
          border: VaultBorders.allSubtle(opacity: 0.6),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(VaultRadii.lg),
            onTapDown: (_) => _startHoldTimer(),
            onTapUp: (_) => _cancelHoldTimer(),
            onTapCancel: () => _cancelHoldTimer(),
            onTap: widget.onTap != null
                ? () {
                    if (!_holdTriggered) {
                      HapticFeedback.lightImpact();
                      widget.onTap!();
                    }
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(widget.label.toUpperCase(),
                            style: VaultTypography.sectionLabel),
                      ),
                      if (widget.showAlertDot)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.accentColor,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(widget.value,
                          style:
                              VaultTypography.metricValue(widget.accentColor)),
                      const SizedBox(width: 4),
                      Text(widget.unit, style: VaultTypography.meta),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- 4. VAULT CATEGORY CARD (Matte finish 3D icon container with dark icon font) ---
class VaultCategoryCard extends StatefulWidget {
  final String title;
  final String count;
  final String subtitle;
  final dynamic icon;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback? onHold3Seconds;

  const VaultCategoryCard({
    super.key,
    required this.title,
    required this.count,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.onHold3Seconds,
  });

  @override
  State<VaultCategoryCard> createState() => _VaultCategoryCardState();
}

class _VaultCategoryCardState extends State<VaultCategoryCard> {
  Timer? _holdTimer;
  bool _holdTriggered = false;

  void _startHoldTimer() {
    if (widget.onHold3Seconds == null) return;
    _holdTriggered = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _holdTriggered = true;
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.vibrate();
      });
      widget.onHold3Seconds!();
    });
  }

  void _cancelHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceZinc,
        borderRadius: BorderRadius.circular(VaultRadii.lg),
        border: Border.all(
          color: AppColors.borderZinc.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(VaultRadii.lg),
          onTapDown: (_) => _startHoldTimer(),
          onTapUp: (_) => _cancelHoldTimer(),
          onTapCancel: () => _cancelHoldTimer(),
          onTap: () {
            if (!_holdTriggered) {
              HapticFeedback.lightImpact();
              widget.onTap();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Transparent container for 3D light cutouts
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: widget.icon is String
                            ? Image.asset(
                                widget.icon as String,
                                width: 42,
                                height: 42,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => AppIcon(
                                  widget.icon,
                                  size: 28,
                                  color: widget.accentColor,
                                ),
                              )
                            : AppIcon(
                                widget.icon,
                                size: 28,
                                color: widget.accentColor,
                              ),
                      ),
                    ),
                    Text(
                      widget.count,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: widget.accentColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.offWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- HOLD 3 SECONDS DETECTOR FOR AIRSHARE SHORTCUT ---
class HoldToAirshareDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onHold3Seconds;

  const HoldToAirshareDetector({
    super.key,
    required this.child,
    required this.onTap,
    required this.onHold3Seconds,
  });

  @override
  State<HoldToAirshareDetector> createState() => _HoldToAirshareDetectorState();
}

class _HoldToAirshareDetectorState extends State<HoldToAirshareDetector> {
  Timer? _holdTimer;
  bool _holdTriggered = false;

  void _startTimer() {
    _holdTriggered = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _holdTriggered = true;
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.vibrate();
      });
      widget.onHold3Seconds();
    });
  }

  void _cancelTimer() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startTimer(),
      onTapUp: (_) {
        _cancelTimer();
        if (!_holdTriggered) {
          HapticFeedback.lightImpact();
          widget.onTap();
        }
      },
      onTapCancel: _cancelTimer,
      child: widget.child,
    );
  }
}

// --- 5. VAULT CREDENTIAL TILE (Scannable, dense, responsive) ---
class VaultCredentialTile extends StatefulWidget {
  final DecryptedItem item;
  final Color accentColor;
  final VoidCallback onTap;
  final bool showDate;

  const VaultCredentialTile({
    super.key,
    required this.item,
    required this.accentColor,
    required this.onTap,
    this.showDate = false,
  });

  @override
  State<VaultCredentialTile> createState() => _VaultCredentialTileState();
}

class _VaultCredentialTileState extends State<VaultCredentialTile> {
  bool _isPasswordRevealed = false;
  int _countdownSeconds = 10;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isPasswordRevealed = true;
      _countdownSeconds = 10;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _isPasswordRevealed = false;
          _countdownSeconds = 10;
        });
      } else {
        setState(() {
          _countdownSeconds--;
        });
      }
    });
  }

  void _hidePassword() {
    _countdownTimer?.cancel();
    setState(() {
      _isPasswordRevealed = false;
      _countdownSeconds = 10;
    });
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  dynamic _getTypeIcon(ItemType type) {
    switch (type) {
      case ItemType.login:
        return AppIcons.categoryLogin;
      case ItemType.card:
        return AppIcons.categoryCard;
      case ItemType.identity:
        return AppIcons.categoryIdentity;
      case ItemType.note:
        return AppIcons.categoryNote;
      case ItemType.developerSecret:
        return AppIcons.key;
    }
  }

  Future<void> _togglePasswordReveal() async {
    HapticFeedback.lightImpact();
    if (_isPasswordRevealed) {
      _hidePassword();
      return;
    }

    final authenticated = await ReauthService.confirm(
      context,
      reason: 'Authenticate to reveal password for 10 seconds',
    );

    if (authenticated && mounted) {
      HapticFeedback.mediumImpact();
      _startCountdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = ItemTypeExt.fromString(widget.item.type);

    final rawSecret = widget.item.fields['password']?.toString() ??
        widget.item.fields['cvv']?.toString() ??
        widget.item.fields['secret_key']?.toString() ??
        widget.item.fields['pin']?.toString() ??
        '';

    final subtitle = widget.item.fields['username']?.toString() ??
        widget.item.fields['cardholder']?.toString() ??
        widget.item.fields['key_name']?.toString() ??
        '';

    final hasSecret = rawSecret.isNotEmpty;
    final displaySecret = _isPasswordRevealed ? rawSecret : '••••••••••••';

    final hasTotp =
        (widget.item.fields['totp_secret'] ?? '').toString().trim().isNotEmpty;
    final bundleName = (widget.item.fields['bundle'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF15151B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.borderZinc.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title strip: type badge + title + badges
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A22),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.borderZinc.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: widget.accentColor.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcon(_getTypeIcon(type),
                                size: 11, color: widget.accentColor),
                            const SizedBox(width: 4),
                            Text(
                              type.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: widget.accentColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.item.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.offWhite,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (bundleName.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.cardZinc,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.borderZinc),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIcon(HugeIcons.strokeRoundedFolder01,
                                  size: 10, color: AppColors.orangeAccent),
                              const SizedBox(width: 3),
                              Text(
                                bundleName,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (hasTotp) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '2FA',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: widget.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Content section: identifier + secret
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              AppIcon(
                                type == ItemType.card
                                    ? HugeIcons.strokeRoundedCreditCard
                                    : (type == ItemType.identity
                                        ? HugeIcons.strokeRoundedId
                                        : HugeIcons.strokeRoundedUser),
                                size: 12,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                type == ItemType.card
                                    ? 'Card: '
                                    : (type == ItemType.identity
                                        ? 'ID: '
                                        : 'User: '),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.offWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          const AppIcon(
                            AppIcons.lock,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            type == ItemType.card
                                ? 'CVV: '
                                : (type == ItemType.developerSecret
                                    ? 'Secret: '
                                    : 'Pass: '),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: hasSecret ? _togglePasswordReveal : null,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  displaySecret,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _isPasswordRevealed
                                        ? widget.accentColor
                                        : AppColors.textMuted,
                                    fontSize: 12,
                                    fontFamily: _isPasswordRevealed
                                        ? 'monospace'
                                        : null,
                                    letterSpacing:
                                        _isPasswordRevealed ? 0.3 : 1.4,
                                    fontWeight: _isPasswordRevealed
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_isPasswordRevealed)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _togglePasswordReveal,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                margin: const EdgeInsets.only(left: 6),
                                decoration: BoxDecoration(
                                  color: widget.accentColor
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: widget.accentColor
                                        .withValues(alpha: 0.5),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  '${_countdownSeconds}s',
                                  style: TextStyle(
                                    color: widget.accentColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: AppIcon(AppIcons.chevronRight,
                                  color: AppColors.textMuted, size: 16),
                            ),
                        ],
                      ),
                      if (widget.showDate) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            AppIcon(AppIcons.time,
                                size: 11,
                                color:
                                    AppColors.textMuted.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(
                              'Updated: ${_formatDate(widget.item.updatedAt)}',
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    AppColors.textMuted.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- 6. VAULT HERO HEADER (100% Full-width header, no side padding/borders) ---
class VaultHeroHeader extends StatelessWidget {
  final Widget titleContent;
  final Widget child;
  final Color accentColor;

  const VaultHeroHeader({
    super.key,
    required this.titleContent,
    required this.child,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: const BoxDecoration(
        color: AppColors.surfaceZinc,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(VaultRadii.xl),
        ),
      ),
      child: Column(
        children: [
          titleContent,
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// --- 7. VAULT TOOL BUTTON (Modern 4-column grid tile) ---
class VaultToolButton extends StatelessWidget {
  final String label;
  final dynamic icon;
  final Color accentColor;
  final VoidCallback onTap;

  const VaultToolButton({
    super.key,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double iconSize = 40.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceZinc,
        borderRadius: BorderRadius.circular(VaultRadii.lg),
        border: Border.all(
          color: AppColors.borderZinc.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(VaultRadii.lg),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: icon is String
                      ? Image.asset(
                          icon as String,
                          width: iconSize,
                          height: iconSize,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => AppIcon(
                            icon,
                            size: 26,
                            color: accentColor,
                          ),
                        )
                      : AppIcon(
                          icon,
                          size: 26,
                          color: accentColor,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.offWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- 8. VAULT FILTER CHIP ---
class VaultFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color activeAccent;
  final VoidCallback onTap;

  const VaultFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.activeAccent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeAccent.withValues(alpha: 0.15)
              : AppColors.surfaceZinc,
          borderRadius: BorderRadius.circular(VaultRadii.md),
          border: Border.all(
            color: isSelected
                ? activeAccent
                : AppColors.borderZinc.withValues(alpha: 0.6),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeAccent : AppColors.textMuted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
