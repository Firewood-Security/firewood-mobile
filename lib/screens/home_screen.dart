// screens/home_screen.dart
// Main vault home view with top navbar actions, classic metrics overview (Credentials, Health Score & Security Advisor Banner), 6-card bare-icon grid (2x size), and floating search button

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models/item_type.dart';
import '../providers/auth_provider.dart';
import '../services/item_service.dart';
import '../services/lock_service.dart';
import '../services/reauth_service.dart';
import '../services/backup_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_feedback.dart';
import '../theme/vault_design_system.dart';
import '../widgets/vault_components.dart';
import 'credential_view_screen.dart';
import 'category_items_screen.dart';
import 'item_detail_screen.dart';
import 'settings_screen.dart';
import 'vault_search_screen.dart';
import '../widgets/guide_modal.dart';
import '../widgets/security_advisor_sheet.dart';
import '../services/mini_ml_advisor.dart';
import '../services/accent_color_service.dart';
import '../services/bundle_service.dart';
import '../widgets/bundle_settings_sheet.dart';
import '../widgets/airshare_modal.dart';
import 'bundle_detail_screen.dart';
import '../services/autofill_service.dart';
import '../services/notification_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ItemService _itemService = ItemService();
  int _selectedView = 0; // 0 = Categories, 1 = Bundles
  late final PageController _viewPageController;

  @override
  void initState() {
    super.initState();
    _viewPageController = PageController(initialPage: _selectedView);
    AccentColorService.currentColor.addListener(_onAccentColorChanged);
    _checkGuideModal();
  }

  void _onAccentColorChanged() {
    _refreshDashboard();
  }

  Future<void> _checkGuideModal() async {
    final shouldShow = await GuideModal.shouldShow();
    if (shouldShow && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) GuideModal.show(context);
      });
    }
  }

  @override
  void dispose() {
    _viewPageController.dispose();
    AccentColorService.currentColor.removeListener(_onAccentColorChanged);
    super.dispose();
  }

  void _navigateToBundle(SecretKey key, String bundleName) {
    HapticFeedback.lightImpact();
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => BundleDetailScreen(
              secretKey: key,
              bundleName: bundleName,
            ),
          ),
        )
        .then((_) => _refreshDashboard());
  }

  Future<void> _createNewBundlePrompt(SecretKey key) async {
    final controller = TextEditingController();
    final bundleName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderZinc),
        ),
        title: Row(
          children: [
            AppIcon(HugeIcons.strokeRoundedFolder01,
                color: AppColors.orangeAccent, size: 22),
            const SizedBox(width: 10),
            Text(
              'New Credential Bundle',
              style: TextStyle(
                color: AppColors.offWhite,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a bundle name to group related credentials (e.g. Housework, Mom, Personal, Work).',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.offWhite, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Bundle Name (e.g. Housework)',
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orangeAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create Bundle'),
          ),
        ],
      ),
    );

    if (bundleName != null && bundleName.isNotEmpty && mounted) {
      await BundleService.registerBundle(bundleName);
      setState(() => _selectedView = 1);
      if (_viewPageController.hasClients) {
        _viewPageController.jumpToPage(1);
      }
      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ItemDetailScreen(
            secretKey: key,
            itemService: _itemService,
            initialBundle: bundleName,
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
  }

  void _openBundleSettings(
      SecretKey key, String bundleName, List<DecryptedItem> items) {
    BundleSettingsSheet.show(
      context: context,
      secretKey: key,
      bundleName: bundleName,
      items: items,
      onRenamed: (_) {
        if (mounted) setState(() {});
      },
      onEmptied: () {
        if (mounted) setState(() {});
      },
      onDeleted: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _addItem(SecretKey key) async {
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ItemDetailScreen(
          secretKey: key,
          itemService: _itemService,
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
    _refreshDashboard();
  }

  Future<void> _importBackup(SecretKey currentKey) async {
    // Auth policy: importing overrides credentials in the vault.
    if (!await ReauthService.confirm(context,
        reason: 'Authenticate to import a vault backup')) {
      return;
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();

    LockService.beginForegroundFlow();
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: 'Select .firewood Backup File',
      );
    } finally {
      LockService.endForegroundFlow();
    }

    if (result == null || result.files.single.path == null || !mounted) return;
    final filePath = result.files.single.path!;

    if (!filePath.toLowerCase().endsWith('.firewood')) {
      if (mounted) {
        AppToast.show(context,
            message: 'Please select a valid .firewood backup file',
            type: ToastType.error);
      }
      return;
    }

    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        title: const Text('Import Backup File',
            style: TextStyle(
                color: AppColors.offWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordController,
            obscureText: true,
            style: const TextStyle(color: AppColors.offWhite),
            decoration: const InputDecoration(
              labelText: 'Backup Master Password',
              prefixIcon: AppIcon(AppInputIcons.lock,
                  size: 20, color: AppColors.textMuted),
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Password required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, passwordController.text);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangeAccent,
                foregroundColor: Colors.white,
                shadowColor: AppColors.shade(AppColors.orangeAccent, -0.18)),
            child: const Text('Import & Restore'),
          ),
        ],
      ),
    );

    if (password == null || !mounted) return;

    try {
      final backupService = BackupService();
      final importResult = await backupService.importVault(
        filePath,
        password,
        overwrite: false,
        activeVaultKey: currentKey,
      );

      if (mounted) {
        AppToast.show(
          context,
          message: 'Successfully imported backup: $importResult',
          type: ToastType.success,
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Failed to import backup: ${e.toString()}',
          type: ToastType.error,
        );
      }
    }
  }

  void _showPlusActionSheet(SecretKey key) {
    HapticFeedback.lightImpact();
    final activeAccent = Theme.of(context).colorScheme.primary;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF16161A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.borderZinc, width: 1),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderZinc,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vault actions',
                          style: GoogleFonts.syncopate(
                            color: AppColors.offWhite,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Add, organise or restore credentials',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Button 1: Add Credentials
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardZinc,
                  borderRadius: BorderRadius.circular(VaultRadii.lg),
                  border: VaultBorders.allSubtle(),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(VaultRadii.lg),
                    onTap: () {
                      Navigator.pop(ctx);
                      _addItem(key);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          const AppIcon(AppIcons.add, size: 36),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Credentials',
                                  style: TextStyle(
                                    color: AppColors.offWhite,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Create a new login, card, note, or ID',
                                  style: TextStyle(
                                      color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          AppIcon(AppIcons.chevronRight,
                              size: 16, color: activeAccent),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Button 2: New Credential Bundle
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceZinc,
                  borderRadius: BorderRadius.circular(VaultRadii.lg),
                  border: VaultBorders.allSubtle(opacity: 0.8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(VaultRadii.lg),
                    onTap: () {
                      Navigator.pop(ctx);
                      _createNewBundlePrompt(key);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          AppIcon(HugeIcons.strokeRoundedFolder01,
                              size: 28, color: AppColors.orangeAccent),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'New Credential Bundle',
                                  style: TextStyle(
                                    color: AppColors.offWhite,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Group related credentials across categories',
                                  style: TextStyle(
                                      color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          AppIcon(AppIcons.chevronRight,
                              size: 16, color: activeAccent),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Button 3: Import Backup
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceZinc,
                  borderRadius: BorderRadius.circular(VaultRadii.lg),
                  border: VaultBorders.allSubtle(opacity: 0.7),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(VaultRadii.lg),
                    onTap: () {
                      Navigator.pop(ctx);
                      _importBackup(key);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          const AppIcon(AppIcons.download, size: 26),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Import Backup',
                                  style: TextStyle(
                                    color: AppColors.offWhite,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Restore credentials from encrypted .firewood file',
                                  style: TextStyle(
                                      color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const AppIcon(AppIcons.chevronRight,
                              size: 16, color: AppColors.textMuted),
                        ],
                      ),
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

  Future<void> _viewItem(SecretKey key, DecryptedItem item) async {
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CredentialViewScreen(
          secretKey: key,
          itemService: _itemService,
          item: item,
        ),
      ),
    );
    _refreshDashboard();
  }

  void _navigateToCategory(SecretKey key, ItemType? category) {
    HapticFeedback.lightImpact();
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CategoryItemsScreen(
              secretKey: key,
              category: category,
            ),
          ),
        )
        .then((_) => _refreshDashboard());
  }

  void _navigateToSearch(SecretKey key) {
    HapticFeedback.lightImpact();
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => VaultSearchScreen(
              secretKey: key,
              autoFocusSearch: true,
            ),
          ),
        )
        .then((_) => _refreshDashboard());
  }

  void _navigateToSettings() {
    HapticFeedback.lightImpact();
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => const SettingsScreen(),
          ),
        )
        .then((_) => _refreshDashboard());
  }

  void _navigateToAirShareSend() {
    HapticFeedback.heavyImpact();
    AirShareModal.show(context, role: AirShareRole.send);
  }

  @override
  Widget build(BuildContext context) {
    final key = ref.watch(authProvider);

    return ValueListenableBuilder<Color>(
      valueListenable: AccentColorService.currentColor,
      builder: (context, accentColor, _) {
        return Scaffold(
          backgroundColor: AppColors.backgroundZinc,
          appBar: VaultAppBar(
            showLogo: true,
            actions: [
              if (key != null) ...[
                IconButton(
                  icon: const AppIcon(
                    HugeIcons.strokeRoundedPlusSign,
                    color: AppColors.offWhite,
                    size: 22,
                    strokeWidth: 2.0,
                  ),
                  tooltip: 'Add Credentials',
                  onPressed: () => _showPlusActionSheet(key),
                ),
                IconButton(
                  icon: const AppIcon(
                    HugeIcons.strokeRoundedSettings02,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  tooltip: 'Settings',
                  onPressed: _navigateToSettings,
                ),
                IconButton(
                  icon: const AppIcon(
                    HugeIcons.strokeRoundedLockKey,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  tooltip: 'Lock Vault',
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(authProvider.notifier).state = null;
                  },
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
          floatingActionButton: key == null
              ? null
              : FloatingActionButton(
                  onPressed: () => _navigateToSearch(key),
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  child: const AppIcon(AppInputIcons.search,
                      size: 24, color: Colors.white),
                ),
          body: key == null
              ? Center(
                  child: CircularProgressIndicator(color: accentColor),
                )
              : _buildDashboard(key, accentColor),
        );
      },
    );
  }

  _DashboardData? _cachedData;
  Future<_DashboardData>? _dashboardFuture;

  /// Flicker fix: invalidate cached dashboard data when returning from
  /// sub-screens so new/edited items appear without a stale flash.
  void _refreshDashboard() {
    if (!mounted) return;
    setState(() {
      _dashboardFuture = null;
    });
  }

  Future<_DashboardData> _loadDashboardData(SecretKey key) async {
    final results = await Future.wait([
      _itemService.getAllItems(key),
      BundleService.getRegisteredBundles(),
    ]);
    final items = results[0] as List<DecryptedItem>;

    // 100% Offline native Autofill store synchronization
    AutofillService.syncDecryptedItems(items);

    // Throttled on-device security tips and findings check
    _checkSecurityFindings(items);

    return _DashboardData(
      items: items,
      registeredBundles: results[1] as List<String>,
    );
  }

  void _checkSecurityFindings(List<DecryptedItem> items) {
    if (items.isEmpty) return;
    try {
      final adv = SecurityAdvisorEngine.analyze(items);
      if (adv.topTip != null) {
        NotificationAlertService.notifySecurityTip(
          tipText: '${adv.topTip!.title}: ${adv.topTip!.message}',
        );
      }
    } catch (_) {}
  }

  Widget _buildDashboard(SecretKey key, Color activeAccent) {
    return FutureBuilder<_DashboardData>(
      future: _dashboardFuture ??= _loadDashboardData(key),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _cachedData = snapshot.data;
        }

        final data = snapshot.data ?? _cachedData;

        if (data == null &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final itemList = data?.items ?? [];
        final registeredBundles = data?.registeredBundles ?? [];
        final logins = itemList
            .where((i) => ItemTypeExt.fromString(i.type) == ItemType.login)
            .toList();
        final cards = itemList
            .where((i) => ItemTypeExt.fromString(i.type) == ItemType.card)
            .length;
        final identities = itemList
            .where((i) => ItemTypeExt.fromString(i.type) == ItemType.identity)
            .length;
        final devSecrets = itemList
            .where((i) =>
                ItemTypeExt.fromString(i.type) == ItemType.developerSecret)
            .length;
        final notes = itemList
            .where((i) => ItemTypeExt.fromString(i.type) == ItemType.note)
            .length;

        final twoFaCount = logins
            .where((i) =>
                (i.fields['totp_secret'] ?? '').toString().trim().isNotEmpty)
            .length;

        final Map<String, List<DecryptedItem>> bundleMap = {};
        for (final b in registeredBundles) {
          bundleMap.putIfAbsent(b, () => []);
        }
        for (final item in itemList) {
          final b = (item.fields['bundle'] ?? '').toString().trim();
          if (b.isNotEmpty) {
            bundleMap.putIfAbsent(b, () => []).add(item);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TOP METRICS ROW (VaultMetricCard primitives)
                  Builder(
                    builder: (context) {
                      final adv = SecurityAdvisorEngine.analyze(itemList);
                      final score = adv.securityScore;
                      return Row(
                        children: [
                          VaultMetricCard(
                            label: 'TOTAL CREDENTIALS',
                            value: '${itemList.length}',
                            unit: 'items',
                            accentColor: activeAccent,
                            onHold3Seconds: _navigateToAirShareSend,
                          ),
                          const SizedBox(width: 10),
                          VaultMetricCard(
                            label: 'HEALTH SCORE',
                            value: '$score%',
                            unit: 'health',
                            accentColor: score >= 80
                                ? activeAccent
                                : (score >= 50
                                    ? const Color(0xFFF59E0B)
                                    : AppColors.roseAccent),
                            showAlertDot: score < 80 && itemList.isNotEmpty,
                            onTap: () => SecurityAdvisorSheet.show(
                              context,
                              key: key,
                              items: itemList,
                              onOpenItem: (k, item) => _viewItem(k, item),
                            ),
                            onHold3Seconds: _navigateToAirShareSend,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // View Selector Tabs: Categories vs Bundles
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedView = 0);
                            if (_viewPageController.hasClients) {
                              _viewPageController.animateToPage(
                                0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedView == 0
                                  ? AppColors.surfaceZinc
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedView == 0
                                    ? AppColors.offWhite.withValues(alpha: 0.18)
                                    : AppColors.borderZinc
                                        .withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'CATEGORIES',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: _selectedView == 0
                                    ? FontWeight.bold
                                    : FontWeight.w400,
                                letterSpacing: 0.8,
                                color: _selectedView == 0
                                    ? AppColors.offWhite
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedView = 1);
                            if (_viewPageController.hasClients) {
                              _viewPageController.animateToPage(
                                1,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedView == 1
                                  ? AppColors.surfaceZinc
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedView == 1
                                    ? AppColors.offWhite.withValues(alpha: 0.18)
                                    : AppColors.borderZinc
                                        .withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'BUNDLES',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: _selectedView == 1
                                        ? FontWeight.bold
                                        : FontWeight.w400,
                                    letterSpacing: 0.8,
                                    color: _selectedView == 1
                                        ? AppColors.offWhite
                                        : AppColors.textMuted,
                                  ),
                                ),
                                if (bundleMap.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _selectedView == 1
                                          ? AppColors.borderZinc
                                          : AppColors.borderZinc
                                              .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${bundleMap.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedView == 1
                                            ? AppColors.offWhite
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _viewPageController,
                clipBehavior: Clip.hardEdge,
                onPageChanged: (idx) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedView = idx);
                },
                children: [
                  // PAGE 0: VAULT CATEGORIES
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const VaultSectionLabel('VAULT CATEGORIES',
                            padding: EdgeInsets.symmetric(vertical: 2)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: GridView.count(
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.35,
                            children: [
                              VaultCategoryCard(
                                title: 'Logins',
                                count: '${logins.length}',
                                subtitle: '$twoFaCount 2FA Active',
                                icon: 'assets/icons/cutouts/user-login.png',
                                accentColor: activeAccent,
                                onTap: () =>
                                    _navigateToCategory(key, ItemType.login),
                                onHold3Seconds: _navigateToAirShareSend,
                              ),
                              VaultCategoryCard(
                                title: 'Cards',
                                count: '$cards',
                                subtitle: 'Payment cards',
                                icon: 'assets/icons/cutouts/credit-card.png',
                                accentColor: activeAccent,
                                onTap: () =>
                                    _navigateToCategory(key, ItemType.card),
                                onHold3Seconds: _navigateToAirShareSend,
                              ),
                              VaultCategoryCard(
                                title: 'Identity',
                                count: '$identities',
                                subtitle: 'Passports & IDs',
                                icon: 'assets/icons/cutouts/passport.png',
                                accentColor: activeAccent,
                                onTap: () =>
                                    _navigateToCategory(key, ItemType.identity),
                                onHold3Seconds: _navigateToAirShareSend,
                              ),
                              VaultCategoryCard(
                                title: 'API Keys',
                                count: '$devSecrets',
                                subtitle: 'Developer secrets',
                                icon: 'assets/icons/cutouts/api-key.png',
                                accentColor: activeAccent,
                                onTap: () => _navigateToCategory(
                                    key, ItemType.developerSecret),
                                onHold3Seconds: _navigateToAirShareSend,
                              ),
                              VaultCategoryCard(
                                title: 'Secure Notes',
                                count: '$notes',
                                subtitle: 'Encrypted notes',
                                icon: 'assets/icons/cutouts/secure-note.png',
                                accentColor: activeAccent,
                                onTap: () =>
                                    _navigateToCategory(key, ItemType.note),
                                onHold3Seconds: _navigateToAirShareSend,
                              ),
                              VaultCategoryCard(
                                title: 'All Vault Items',
                                count: '${itemList.length}',
                                subtitle: 'Complete vault',
                                icon: 'assets/icons/cutouts/vault-lock.png',
                                accentColor: activeAccent,
                                onTap: () => _navigateToCategory(key, null),
                                onHold3Seconds: _navigateToAirShareSend,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // PAGE 1: CREDENTIAL BUNDLES
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            VaultSectionLabel(
                              'CREDENTIAL BUNDLES (${bundleMap.length})',
                              padding: const EdgeInsets.symmetric(vertical: 2),
                            ),
                            GestureDetector(
                              onTap: () => _createNewBundlePrompt(key),
                              child: Row(
                                children: [
                                  AppIcon(HugeIcons.strokeRoundedAddCircle,
                                      size: 14, color: activeAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'New Bundle',
                                    style: TextStyle(
                                      color: activeAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: bundleMap.isEmpty
                              ? Center(
                                  child: Container(
                                    margin: const EdgeInsets.all(16),
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceZinc,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: AppColors.borderZinc,
                                          width: 1),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: activeAccent.withValues(
                                                alpha: 0.1),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: activeAccent.withValues(
                                                    alpha: 0.3)),
                                          ),
                                          child: Center(
                                            child: AppIcon(
                                              HugeIcons.strokeRoundedFolder01,
                                              size: 28,
                                              color: activeAccent,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'No Credential Bundles Yet',
                                          style: TextStyle(
                                            color: AppColors.offWhite,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Group related credentials across categories (e.g. Housework: Mom\'s ID, Gmail, Yahoo login) encrypted together.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: activeAccent,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 10),
                                          ),
                                          icon: const AppIcon(
                                              HugeIcons.strokeRoundedAdd01,
                                              size: 16,
                                              color: Colors.white),
                                          label: const Text(
                                              'Create First Bundle',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold)),
                                          onPressed: () =>
                                              _createNewBundlePrompt(key),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView(
                                  children: bundleMap.entries.map((entry) {
                                    final bName = entry.key;
                                    final bItems = entry.value;
                                    final typeSet = bItems
                                        .map((i) =>
                                            ItemTypeExt.fromString(i.type)
                                                .label)
                                        .toSet()
                                        .toList();
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF15151B),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.borderZinc
                                              .withValues(alpha: 0.5),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: HoldToAirshareDetector(
                                        onTap: () =>
                                            _navigateToBundle(key, bName),
                                        onHold3Seconds: _navigateToAirShareSend,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 12),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 46,
                                                height: 46,
                                                decoration: BoxDecoration(
                                                  color: activeAccent
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border:
                                                      VaultBorders.allAccent(
                                                          activeAccent,
                                                          opacity: 0.3),
                                                ),
                                                child: Center(
                                                  child: AppIcon(
                                                    HugeIcons
                                                        .strokeRoundedFolder01,
                                                    size: 24,
                                                    color: activeAccent,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            bName,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              color: AppColors
                                                                  .offWhite,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              fontSize: 14.5,
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 7,
                                                                  vertical: 2),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: activeAccent
                                                                .withValues(
                                                                    alpha:
                                                                        0.15),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20),
                                                            border: Border.all(
                                                              color: activeAccent
                                                                  .withValues(
                                                                      alpha:
                                                                          0.3),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            '${bItems.length}',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  activeAccent,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      typeSet.isEmpty
                                                          ? 'Empty bundle'
                                                          : typeSet.join(' • '),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color:
                                                            AppColors.textMuted,
                                                        fontSize: 11.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () =>
                                                    _openBundleSettings(
                                                        key, bName, bItems),
                                                child: Container(
                                                  width: 30,
                                                  height: 30,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.cardZinc,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                        color: AppColors
                                                            .borderZinc),
                                                  ),
                                                  child: const Center(
                                                    child: AppIcon(
                                                        AppIcons.chevronRight,
                                                        size: 14,
                                                        color: AppColors
                                                            .textMuted),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DashboardData {
  final List<DecryptedItem> items;
  final List<String> registeredBundles;
  const _DashboardData({required this.items, required this.registeredBundles});
}
