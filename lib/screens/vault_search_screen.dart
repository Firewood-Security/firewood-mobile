// screens/vault_search_screen.dart
// Pure minimalist vault search screen with active search focus and category filtering

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/item_type.dart';
import '../services/item_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/vault_design_system.dart';
import '../widgets/vault_components.dart';
import 'credential_view_screen.dart';

class VaultSearchScreen extends StatefulWidget {
  final SecretKey secretKey;
  final ItemType? initialFilter;
  final bool autoFocusSearch;

  const VaultSearchScreen({
    super.key,
    required this.secretKey,
    this.initialFilter,
    this.autoFocusSearch = true,
  });

  @override
  State<VaultSearchScreen> createState() => _VaultSearchScreenState();
}

class _VaultSearchScreenState extends State<VaultSearchScreen> {
  final ItemService _itemService = ItemService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  ItemType? _filterType;

  @override
  void initState() {
    super.initState();
    _filterType = widget.initialFilter;
    if (widget.autoFocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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

  Widget _buildCategoryDropdown(Color activeAccent) {
    final currentLabel = _filterType == null ? 'All' : _filterType!.label;
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.surfaceZinc,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VaultRadii.md),
            side: const BorderSide(color: AppColors.borderZinc),
          ),
          elevation: 6,
        ),
      ),
      child: PopupMenuButton<ItemType?>(
        tooltip: 'Filter category',
        initialValue: _filterType,
        position: PopupMenuPosition.under,
        onSelected: (ItemType? val) {
          HapticFeedback.selectionClick();
          setState(() => _filterType = val);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 62),
                child: Text(
                  currentLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _filterType != null
                        ? activeAccent
                        : AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: _filterType != null ? activeAccent : AppColors.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
        itemBuilder: (BuildContext context) => [
          PopupMenuItem<ItemType?>(
            value: null,
            height: 38,
            child: Row(
              children: [
                AppIcon(AppIcons.shield,
                    size: 14,
                    color: _filterType == null
                        ? activeAccent
                        : AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All Categories',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _filterType == null
                          ? activeAccent
                          : AppColors.offWhite,
                      fontWeight: _filterType == null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (_filterType == null)
                  Icon(Icons.check_rounded, color: activeAccent, size: 16),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          ...ItemType.values.map((type) {
            final isSelected = _filterType == type;
            return PopupMenuItem<ItemType?>(
              value: type,
              height: 38,
              child: Row(
                children: [
                  AppIcon(_getTypeIcon(type),
                      size: 14,
                      color: isSelected ? activeAccent : AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isSelected ? activeAccent : AppColors.offWhite,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_rounded, color: activeAccent, size: 16),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeAccent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: AppColors.backgroundZinc,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceZinc,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const AppIcon(AppIcons.arrowLeft,
              color: AppColors.offWhite, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 14),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.backgroundZinc,
            borderRadius: BorderRadius.circular(VaultRadii.md),
            border: Border.all(
              color: AppColors.borderZinc.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const AppIcon(AppInputIcons.search,
                  color: AppColors.textMuted, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: widget.autoFocusSearch,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(
                      color: AppColors.offWhite, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: _filterType != null
                        ? 'Search ${_filterType!.label}...'
                        : 'Search vault...',
                    hintStyle: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: AppIcon(AppInputIcons.close,
                        color: AppColors.textMuted, size: 15),
                  ),
                ),
              Container(
                height: 18,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: AppColors.borderZinc.withValues(alpha: 0.7),
              ),
              _buildCategoryDropdown(activeAccent),
            ],
          ),
        ),
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

          var items = snapshot.data ?? [];

          // Category filter
          if (_filterType != null) {
            items = items
                .where(
                    (item) => ItemTypeExt.fromString(item.type) == _filterType)
                .toList();
          }

          // Search query filter
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            items = items.where((item) {
              final title = item.title.toLowerCase();
              final fields = item.fields.values
                  .map((v) => v.toString().toLowerCase())
                  .join(' ');
              return title.contains(query) || fields.contains(query);
            }).toList();
          }

          // Sort newest first
          items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(AppIcons.shield,
                        size: 48,
                        color: AppColors.textMuted.withValues(alpha: 0.6)),
                    const SizedBox(height: 14),
                    const Text(
                      'No items found',
                      style: TextStyle(
                        color: AppColors.offWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No credentials match "$_searchQuery"'
                          : _filterType != null
                              ? 'No ${_filterType!.label} items in vault'
                              : 'No items in this category yet',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: VaultCredentialTile(
                  item: item,
                  accentColor: activeAccent,
                  onTap: () => _viewItem(item),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
