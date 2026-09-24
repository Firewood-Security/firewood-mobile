// Update screen: hero status section (live update-check process) with the
// release changelog below. TLS-only checks (Q-09): no authenticated-update
// claims are made here — status reflects version comparison only.

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_version_service.dart';
import '../services/update_service.dart';
import '../theme/app_button.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

enum _CheckState { checking, available, upToDate }

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  _CheckState _state = _CheckState.checking;
  AppUpdateInfo? _info;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _state = _CheckState.checking;
      _info = null;
    });
    final info = await UpdateService().checkAppUpdate();
    if (!mounted) return;
    setState(() {
      _info = info;
      _state = info.hasUpdate ? _CheckState.available : _CheckState.upToDate;
    });
  }

  Future<void> _download() async {
    final url = _info?.downloadUrl ?? '';
    if (url.isEmpty) return;
    setState(() => _downloading = true);
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeAccent = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: AppColors.surfaceZinc,
      appBar: AppBar(
        title: const Text('Updates', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const AppIcon(HugeIcons.strokeRoundedArrowLeft01, color: AppColors.offWhite, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Re-check',
            onPressed: _state == _CheckState.checking ? null : _check,
            icon: const AppIcon(HugeIcons.strokeRoundedRefresh, color: AppColors.textMuted, size: 20),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- Hero: update check process ---
          _buildHero(theme, activeAccent),
          const SizedBox(height: 20),

          // --- Changelog ---
          _buildChangelog(theme),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Installed ${AppVersionService.fullVersionString} • Build ${AppVersionService.buildNumber}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(ThemeData theme, Color activeAccent) {
    late final dynamic stateIcon;
    late final String title;
    late final String subtitle;

    switch (_state) {
      case _CheckState.checking:
        stateIcon = HugeIcons.strokeRoundedRefresh;
        title = 'Checking for updates';
        subtitle = 'Contacting the secure update channel…';
        break;
      case _CheckState.available:
        stateIcon = HugeIcons.strokeRoundedDownload01;
        title = 'Update available';
        subtitle = 'Version ${_info?.version ?? ''} is ready to download.';
        break;
      case _CheckState.upToDate:
        stateIcon = HugeIcons.strokeRoundedCheckmarkCircle01;
        title = 'You are up to date';
        subtitle = 'Running the latest verified release of Firewood.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardZinc,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _state == _CheckState.available ? activeAccent : AppColors.borderZinc,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_state == _CheckState.checking)
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: activeAccent,
                    ),
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _state == _CheckState.checking
                      ? RotatingIcon(icon: stateIcon, color: activeAccent, size: 30)
                      : AppIcon(
                          stateIcon,
                          key: ValueKey(stateIcon),
                          size: 34,
                          color: _state == _CheckState.available ? activeAccent : AppColors.mintAccent,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.offWhite,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4),
            textAlign: TextAlign.center,
          ),
          if (_state == _CheckState.available) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: _downloading ? 'Opening…' : 'Download Update',
                icon: HugeIcons.strokeRoundedDownload01,
                variant: AppButtonVariant.primary,
                fullWidth: true,
                onPressed: _downloading ? null : _download,
              ),
            ),
          ],
          if (_state == _CheckState.available && _info != null) ...[
            const SizedBox(height: 12),
            _VersionCompareRow(
              current: AppVersionService.fullVersionString,
              latest: 'v${_info!.version}',
              accent: activeAccent,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChangelog(ThemeData theme) {
    final checking = _state == _CheckState.checking;
    final notes = _info?.releaseNotes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardZinc,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderZinc, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(HugeIcons.strokeRoundedFile01, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'CHANGELOG',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (checking)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted),
                ),
              ),
            )
          else
            Text(
              notes ?? 'No release notes for this version.',
              style: const TextStyle(
                color: AppColors.offWhite,
                fontSize: 13,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }
}

class _VersionCompareRow extends StatelessWidget {
  final String current;
  final String latest;
  final Color accent;

  const _VersionCompareRow({
    required this.current,
    required this.latest,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    Widget pill(String text, Color fg, Color bg, Color border) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 1),
          ),
          child: Text(
            text,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: fg),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        pill(current, AppColors.textMuted, AppColors.surfaceZinc, AppColors.borderZinc),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: AppIcon(HugeIcons.strokeRoundedArrowRight01, size: 14, color: AppColors.textMuted),
        ),
        pill(latest, Colors.white, accent, AppColors.orangeDark),
      ],
    );
  }
}

class RotatingIcon extends StatefulWidget {
  final dynamic icon;
  final Color color;
  final double size;

  const RotatingIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  State<RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<RotatingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: AppIcon(widget.icon, size: widget.size, color: widget.color),
    );
  }
}
