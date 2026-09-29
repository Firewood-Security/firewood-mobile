// screens/credential_view_screen.dart
// Credential detail page inside an unlocked session.
//
// Auth policy: opening this page NEVER re-prompts — the vault unlock at
// login is the session's one authentication and browsing is free. Only
// critical actions re-verify via ReauthService: revealing or copying a
// sensitive field (masked password reads) and entering edit (overriding
// the credential). One verification covers the rest of the visit.

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item_type.dart';
import '../services/item_service.dart';
import '../services/lock_service.dart';
import '../services/reauth_service.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/airshare_modal.dart';
import '../widgets/vault_components.dart';
import '../theme/app_button.dart';
import 'item_detail_screen.dart';

class CredentialViewScreen extends ConsumerStatefulWidget {
  final SecretKey secretKey;
  final ItemService itemService;
  final DecryptedItem item;

  const CredentialViewScreen({
    super.key,
    required this.secretKey,
    required this.itemService,
    required this.item,
  });

  @override
  ConsumerState<CredentialViewScreen> createState() =>
      _CredentialViewScreenState();
}

class _CredentialViewScreenState extends ConsumerState<CredentialViewScreen>
    with SingleTickerProviderStateMixin {
  late DecryptedItem _currentItem;

  // One re-verification covers every critical action of this visit
  // (reveal, sensitive copy, edit) — browsing never re-prompts.
  bool _reauthedThisVisit = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final Set<String> _revealedFields = {};

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Critical-action gate: re-verify once per visit via ReauthService.
  Future<bool> _confirmCritical(String reason) async {
    if (_reauthedThisVisit) return true;
    final ok = await ReauthService.confirm(context, reason: reason);
    if (ok && mounted) _reauthedThisVisit = true;
    return ok && mounted;
  }

  Future<void> _openEditScreen() async {
    if (!await _confirmCritical('Authenticate to edit this credential')) {
      return;
    }
    if (!mounted) return;
    final nav = Navigator.of(context);

    await nav.push(
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(
          secretKey: widget.secretKey,
          itemService: widget.itemService,
          existingItem: _currentItem,
        ),
      ),
    );

    // Refresh current item after edit
    try {
      final items = await widget.itemService.getAllItems(widget.secretKey);
      final updated = items.firstWhere(
        (it) => it.itemId == _currentItem.itemId,
        orElse: () => _currentItem,
      );
      if (mounted) {
        setState(() {
          _currentItem = updated;
        });
      }
    } catch (_) {}
  }

  Future<void> _copyToClipboard(String label, String value,
      {bool sensitive = false}) async {
    if (value.isEmpty) return;
    if (sensitive && !await _confirmCritical('Authenticate to copy $label')) {
      return;
    }
    if (!mounted) return;
    ref.read(lockServiceProvider).copySecret(value);
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const AppIcon(AppIcons.checkCircle,
                color: Colors.greenAccent, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Copied $label (clears in 30s)')),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showImageDialog(String base64Image) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenImageViewer(base64Image: base64Image),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemType = ItemTypeExt.fromString(_currentItem.type);

    return Scaffold(
      backgroundColor: AppColors.backgroundZinc,
      appBar: VaultAppBar(
        title: _currentItem.title,
        actions: [
          IconButton(
            icon: const AppIcon(HugeIcons.strokeRoundedShare08, size: 20),
            tooltip: 'AirShare',
            onPressed: () => AirShareModal.show(
              context,
              item: _currentItem,
              role: AirShareRole.send,
            ),
          ),
          IconButton(
            icon: const AppIcon(HugeIcons.strokeRoundedEdit01, size: 20),
            tooltip: 'Edit Credential',
            onPressed: _openEditScreen,
          ),
        ],
      ),
      body: _buildCredentialDetails(itemType),
    );
  }

  Widget _buildCredentialDetails(ItemType itemType) {
    final fields = Map<String, dynamic>.from(_currentItem.fields);
    final String? idImage = fields.remove('id_image')?.toString();
    final String? bundleName = fields.remove('bundle')?.toString().trim();
    // Exclude metadata timestamps since they are shown exclusively in the Metadata section
    fields.removeWhere((k, _) {
      final clean = k.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
      return clean == 'createdat' ||
          clean == 'updatedat' ||
          clean == 'timestamp';
    });

    final activeAccent = Theme.of(context).colorScheme.primary;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Refined 100% Full-Width Header with transparent 3D icon & value-only metric badge
          Container(
            width: double.infinity,
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                // Transparent 3D Cutout Icon (No background color container)
                Image.asset(
                  _getItemCutoutPath(itemType),
                  width: 52,
                  height: 52,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => AppIcon(
                    _getTypeIcon(itemType),
                    size: 38,
                    color: activeAccent,
                  ),
                ),
                const SizedBox(width: 14),
                // Item details (Title + Category/Bundle value-only metric badges)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentItem.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.offWhite,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: activeAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: activeAccent.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              itemType.label.toUpperCase(),
                              style: TextStyle(
                                color: activeAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (bundleName != null && bundleName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.cardZinc,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.borderZinc
                                      .withValues(alpha: 0.6),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const HugeIcon(
                                    icon: HugeIcons.strokeRoundedFolder01,
                                    size: 11,
                                    color: AppColors.textMuted,
                                    strokeWidth: 2,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    bundleName.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
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
          ),

          // Scrollable fields below header
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // Quick Action Bar (minimalist: only Copy Username & Copy Password if available — no duplicate Edit button)
                if (fields.containsKey('username') ||
                    fields.containsKey('password')) ...[
                  Row(
                    children: [
                      if (fields.containsKey('username'))
                        Expanded(
                          child: AppButton(
                            onPressed: () => _copyToClipboard(
                                'Username', fields['username'].toString()),
                            icon: HugeIcons.strokeRoundedUser,
                            label: 'Copy User',
                            variant: AppButtonVariant.secondary,
                            height: 38,
                            fontSize: 12,
                          ),
                        ),
                      if (fields.containsKey('username') &&
                          fields.containsKey('password'))
                        const SizedBox(width: 10),
                      if (fields.containsKey('password'))
                        Expanded(
                          child: AppButton(
                            onPressed: () => _copyToClipboard(
                                'Password', fields['password'].toString(),
                                sensitive: true),
                            icon: HugeIcons.strokeRoundedCopy01,
                            label: 'Copy Password',
                            variant: AppButtonVariant.primary,
                            height: 38,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // ID Document Image preview if present
                if (idImage != null) ...[
                  Text(
                    'IDENTITY DOCUMENT ATTACHMENT',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _showImageDialog(idImage),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceZinc,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderZinc),
                      ),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Image.memory(
                            base64Decode(idImage),
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcon(AppIcons.search,
                                    color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text('Tap to expand',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                const Text(
                  'DECRYPTED CREDENTIALS',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Stored fields
                ...fields.entries.map((entry) {
                  final key = entry.key;
                  final val = entry.value.toString();
                  final isSensitive = key.toLowerCase().contains('password') ||
                      key.toLowerCase().contains('cvv') ||
                      key.toLowerCase().contains('pin') ||
                      key.toLowerCase().contains('secret') ||
                      key.toLowerCase().contains('id_number');
                  final isRevealed = _revealedFields.contains(key);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceZinc,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderZinc.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                key.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMuted,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const Spacer(),
                              if (isSensitive)
                                IconButton(
                                  icon: AppIcon(
                                    isRevealed
                                        ? AppInputIcons.eyeOff
                                        : AppInputIcons.eye,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () async {
                                    if (!isRevealed &&
                                        !await _confirmCritical(
                                            'Authenticate to reveal $key')) {
                                      return;
                                    }
                                    if (!mounted) return;
                                    setState(() {
                                      if (isRevealed) {
                                        _revealedFields.remove(key);
                                      } else {
                                        _revealedFields.add(key);
                                      }
                                    });
                                  },
                                ),
                              IconButton(
                                icon: AppIcon(AppInputIcons.copy,
                                    size: 18, color: AppColors.orangeAccent),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _copyToClipboard(key, val,
                                    sensitive: isSensitive),
                                tooltip: 'Copy $key',
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            isSensitive && !isRevealed
                                ? '••••••••••••••••'
                                : val,
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: isSensitive && !isRevealed
                                  ? null
                                  : 'Monospace',
                              fontWeight: FontWeight.w600,
                              color: AppColors.offWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 12),
                const Text(
                  'METADATA & TIMESTAMPS',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceZinc,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.borderZinc.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const AppIcon(AppIcons.calendar,
                              size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          const Text('Created At',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textMuted)),
                          const Spacer(),
                          Text(_formatDateTime(_currentItem.createdAt),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.offWhite,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: AppColors.borderZinc, height: 1),
                      ),
                      Row(
                        children: [
                          const AppIcon(AppIcons.history,
                              size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          const Text('Last Updated',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textMuted)),
                          const Spacer(),
                          Text(_formatDateTime(_currentItem.updatedAt),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.orangeAccent,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final year = dt.year;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour =
        (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$year-$month-$day  $hour:$minute $ampm';
  }

  dynamic _getTypeIcon(ItemType type) {
    switch (type) {
      case ItemType.login:
        return AppIcons.typeLogin;
      case ItemType.card:
        return AppIcons.typeCard;
      case ItemType.identity:
        return AppIcons.typeIdentity;
      case ItemType.note:
        return AppIcons.typeNote;
      case ItemType.developerSecret:
        return AppIcons.typeDeveloperSecret;
    }
  }

  String _getItemCutoutPath(ItemType type) {
    switch (type) {
      case ItemType.login:
        return 'assets/icons/cutouts_dark/user-login.png';
      case ItemType.card:
        return 'assets/icons/cutouts_dark/credit-card.png';
      case ItemType.identity:
        return 'assets/icons/cutouts_dark/passport.png';
      case ItemType.note:
        return 'assets/icons/cutouts_dark/secure-note.png';
      case ItemType.developerSecret:
        return 'assets/icons/cutouts_dark/api-key.png';
    }
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  final String base64Image;
  const _FullscreenImageViewer({required this.base64Image});

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
      HapticFeedback.lightImpact();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        elevation: 0,
        leading: IconButton(
          icon: const AppIcon(AppIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Identity Document Preview',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const AppIcon(HugeIcons.strokeRoundedRefresh,
                color: Colors.white70),
            tooltip: 'Reset Zoom',
            onPressed: () {
              _transformationController.value = Matrix4.identity();
              HapticFeedback.selectionClick();
            },
          ),
        ],
      ),
      body: GestureDetector(
        onDoubleTapDown: (details) => _doubleTapDetails = details,
        onDoubleTap: _handleDoubleTap,
        child: Center(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1.0,
            maxScale: 4.0,
            child: Image.memory(
              base64Decode(widget.base64Image),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      ),
    );
  }
}
