// screens/category_items_screen.dart
// Dedicated styled screen for each credential category with 100% full-width technical header,
// 3D cutout icon, total metrics, creation date listings, and smooth detail navigation

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models/item_type.dart';
import '../services/item_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/vault_design_system.dart';
import '../widgets/vault_components.dart';
import 'credential_view_screen.dart';
import 'item_detail_screen.dart';
import '../services/bundle_service.dart';
import '../widgets/bundle_settings_sheet.dart';

class CategoryItemsScreen extends StatefulWidget {
  final SecretKey secretKey;
  final ItemType? category; // null represents "All Vault Items"
  final String? bundle; // If provided, shows all items in this bundle

  const CategoryItemsScreen({
    super.key,
    required this.secretKey,
    this.category,
    this.bundle,
  });

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen> {
  final ItemService _itemService = ItemService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late String? _currentBundle;

  @override
  void initState() {
    super.initState();
    _currentBundle = widget.bundle;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _categoryTitle {
    if (_currentBundle != null) return '$_currentBundle Bundle';
    if (widget.category == null) return 'All Vault Items';
    switch (widget.category!) {
      case ItemType.login:
        return 'Logins';
      case ItemType.card:
        return 'Payment Cards';
      case ItemType.identity:
        return 'Identities & Passports';
      case ItemType.note:
        return 'Secure Notes';
      case ItemType.developerSecret:
        return 'API Keys & Secrets';
    }
  }

  String get _categorySubtitle {
    if (_currentBundle != null) {
      return 'Encrypted group containing related credentials across all types';
    }
    if (widget.category == null)
      return 'Complete encrypted credential database';
    switch (widget.category!) {
      case ItemType.login:
        return 'Accounts, passwords and 2FA TOTP authenticators';
      case ItemType.card:
        return 'Credit, debit cards and encrypted CVV records';
      case ItemType.identity:
        return 'Government IDs, passports and driver licenses';
      case ItemType.note:
        return 'Confidential notes and cryptographic memos';
      case ItemType.developerSecret:
        return 'API tokens, private keys and environment variables';
    }
  }

  String get _categoryCutoutPath {
    if (_currentBundle != null) {
      return 'assets/icons/cutouts/vault-lock.png';
    }
    if (widget.category == null) {
      return 'assets/icons/cutouts/vault-lock.png';
    }
    switch (widget.category!) {
      case ItemType.login:
        return 'assets/icons/cutouts/user-login.png';
      case ItemType.card:
        return 'assets/icons/cutouts/credit-card.png';
      case ItemType.identity:
        return 'assets/icons/cutouts/passport.png';
      case ItemType.note:
        return 'assets/icons/cutouts/secure-note.png';
      case ItemType.developerSecret:
        return 'assets/icons/cutouts/api-key.png';
    }
  }

  dynamic get _categoryIcon {
    if (_currentBundle != null) return HugeIcons.strokeRoundedFolder01;
    if (widget.category == null) return AppIcons.vault;
    switch (widget.category!) {
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

  List<DecryptedItem> _currentBundleItems = [];

  void _openBundleSettings() {
    if (_currentBundle == null) return;
    BundleSettingsSheet.show(
      context: context,
      secretKey: widget.secretKey,
      bundleName: _currentBundle!,
      items: _currentBundleItems,
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

  Future<void> _addItem() async {
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ItemDetailScreen(
          secretKey: widget.secretKey,
          itemService: _itemService,
          initialCategory: widget.category,
          initialBundle: _currentBundle,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final activeAccent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: AppColors.backgroundZinc,
      appBar: VaultAppBar(
        title: _categoryTitle,
        leading: IconButton(
          icon: const AppIcon(AppIcons.arrowLeft,
              color: AppColors.offWhite, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_currentBundle != null) ...[
            IconButton(
              icon: const AppIcon(HugeIcons.strokeRoundedSettings01,
                  color: AppColors.offWhite, size: 20),
              tooltip: 'Bundle Settings',
              onPressed: _openBundleSettings,
            ),
          ],
          IconButton(
            icon: AppIcon(AppIcons.add, color: activeAccent, size: 22),
            tooltip: 'Add $_categoryTitle',
            onPressed: _addItem,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<List<DecryptedItem>>(
        future: _itemService.getAllItems(widget.secretKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(activeAccent),
              ),
            );
          }

          var allItems = snapshot.data ?? [];
          if (_currentBundle != null) {
            _currentBundleItems = allItems
                .where((i) =>
                    (i.fields['bundle'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase() ==
                    _currentBundle!.toLowerCase())
                .toList();

            // If bundle has become empty, purge it and automatically close the bundle screen
            if (_currentBundleItems.isEmpty &&
                snapshot.connectionState != ConnectionState.waiting) {
              BundleService.deleteBundle(_currentBundle!);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && Navigator.of(context).canPop()) {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                }
              });
            }
          }

          var categoryItems = _currentBundle != null
              ? _currentBundleItems
              : (widget.category == null
                  ? allItems
                  : allItems
                      .where((i) =>
                          ItemTypeExt.fromString(i.type) == widget.category)
                      .toList());

          // Apply local filter query
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            categoryItems = categoryItems.where((item) {
              final title = item.title.toLowerCase();
              final fields = item.fields.values
                  .map((v) => v.toString().toLowerCase())
                  .join(' ');
              return title.contains(query) || fields.contains(query);
            }).toList();
          }

          categoryItems.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          return Column(
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
                      _categoryCutoutPath,
                      width: 52,
                      height: 52,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => AppIcon(
                        _categoryIcon,
                        size: 38,
                        color: activeAccent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Item details (Subtitle description + Clean value-only metric badge)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _categorySubtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Value-only metric badge
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
                              '${categoryItems.length} ${categoryItems.length == 1 ? 'item' : 'items'}',
                              style: TextStyle(
                                color: activeAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Filter In-Category Search Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style:
                      const TextStyle(color: AppColors.offWhite, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Filter $_categoryTitle...',
                    hintStyle: VaultTypography.meta,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: AppIcon(AppInputIcons.search,
                          color: AppColors.textMuted, size: 18),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const AppIcon(AppInputIcons.close,
                                color: AppColors.textMuted, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    fillColor: AppColors.surfaceZinc,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VaultRadii.md),
                      borderSide: BorderSide(
                          color: AppColors.borderZinc.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VaultRadii.md),
                      borderSide: BorderSide(
                          color: AppColors.borderZinc.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VaultRadii.md),
                      borderSide: BorderSide(color: activeAccent, width: 1.5),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Item List with creation dates and names
              Expanded(
                child: categoryItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcon(_categoryIcon,
                                size: 48,
                                color:
                                    AppColors.textMuted.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No matching ${_categoryTitle.toLowerCase()}'
                                  : 'No ${_categoryTitle.toLowerCase()} added yet',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 14),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _addItem,
                              icon: const AppIcon(AppIcons.add, size: 18),
                              label: Text('Add $_categoryTitle'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: activeAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(VaultRadii.md),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        itemCount: categoryItems.length,
                        itemBuilder: (context, index) {
                          final item = categoryItems[index];
                          return VaultCredentialTile(
                            item: item,
                            accentColor: activeAccent,
                            showDate: true,
                            onTap: () => _viewItem(item),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
