// screens/home_screen.dart
// Main vault view with floating bottom navigation, logo-only navbar, analytics, password listing, generator, security info, and settings

import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/item_type.dart';
import '../providers/auth_provider.dart';
import '../services/item_service.dart';
import '../services/lock_service.dart';
import '../services/backup_service.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_feedback.dart';
import 'credential_view_screen.dart';
import 'item_detail_screen.dart';
import 'settings_screen.dart';
import '../widgets/guide_modal.dart';
import '../widgets/security_advisor_sheet.dart';
import '../widgets/app_floating_navbar.dart';
import '../services/analytics_service.dart';
import '../services/accent_color_service.dart';
import '../services/generator_service.dart';
import '../widgets/password_strength_meter.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  final ItemService _itemService = ItemService();
  final TextEditingController _searchController = TextEditingController();

  int _currentTabIndex = 0;
  String _searchQuery = '';
  ItemType? _filterType;
  bool _sortDescending = true;
  bool _isGridView = false;

  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    AccentColorService.currentColor.addListener(_onAccentColorChanged);
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabController.forward();
    _checkGuideModal();
  }

  void _onAccentColorChanged() {
    if (mounted) setState(() {});
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
    AccentColorService.currentColor.removeListener(_onAccentColorChanged);
    _fabController.dispose();
    _searchController.dispose();
    super.dispose();
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
    setState(() {}); // Refresh list
  }

  Future<void> _importBackup(SecretKey currentKey) async {
    HapticFeedback.lightImpact();

    // Request file & storage permissions
    try {
      if (Platform.isAndroid) {
        final storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          await Permission.storage.request();
        }
        final manageStatus = await Permission.manageExternalStorage.status;
        if (!manageStatus.isGranted && !manageStatus.isRestricted) {
          await Permission.manageExternalStorage.request();
        }
      }
    } catch (_) {}

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      dialogTitle: 'Select .firewood Backup File',
    );

    if (result == null || result.files.single.path == null || !mounted) return;
    final filePath = result.files.single.path!;

    if (!filePath.toLowerCase().endsWith('.firewood')) {
      if (mounted) {
        AppToast.show(context, message: 'Please select a valid .firewood backup file', type: ToastType.error);
      }
      return;
    }

    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        title: const Text('Import Backup File', style: TextStyle(color: AppColors.offWhite, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordController,
            obscureText: true,
            style: const TextStyle(color: AppColors.offWhite),
            decoration: const InputDecoration(
              labelText: 'Backup Master Password',
              prefixIcon: AppIcon(AppInputIcons.lock, size: 20, color: AppColors.textMuted),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Password required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, passwordController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.primary, foregroundColor: Colors.white),
            child: const Text('Import & Restore'),
          ),
        ],
      ),
    );

    if (password == null || !mounted) return;

    try {
      final backupService = BackupService();
      final result = await backupService.importVault(
        filePath,
        password,
        overwrite: false,
        activeVaultKey: currentKey,
      );

      if (mounted) {
        AppToast.show(
          context,
          message: 'Successfully imported backup: $result',
          type: ToastType.success,
        );
        setState(() {}); // Refresh list
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
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF16161A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppColors.borderZinc, width: 1),
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).padding.bottom + 20),
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
              const SizedBox(height: 18),
              Row(
                children: [
                  AppIcon(AppIcons.vault, size: 34),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vault Actions',
                          style: TextStyle(
                            color: AppColors.offWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Choose an action to perform',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Button 1: Add Credentials
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardZinc,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderZinc, width: 1),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.pop(ctx);
                      _addItem(key);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          AppIcon(AppIcons.add, size: 36),
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
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          AppIcon(AppIcons.chevronRight, size: 16, color: activeAccent),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Button 2: Import Backup
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceZinc,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.7), width: 1),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(ctx);
                      _importBackup(key);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const AppIcon(AppIcons.chevronRight, size: 16, color: AppColors.textMuted),
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
    setState(() {}); // Refresh after view
  }

  Future<void> _deleteItem(SecretKey key, DecryptedItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            AppIcon(AppIcons.delete, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Delete Item?'),
          ],
        ),
        content: Text('Delete "${item.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _itemService.deleteItem(item.itemId);
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${item.title}" deleted')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = ref.watch(authProvider);

    return ValueListenableBuilder<Color>(
      valueListenable: AccentColorService.currentColor,
      builder: (context, accentColor, _) {
        return Scaffold(
          backgroundColor: AppColors.backgroundZinc,
          appBar: AppBar(
            backgroundColor: AppColors.surfaceZinc,
            elevation: 0,
            centerTitle: false,
            title: Row(
              children: [
                Image.asset(
                  'assets/FWS.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Firewood',
                  style: TextStyle(
                    color: AppColors.offWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: AppIcon(HugeIcons.strokeRoundedLock, color: AppColors.orangeAccent, size: 30),
                tooltip: 'Lock Vault',
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref.read(authProvider.notifier).state = null;
                },
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: key == null
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.orangeAccent),
                )
              : Stack(
                  children: [
                    IndexedStack(
                      index: _currentTabIndex,
                      children: [
                        _buildHomeDashboardTab(key),
                        _buildPasswordsListingTab(key),
                        _buildGeneratorTab(),
                        const SettingsScreen(),
                      ],
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                      child: AppFloatingNavBar(
                        currentIndex: _currentTabIndex,
                        onTap: (index) {
                          HapticFeedback.selectionClick();
                          setState(() => _currentTabIndex = index);
                        },
                      ),
                    ),
                  ],
                ),
          floatingActionButton: (key != null && _currentTabIndex <= 1)
              ? Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 120),
                  child: ScaleTransition(
                    scale: _fabController,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Theme.of(context).colorScheme.primary,
                        border: Border.all(
                          color: AppColors.orangeDark,
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          onTap: () => _showPlusActionSheet(key),
                          child: const Center(
                            child: AppIcon(AppIcons.add, color: Colors.white, size: 26, strokeWidth: 2.2),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  // --- TAB 0: HOME DASHBOARD (Metrics & Summary) ---
  Widget _buildHomeDashboardTab(SecretKey key) {
    return FutureBuilder<List<DecryptedItem>>(
      future: _itemService.getAllItems(key),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];
        final logins = items.where((i) => ItemTypeExt.fromString(i.type) == ItemType.login).toList();
        final cards = items.where((i) => ItemTypeExt.fromString(i.type) == ItemType.card).length;
        final identities = items.where((i) => ItemTypeExt.fromString(i.type) == ItemType.identity).length;
        final notes = items.where((i) => ItemTypeExt.fromString(i.type) == ItemType.note).length;
        final devSecrets = items.where((i) => ItemTypeExt.fromString(i.type) == ItemType.developerSecret).length;
        final report = VaultAnalyticsService.computeReport(items);
        final issueCount =
            SecurityAdvisorSheet.collectIssues(items, DateTime.now()).length;
        final activeAccent = Theme.of(context).colorScheme.primary;

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ROW 1: OVERVIEW & SECURITY HEALTH
                Row(
                  children: [
                    // Card 1: Total Credentials
                    Expanded(
                      child: Container(
                        height: 122,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceZinc,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                AppIcon(AppIcons.shield, size: 40),
                                const Spacer(),
                                Text(
                                  '${report.totalItems}',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.offWhite),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TOTAL CREDENTIALS',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${report.totalItems} Active & Protected',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: activeAccent),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Card 2: Security Health Score
                    Expanded(
                      child: Container(
                        height: 122,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceZinc,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                AppIcon(
                                  AppIcons.shieldCheck,
                                  size: 40,
                                ),
                                const Spacer(),
                                Text(
                                  '${report.securityScore}%',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: report.securityScore >= 80 ? const Color(0xFF22C55E) : report.securityScore >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SECURITY HEALTH',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  report.securityScore >= 80 ? 'Optimal Protection' : report.securityScore >= 50 ? 'Attention Recommended' : 'Action Required',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: report.securityScore >= 80 ? const Color(0xFF22C55E) : report.securityScore >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ROW 2: MINIMAL SECURITY ADVISOR CARD (tap for per-item issues)
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => SecurityAdvisorSheet.show(
                      context,
                      key: key,
                      items: items,
                      onOpenItem: _viewItem,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceZinc,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'SECURITY ADVISOR',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppColors.offWhite),
                          ),
                          const Spacer(),
                          Text(
                            '${report.totpCoveragePercent.round()}% 2FA',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: issueCount > 0 ? AppColors.roseAccent : AppColors.mintAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              issueCount > 0 ? '$issueCount issue${issueCount == 1 ? '' : 's'}' : 'All clear',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Metrics 4-Column Scannable Grid
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.cardZinc,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderZinc, width: 1),
                              ),
                              child: _AnalyticsMetricChip(label: 'Strong', value: '${report.strongPasswords}', color: const Color(0xFF22C55E)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.cardZinc,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderZinc, width: 1),
                              ),
                              child: _AnalyticsMetricChip(label: 'Weak', value: '${report.weakPasswords}', color: report.weakPasswords > 0 ? const Color(0xFFEF4444) : AppColors.textMuted),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.cardZinc,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderZinc, width: 1),
                              ),
                              child: _AnalyticsMetricChip(label: 'Reused', value: '${report.reusedPasswords}', color: report.reusedPasswords > 0 ? const Color(0xFFF59E0B) : AppColors.textMuted),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.cardZinc,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderZinc, width: 1),
                              ),
                              child: _AnalyticsMetricChip(label: 'Compromised', value: '${report.breachedPasswords}', color: report.breachedPasswords > 0 ? const Color(0xFFEF4444) : const Color(0xFF22C55E)),
                            ),
                          ),
                        ],
                      ),

                      if (report.recommendations.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(color: AppColors.borderZinc, height: 1),
                        ),
                        Row(
                          children: [
                            AppIcon(AppIcons.info, size: 14, color: activeAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                report.recommendations.first,
                                style: const TextStyle(fontSize: 11, color: AppColors.offWhite, height: 1.3),
                              ),
                            ),
                            const AppIcon(
                              AppIcons.chevronRight,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                  ),
                ),
                const SizedBox(height: 20),

                // ROW 3: FIVE CREDENTIAL CATEGORY CARDS
                Row(
                  children: [
                    const Text('CREDENTIAL CATEGORIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textMuted)),
                    const Spacer(),
                    Text('${items.length} Total', style: TextStyle(fontSize: 11, color: activeAccent, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _CategorySummaryCard(
                        title: 'Accounts',
                        count: logins.length,
                        subtitle: '${logins.where((i) => (i.fields['totp_secret'] ?? '').toString().trim().isNotEmpty).length} 2FA Active',
                        icon: AppIcons.categoryLogin,
                        accentColor: activeAccent,
                        isSelected: _filterType == ItemType.login,
                        onTap: () => setState(() { _filterType = ItemType.login; _currentTabIndex = 1; }),
                      ),
                      _CategorySummaryCard(
                        title: 'Cards',
                        count: cards,
                        subtitle: 'Encrypted CVV',
                        icon: AppIcons.categoryCard,
                        accentColor: const Color(0xFF3B82F6),
                        isSelected: _filterType == ItemType.card,
                        onTap: () => setState(() { _filterType = ItemType.card; _currentTabIndex = 1; }),
                      ),
                      _CategorySummaryCard(
                        title: 'Identity',
                        count: identities,
                        subtitle: 'ID & Passports',
                        icon: AppIcons.categoryIdentity,
                        accentColor: const Color(0xFF8B5CF6),
                        isSelected: _filterType == ItemType.identity,
                        onTap: () => setState(() { _filterType = ItemType.identity; _currentTabIndex = 1; }),
                      ),
                      _CategorySummaryCard(
                        title: 'Keys',
                        count: devSecrets,
                        subtitle: 'Keys & Tokens',
                        icon: AppIcons.key,
                        accentColor: const Color(0xFF10B981),
                        isSelected: _filterType == ItemType.developerSecret,
                        onTap: () => setState(() { _filterType = ItemType.developerSecret; _currentTabIndex = 1; }),
                      ),
                      _CategorySummaryCard(
                        title: 'Secure Notes',
                        count: notes,
                        subtitle: 'Encrypted Notes',
                        icon: AppIcons.categoryNote,
                        accentColor: const Color(0xFFF43F5E),
                        isSelected: _filterType == ItemType.note,
                        onTap: () => setState(() { _filterType = ItemType.note; _currentTabIndex = 1; }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ROW 4: RECENT ACTIVITY LIST
                Row(
                  children: [
                    const Text('RECENT CREDENTIALS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textMuted)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _currentTabIndex = 1),
                      child: Text('View All', style: TextStyle(color: activeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceZinc,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.4)),
                    ),
                    child: const Column(
                      children: [
                        AppIcon(AppIcons.shield, size: 40, color: AppColors.textMuted),
                        SizedBox(height: 8),
                        Text('Vault is Empty', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Tap + to add your first password or card', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  )
                else
                  ...items.take(4).map(
                        (item) => _ItemTile(
                          item: item,
                          onTap: () => _viewItem(key, item),
                          onDelete: () => _deleteItem(key, item),
                          index: 0,
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- TAB 1: PASSWORDS / VAULT LISTING (Search, Filter, Sort & Grid inline) ---
  Widget _buildPasswordsListingTab(SecretKey key) {
    return FutureBuilder<List<DecryptedItem>>(
      future: _itemService.getAllItems(key),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var items = snapshot.data ?? [];

        // Apply inline search
        if (_searchQuery.isNotEmpty) {
          items = items.where((item) {
            final title = item.title.toLowerCase();
            final query = _searchQuery.toLowerCase();
            final fields = item.fields.values.map((v) => v.toString().toLowerCase()).join(' ');
            return title.contains(query) || fields.contains(query);
          }).toList();
        }

        // Apply category filter
        if (_filterType != null) {
          items = items.where((item) => ItemTypeExt.fromString(item.type) == _filterType).toList();
        }

        // Sort items
        items.sort((a, b) => _sortDescending ? b.updatedAt.compareTo(a.updatedAt) : a.updatedAt.compareTo(b.updatedAt));

        return Column(
          children: [
            // Inline Search Bar & Toolbar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: AppColors.offWhite, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search vault items...',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: AppIcon(AppInputIcons.search, color: AppColors.textMuted, size: 20),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const AppIcon(AppInputIcons.close, color: AppColors.textMuted, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      fillColor: AppColors.surfaceZinc,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Category Dropdown & Styled Controls Row
                  Row(
                    children: [
                      // Category Filter Dropdown
                      Expanded(
                        child: DropdownButtonFormField<ItemType?>(
                          value: _filterType,
                          isExpanded: true,
                          dropdownColor: AppColors.surfaceZinc,
                          borderRadius: BorderRadius.circular(12),
                          icon: AppIcon(AppIcons.chevronDown, color: AppColors.orangeAccent, size: 18),
                          style: const TextStyle(color: AppColors.offWhite, fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.inputZinc,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.borderZinc.withValues(alpha: 0.5)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.borderZinc.withValues(alpha: 0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.orangeAccent, width: 1.5),
                            ),
                          ),
                          items: [
                            DropdownMenuItem<ItemType?>(
                              value: null,
                              child: const Row(
                                children: [
                                  AppIcon(AppIcons.folder, size: 16, color: AppColors.textMuted),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'All Categories',
                                      style: TextStyle(color: AppColors.offWhite, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...ItemType.values.map(
                              (t) => DropdownMenuItem<ItemType?>(
                                value: t,
                                child: Row(
                                  children: [
                                    AppIcon(_getTypeIcon(t), size: 16, color: AppColors.orangeAccent),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        t.label,
                                        style: const TextStyle(color: AppColors.offWhite, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) => setState(() => _filterType = val),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sort Direction Button
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _sortDescending = !_sortDescending),
                        icon: AppIcon(_sortDescending ? AppIcons.chevronDown : AppIcons.chevronUp, size: 16, color: AppColors.orangeAccent),
                        label: Text(_sortDescending ? 'Newest' : 'Oldest', style: const TextStyle(fontSize: 12, color: AppColors.offWhite)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          side: BorderSide(color: AppColors.borderZinc.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Grid/List View Toggle Button
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _isGridView = !_isGridView),
                        icon: AppIcon(_isGridView ? HugeIcons.strokeRoundedListView : HugeIcons.strokeRoundedGridView, size: 16, color: AppColors.orangeAccent),
                        label: Text(_isGridView ? 'List' : 'Grid', style: const TextStyle(fontSize: 12, color: AppColors.offWhite)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          side: BorderSide(color: AppColors.borderZinc.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Listing Area
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text('No matching items', style: TextStyle(color: AppColors.textMuted)),
                    )
                  : _isGridView
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.1,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final type = ItemTypeExt.fromString(item.type);
                            final sub = item.fields['username']?.toString() ?? item.fields['cardholder']?.toString() ?? '••••••••';
                            return Card(
                              color: AppColors.surfaceZinc,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: AppColors.borderZinc.withValues(alpha: 0.5)),
                              ),
                              child: InkWell(
                                onTap: () => _viewItem(key, item),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          AppIcon(_getTypeIcon(type), color: AppColors.orangeAccent, size: 20),
                                          const Spacer(),
                                          const AppIcon(AppIcons.shield, size: 14, color: AppColors.textMuted),
                                        ],
                                      ),
                                      const Spacer(),
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.offWhite),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        sub,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _ItemTile(
                              item: item,
                              onTap: () => _viewItem(key, item),
                              onDelete: () => _deleteItem(key, item),
                              index: index,
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  // --- TAB 2: PASSWORD GENERATOR (Useful Tool Screen) ---
  Widget _buildGeneratorTab() {
    return const _GeneratorToolTab();
  }

  dynamic _getTypeIcon(ItemType type) {
    switch (type) {
      case ItemType.login: return AppIcons.categoryLogin;
      case ItemType.card: return AppIcons.categoryCard;
      case ItemType.identity: return AppIcons.categoryIdentity;
      case ItemType.note: return AppIcons.categoryNote;
      case ItemType.developerSecret: return AppIcons.key;
    }
  }
}

// --- PASSWORD GENERATOR COMPONENT ---
enum _GeneratorMode { password, passphrase, pin }

class _GeneratorToolTab extends ConsumerStatefulWidget {
  const _GeneratorToolTab();

  @override
  ConsumerState<_GeneratorToolTab> createState() => _GeneratorToolTabState();
}

class _GeneratorToolTabState extends ConsumerState<_GeneratorToolTab> {
  _GeneratorMode _mode = _GeneratorMode.password;

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
    _regenerate();
  }

  void _regenerate() {
    String result = '';
    switch (_mode) {
      case _GeneratorMode.password:
        result = GeneratorService.generatePassword(
          length: _passwordLength.round(),
          includeUppercase: _includeUpper,
          includeLowercase: _includeLower,
          includeDigits: _includeDigits,
          includeSymbols: _includeSymbols,
          excludeAmbiguous: _excludeAmbiguous,
        );
        break;
      case _GeneratorMode.passphrase:
        result = GeneratorService.generatePassphrase(
          wordCount: _wordCount.round(),
          separator: _separator,
          capitalize: _capitalizePassphrase,
          includeNumber: _includePassphraseNumber,
        );
        break;
      case _GeneratorMode.pin:
        result = GeneratorService.generatePIN(
          length: _pinLength.round(),
        );
        break;
    }
    setState(() => _generatedSecret = result);
  }

  double get _secretFontSize {
    final len = _generatedSecret.length;
    if (len <= 12) return 20;
    if (len <= 18) return 16;
    if (len <= 26) return 14;
    if (len <= 34) return 12.5;
    return 11;
  }

  @override
  Widget build(BuildContext context) {
    final activeAccent = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GENERATOR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted,
                ),
              ),
              IconButton(
                tooltip: 'Regenerate',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _regenerate();
                },
                icon: AppIcon(HugeIcons.strokeRoundedRefresh, size: 18, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mode Selector Segmented Pill Bar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceZinc,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                _buildModeOption(
                  mode: _GeneratorMode.password,
                  icon: HugeIcons.strokeRoundedLock,
                  activeAccent: activeAccent,
                ),
                _buildModeOption(
                  mode: _GeneratorMode.passphrase,
                  icon: HugeIcons.strokeRoundedText,
                  activeAccent: activeAccent,
                ),
                _buildModeOption(
                  mode: _GeneratorMode.pin,
                  icon: HugeIcons.strokeRoundedPinCode,
                  activeAccent: activeAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Generated Output Box
          Container(
            padding: const EdgeInsets.all(16),
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
                Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  alignment: Alignment.center,
                  child: SelectableText(
                    _generatedSecret,
                    style: TextStyle(
                      fontSize: _secretFontSize,
                      fontFamily: 'Monospace',
                      fontWeight: FontWeight.bold,
                      color: activeAccent,
                      letterSpacing: _mode == _GeneratorMode.pin ? 3.0 : 0.5,
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

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _regenerate();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.offWhite,
                          side: const BorderSide(color: AppColors.borderZinc),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const AppIcon(HugeIcons.strokeRoundedRefresh, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(lockServiceProvider).copySecret(_generatedSecret);
                          HapticFeedback.selectionClick();
                          AppToast.show(
                            context,
                            message: 'Copied to clipboard',
                            type: ToastType.success,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const AppIcon(HugeIcons.strokeRoundedCopy01, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Dynamic Options based on selected Mode
          if (_mode == _GeneratorMode.password) ...[
            _buildSliderRow(
              title: 'Length',
              value: '${_passwordLength.round()}',
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
            _buildGlyphRow([
              ('Aa', _includeUpper, () {
                setState(() => _includeUpper = !_includeUpper);
                _regenerate();
              }),
            ]),
            _buildSwitchTile('Lowercase (a-z)', _includeLower, activeAccent, (v) {
              setState(() => _includeLower = v);
              _regenerate();
            }),
            _buildSwitchTile('Numbers (0-9)', _includeDigits, activeAccent, (v) {
              setState(() => _includeDigits = v);
              _regenerate();
            }),
            _buildSwitchTile('Symbols (!@#\$%^&*)', _includeSymbols, activeAccent, (v) {
              setState(() => _includeSymbols = v);
              _regenerate();
            }),
            _buildSwitchTile('Exclude Ambiguous ({ } [ ] ( ) / \\ ~)', _excludeAmbiguous, activeAccent, (v) {
              setState(() => _excludeAmbiguous = v);
              _regenerate();
            }),
          ] else if (_mode == _GeneratorMode.passphrase) ...[
            _buildSliderRow(
              title: 'Words',
              value: '${_wordCount.round()}',
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Separator Symbol', style: TextStyle(color: AppColors.offWhite, fontSize: 14)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['-', '.', '_', ' '].map((sep) {
                      final isSelected = _separator == sep;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _separator = sep);
                          _regenerate();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? activeAccent : AppColors.surfaceZinc,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? activeAccent : AppColors.borderZinc,
                            ),
                          ),
                          child: Text(
                            sep == ' ' ? 'Space' : sep,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.offWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildSwitchTile('Capitalize Each Word', _capitalizePassphrase, activeAccent, (v) {
              setState(() => _capitalizePassphrase = v);
              _regenerate();
            }),
            _buildSwitchTile('Append 4-Digit Number', _includePassphraseNumber, activeAccent, (v) {
              setState(() => _includePassphraseNumber = v);
              _regenerate();
            }),
          ] else if (_mode == _GeneratorMode.pin) ...[
            _buildSliderRow(
              title: 'Digits',
              value: '${_pinLength.round()}',
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
    );
  }

  Widget _buildModeOption({
    required _GeneratorMode mode,
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.orangeAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.orangeAccent : Colors.transparent,
              width: 1,
            ),
          ),
          child: Center(
            child: AppIcon(
              icon,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlyphRow(List<(String, bool, VoidCallback)> chips) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chip in chips)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              chip.$3();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: chip.$2
                    ? AppColors.orangeAccent
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: chip.$2
                      ? AppColors.orangeAccent
                      : AppColors.borderZinc,
                  width: 1,
                ),
              ),
              child: Text(
                chip.$1,
                style: TextStyle(
                  color: chip.$2
                      ? Colors.white
                      : AppColors.textMuted,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
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
              fontSize: 14,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: activeAccent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.orangeDark),
            ),
            child: Text(
              value,
              style: TextStyle(
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

  Widget _buildSwitchTile(String title, bool value, Color activeAccent, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: AppColors.offWhite, fontSize: 13.5)),
      value: value,
      activeColor: activeAccent,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onChanged: (val) {
        HapticFeedback.selectionClick();
        onChanged(val);
      },
    );
  }
}

class _CategorySummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final dynamic icon;
  final Color? accentColor;
  final bool isSelected;
  final VoidCallback onTap;
  final String? subtitle;

  const _CategorySummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    this.accentColor,
    this.isSelected = false,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      width: 114,
      height: 96,
      margin: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? effectiveAccent : AppColors.surfaceZinc,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? effectiveAccent : AppColors.borderZinc,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppIcon(icon, size: 36),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isSelected ? Colors.white : AppColors.offWhite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.offWhite,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final DecryptedItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final int index;

  const _ItemTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final type = ItemTypeExt.fromString(item.type);
    final activeAccent = Theme.of(context).colorScheme.primary;
    final subtitle = item.fields['username']?.toString() ??
        item.fields['cardholder']?.toString() ??
        '••••••••••••';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceZinc,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: AppIcon(_getTypeIcon(type), size: 42),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.offWhite,
            letterSpacing: -0.1,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        trailing: const AppIcon(AppIcons.chevronRight, color: AppColors.textMuted, size: 18),
        onTap: onTap,
      ),
    );
  }

  dynamic _getTypeIcon(ItemType type) {
    switch (type) {
      case ItemType.login: return AppIcons.categoryLogin;
      case ItemType.card: return AppIcons.categoryCard;
      case ItemType.identity: return AppIcons.categoryIdentity;
      case ItemType.note: return AppIcons.categoryNote;
      case ItemType.developerSecret: return AppIcons.key;
    }
  }
}

class _AnalyticsMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnalyticsMetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}