// screens/bundle_detail_screen.dart
// Distinctive, modern Bundle Dossier screen designed specifically for multi-credential bundles

import 'dart:async';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../services/reauth_service.dart';

import '../models/item_type.dart';
import '../services/bundle_service.dart';
import '../services/csv_import_service.dart';
import '../services/item_service.dart';
import '../services/lock_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/airshare_modal.dart';
import '../widgets/bundle_settings_sheet.dart';
import '../widgets/vault_components.dart';
import 'credential_view_screen.dart';
import 'item_detail_screen.dart';

class BundleDetailScreen extends ConsumerStatefulWidget {
  final SecretKey secretKey;
  final String bundleName;

  const BundleDetailScreen({
    super.key,
    required this.secretKey,
    required this.bundleName,
  });

  @override
  ConsumerState<BundleDetailScreen> createState() => _BundleDetailScreenState();
}

class _BundleDetailScreenState extends ConsumerState<BundleDetailScreen> {
  final ItemService _itemService = ItemService();
  final TextEditingController _searchController = TextEditingController();

  late String _currentBundle;
  String _searchQuery = '';
  ItemType? _selectedTypeFilter;
  List<DecryptedItem> _bundleItems = [];

  @override
  void initState() {
    super.initState();
    _currentBundle = widget.bundleName;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openBundleSettings() {
    BundleSettingsSheet.show(
      context: context,
      secretKey: widget.secretKey,
      bundleName: _currentBundle,
      items: _bundleItems,
      onRenamed: (newName) {
        setState(() {
          _currentBundle = newName;
        });
      },
      onEmptied: () {
        setState(() {});
      },
      onDeleted: () {
        Navigator.pop(context);
      },
    );
  }

  Future<void> _addItemToBundle() async {
    HapticFeedback.lightImpact();
    final res = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(
          secretKey: widget.secretKey,
          itemService: _itemService,
          initialBundle: _currentBundle,
        ),
      ),
    );
    if (res == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _importCsvToBundle() async {
    HapticFeedback.lightImpact();
    final result = await CsvImportService().pickAndImportCsv(
      context: context,
      secretKey: widget.secretKey,
      targetBundle: _currentBundle,
    );
    if (result != null && result.importedCount > 0 && mounted) {
      setState(() {});
    }
  }

  Future<void> _viewItem(DecryptedItem item) async {
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CredentialViewScreen(
          secretKey: widget.secretKey,
          itemService: _itemService,
          item: item,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundZinc,
      appBar: VaultAppBar(
        title: _currentBundle,
        leading: IconButton(
          icon: const AppIcon(AppIcons.arrowLeft,
              color: AppColors.offWhite, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Import CSV into Bundle',
            icon: const AppIcon(HugeIcons.strokeRoundedFileImport,
                color: AppColors.offWhite, size: 20),
            onPressed: _importCsvToBundle,
          ),
          IconButton(
            tooltip: 'Bundle Settings',
            icon: const AppIcon(HugeIcons.strokeRoundedSettings01,
                color: AppColors.offWhite, size: 20),
            onPressed: _openBundleSettings,
          ),
          IconButton(
            tooltip: 'Add Credential to Bundle',
            icon:
                AppIcon(AppIcons.add, color: AppColors.orangeAccent, size: 22),
            onPressed: _addItemToBundle,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<List<DecryptedItem>>(
        future: _itemService.getAllItems(widget.secretKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.orangeAccent),
            );
          }

          final allItems = snapshot.data ?? [];
          _bundleItems = allItems
              .where((i) =>
                  (i.fields['bundle'] ?? '').toString().trim().toLowerCase() ==
                  _currentBundle.toLowerCase())
              .toList();

          // Auto-purge if bundle is empty and automatically pop back to home
          if (_bundleItems.isEmpty &&
              snapshot.connectionState != ConnectionState.waiting) {
            BundleService.deleteBundle(_currentBundle);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.of(context).canPop()) {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              }
            });
            return const Center(
              child: Text(
                'Purging empty bundle…',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            );
          }

          // Compute category breakdown
          final Map<ItemType, int> categoryCounts = {};
          for (final it in _bundleItems) {
            final t = ItemTypeExt.fromString(it.type);
            categoryCounts[t] = (categoryCounts[t] ?? 0) + 1;
          }

          var filteredList = _bundleItems;
          if (_selectedTypeFilter != null) {
            filteredList = filteredList
                .where((i) =>
                    ItemTypeExt.fromString(i.type) == _selectedTypeFilter)
                .toList();
          }

          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            filteredList = filteredList.where((item) {
              final title = item.title.toLowerCase();
              final fields = item.fields.values
                  .map((v) => v.toString().toLowerCase())
                  .join(' ');
              return title.contains(q) || fields.contains(q);
            }).toList();
          }

          return Column(
            children: [
              // 1. Pinned 100% Full-Width Header
              _buildBundleHeader(categoryCounts),

              const SizedBox(height: 12),

              // 2. Search & Category Filter Strip
              _buildFilterSection(categoryCounts),

              // 3. Credential Dossier Cards List
              Expanded(
                child: filteredList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  size: 48,
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No matching credentials in this bundle'
                                    : 'No ${_selectedTypeFilter?.label ?? ''} items in this bundle',
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 13.5),
                                textAlign: TextAlign.center,
                              ),
                              if (_searchQuery.isEmpty &&
                                  _selectedTypeFilter == null) ...[
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.orangeAccent,
                                    side: BorderSide(
                                      color: AppColors.orangeAccent
                                          .withValues(alpha: 0.5),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                  ),
                                  icon: const AppIcon(
                                    HugeIcons.strokeRoundedFileImport,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Bulk Import from CSV',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                  onPressed: _importCsvToBundle,
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          return _BundleDossierCard(
                            key: ValueKey(item.itemId),
                            item: item,
                            accentColor: AppColors.orangeAccent,
                            onTap: () => _viewItem(item),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orangeAccent,
        foregroundColor: Colors.black,
        elevation: 4,
        icon: const AppIcon(AppIcons.add, size: 20, color: Colors.black),
        label: const Text(
          'Add to Bundle',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: _addItemToBundle,
      ),
    );
  }

  Widget _buildBundleHeader(Map<ItemType, int> categoryCounts) {
    return Container(
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
            'assets/icons/cutouts/vault-lock.png',
            width: 52,
            height: 52,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => AppIcon(
              HugeIcons.strokeRoundedFolder01,
              size: 38,
              color: AppColors.orangeAccent,
            ),
          ),
          const SizedBox(width: 14),
          // Bundle Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentBundle,
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
                    // Pill 1: Total items count
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.orangeAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.orangeAccent.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${_bundleItems.length} ${_bundleItems.length == 1 ? 'item' : 'items'}',
                        style: TextStyle(
                          color: AppColors.orangeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    // Pill 2: Categories count
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.cardZinc,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.borderZinc.withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(
                            HugeIcons.strokeRoundedLayers01,
                            size: 11,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${categoryCounts.keys.length} ${categoryCounts.keys.length == 1 ? 'category' : 'categories'}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Pill 3: AES-256
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
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
                            size: 11,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'AES-256',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
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

  Widget _buildFilterSection(Map<ItemType, int> categoryCounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search inside bundle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF16161C),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.borderZinc.withValues(alpha: 0.6),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: AppColors.offWhite, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Filter credentials in "$_currentBundle"…',
                hintStyle:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12),
                prefixIcon: const AppIcon(AppInputIcons.search,
                    color: AppColors.textMuted, size: 15),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const AppIcon(AppInputIcons.close,
                            color: AppColors.textMuted, size: 14),
                      )
                    : null,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Horizontal Category Filter Pills
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip(
                label: 'All (${_bundleItems.length})',
                isSelected: _selectedTypeFilter == null,
                onTap: () => setState(() => _selectedTypeFilter = null),
              ),
              ...categoryCounts.entries.map((entry) {
                final type = entry.key;
                final count = entry.value;
                return _buildFilterChip(
                  label: '${type.label} ($count)',
                  isSelected: _selectedTypeFilter == type,
                  onTap: () => setState(() => _selectedTypeFilter = type),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.orangeAccent.withValues(alpha: 0.18)
                : const Color(0xFF1B1B22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.orangeAccent.withValues(alpha: 0.6)
                  : AppColors.borderZinc.withValues(alpha: 0.4),
              width: 0.9,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.orangeAccent : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Unique, distinguished Dossier card for items inside a Bundle
class _BundleDossierCard extends ConsumerStatefulWidget {
  final DecryptedItem item;
  final Color accentColor;
  final VoidCallback onTap;

  const _BundleDossierCard({
    super.key,
    required this.item,
    required this.accentColor,
    required this.onTap,
  });

  @override
  ConsumerState<_BundleDossierCard> createState() => _BundleDossierCardState();
}

class _BundleDossierCardState extends ConsumerState<_BundleDossierCard> {
  bool _isRevealed = false;
  int _countdown = 10;
  Timer? _timer;
  Timer? _holdTimer;

  @override
  void dispose() {
    _timer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _isRevealed = true;
      _countdown = 10;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_countdown <= 1) {
        _hideSecret();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _hideSecret() {
    _timer?.cancel();
    _timer = null;
    if (mounted) {
      setState(() => _isRevealed = false);
    }
  }

  Future<void> _toggleSecretReveal() async {
    HapticFeedback.lightImpact();
    if (_isRevealed) {
      _hideSecret();
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

  void _onHoldStart() {
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 3), () {
      HapticFeedback.heavyImpact();
      AirShareModal.show(
        context,
        item: widget.item,
        role: AirShareRole.send,
      );
    });
  }

  void _onHoldEnd() {
    _holdTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final type = ItemTypeExt.fromString(widget.item.type);

    final rawSecret = widget.item.fields['password']?.toString() ??
        widget.item.fields['cvv']?.toString() ??
        widget.item.fields['secret_key']?.toString() ??
        widget.item.fields['pin']?.toString() ??
        '';

    final identifier = widget.item.fields['username']?.toString() ??
        widget.item.fields['cardholder']?.toString() ??
        widget.item.fields['key_name']?.toString() ??
        '';

    final hasSecret = rawSecret.isNotEmpty;
    final displaySecret = _isRevealed ? rawSecret : '••••••••••••';

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _onHoldStart(),
      onTapUp: (_) => _onHoldEnd(),
      onTapCancel: () => _onHoldEnd(),
      child: Container(
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
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top strip: Type badge + Title + AirShare button
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
                        color: AppColors.orangeAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.orangeAccent.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(_getTypeIcon(type),
                              size: 11, color: AppColors.orangeAccent),
                          const SizedBox(width: 4),
                          Text(
                            type.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.orangeAccent,
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
                    IconButton(
                      icon: const AppIcon(HugeIcons.strokeRoundedQrCode,
                          size: 16, color: AppColors.textMuted),
                      tooltip: 'AirShare Credential',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        AirShareModal.show(
                          context,
                          item: widget.item,
                          role: AirShareRole.send,
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Middle body: identifier + masked secret
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (identifier.isNotEmpty) ...[
                      Row(
                        children: [
                          const AppIcon(AppIcons.user,
                              size: 12, color: AppColors.textMuted),
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
                              identifier,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.offWhite,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              // V-017: identifiers ride the canonical copy
                              // path — sensitive flag + uniform 30 s TTL.
                              ref
                                  .read(lockServiceProvider)
                                  .copySecret(identifier);
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Identifier copied'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: AppIcon(AppIcons.copy,
                                  size: 12, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Secret row (tap to reveal, no fingerprint icon)
                    Row(
                      children: [
                        const AppIcon(AppIcons.lock,
                            size: 12, color: AppColors.textMuted),
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
                            onTap: hasSecret ? _toggleSecretReveal : null,
                            child: Text(
                              displaySecret,
                              style: TextStyle(
                                fontSize: 12,
                                color: _isRevealed
                                    ? AppColors.orangeAccent
                                    : AppColors.textMuted,
                                fontFamily: _isRevealed ? 'monospace' : null,
                                letterSpacing: _isRevealed ? 0.3 : 1.4,
                                fontWeight: _isRevealed
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (_isRevealed) ...[
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _toggleSecretReveal,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: AppColors.orangeAccent
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.orangeAccent
                                      .withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${_countdown}s',
                                style: TextStyle(
                                  color: AppColors.orangeAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
