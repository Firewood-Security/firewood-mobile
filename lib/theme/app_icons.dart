// theme/app_icons.dart
// Centralized icon system for Firewood.
//
// Display icons are 3D PNG assets (assets/icons/cutouts*.png) referenced as
// path constants; navigation, buttons and input chrome use HugeIcons line
// icons explicitly at their call sites. AppIcon renders both.
// Rollback: git revert; hugeicons dep retained.

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AppIcons {
  AppIcons._();

  // Dark 3D icon set used by display icons (dashboard, settings, guides).
  static const _cut = 'assets/icons/cutouts_dark';

  // Navigation
  static const String home = '$_cut/home.png';
  static const String homeFilled = '$_cut/home.png';
  static const String vault = '$_cut/vault-lock.png';
  static const String vaultFilled = '$_cut/vault-lock.png';
  static const String generate = '$_cut/password-generator.png';
  static const String generateFilled = '$_cut/password-generator.png';
  static const String settings = '$_cut/settings-gear.png';
  static const String settingsFilled = '$_cut/settings-gear.png';

  // Categories & Item Types
  static const String categoryLogin = '$_cut/user-login.png';
  static const String categoryCard = '$_cut/credit-card.png';
  static const String categoryIdentity = '$_cut/passport.png';
  static const String categoryNote = '$_cut/secure-note.png';
  static const categoryLicense = HugeIcons.strokeRoundedLicense;
  static const categoryBank = HugeIcons.strokeRoundedBank;

  static const String typeLogin = '$_cut/user-login.png';
  static const String typeCard = '$_cut/credit-card.png';
  static const String typeIdentity = '$_cut/passport.png';
  static const String typeNote = '$_cut/secure-note.png';
  static const String typeDeveloperSecret = '$_cut/api-key.png';

  // Core Actions & Security
  static const String lock = '$_cut/lock.png';
  static const String lockOpen = '$_cut/lock.png';
  static const String lockClock = '$_cut/timer-clock.png';
  static const String unlock = '$_cut/unlock-open.png';
  static const String shield = '$_cut/shield.png';
  static const String shieldCheck = '$_cut/shield-check.png';
  static const String shieldKey = '$_cut/shield-key.png';
  static const String fingerprint = '$_cut/fingerprint.png';
  static const String fire = '$_cut/fire-flame.png';
  static const String key = '$_cut/api-key.png';

  // Interactions & State
  static const String search = '$_cut/search.png';
  static const add = HugeIcons.strokeRoundedPlusSign;
  static const addCircle = HugeIcons.strokeRoundedPlusSignCircle;
  static const String copy = '$_cut/copy.png';
  static const String edit = '$_cut/edit-pencil.png';
  static const String delete = '$_cut/trash-delete.png';
  static const String trash = '$_cut/trash-delete.png';
  static const String view = '$_cut/eye-view.png';
  static const String viewOff = '$_cut/eye-off.png';
  static const String eye = '$_cut/eye-view.png';
  static const String eyeOff = '$_cut/eye-off.png';
  static const String check = '$_cut/checkmark.png';
  static const String checkCircle = '$_cut/checkmark.png';
  static const String close = '$_cut/close-x.png';
  static const String refresh = '$_cut/refresh.png';
  static const magic = HugeIcons.strokeRoundedAiMagic;
  static const sparkles = HugeIcons.strokeRoundedSparkles;
  static const star = HugeIcons.strokeRoundedStar;
  static const String share = '$_cut/share.png';
  static const String qrCode = '$_cut/qr-code.png';
  static const String timer = '$_cut/timer-clock.png';
  static const time = HugeIcons.strokeRoundedClock01;
  static const String help = '$_cut/info.png';
  static const String alert = '$_cut/warning-triangle.png';
  static const String alertCircle = '$_cut/warning-triangle.png';
  static const error = HugeIcons.strokeRoundedAlertCircle;
  static const String info = '$_cut/info.png';
  static const arrowBack = HugeIcons.strokeRoundedArrowLeft01;
  static const arrowLeft = HugeIcons.strokeRoundedArrowLeft01;
  static const arrowRight = HugeIcons.strokeRoundedArrowRight01;
  static const chevronRight = HugeIcons.strokeRoundedArrowRight01;
  static const chevronDown = HugeIcons.strokeRoundedArrowDown01;
  static const chevronUp = HugeIcons.strokeRoundedArrowUp01;

  // Fields & Detail (mixed: asset where available)
  static const String title = '$_cut/title-text.png';
  static const String user = '$_cut/user-login.png';
  static const String link = '$_cut/link-chain.png';
  static const String globe = '$_cut/globe-network.png';
  static const String calendar = '$_cut/calendar.png';
  static const String location = '$_cut/location-pin.png';
  static const car = HugeIcons.strokeRoundedCar01;
  static const String note = '$_cut/secure-note.png';
  static const String hash = '$_cut/hash-tag.png';
  static const number = HugeIcons.strokeRoundedPinCode;
  static const String file = '$_cut/file-document.png';
  static const folder = HugeIcons.strokeRoundedFolder01;
  static const String palette = '$_cut/artist-palette.png';
  static const String download = '$_cut/download.png';
  static const String upload = '$_cut/upload.png';
  static const String cloud = '$_cut/cloud.png';
  static const String cloudUpload = '$_cut/upload.png';
  static const cloudDownload = HugeIcons.strokeRoundedCloudDownload;
  static const sync = HugeIcons.strokeRoundedRefresh;
  static const github = HugeIcons.strokeRoundedGithub;
  static const heart = HugeIcons.strokeRoundedFavourite;
  static const String sort = '$_cut/sort-arrows.png';
  static const String filter = '$_cut/filter-funnel.png';
  static const String history = '$_cut/history-clock.png';
  static const String image = '$_cut/image-picture.png';
  static const String terminal = '$_cut/terminal-code.png';
}

/// Line-icon set reserved for text-input chrome (TextField prefix/suffix
/// icons, visibility toggles, in-field action buttons). Inputs always render
/// HugeIcons regardless of the 3D display set used elsewhere.
class AppInputIcons {
  AppInputIcons._();

  static const title = HugeIcons.strokeRoundedText;
  static const user = HugeIcons.strokeRoundedUser;
  static const lock = HugeIcons.strokeRoundedLockPassword;
  static const lockClock = HugeIcons.strokeRoundedClock01;
  static const link = HugeIcons.strokeRoundedLink01;
  static const shieldKey = HugeIcons.strokeRoundedShieldKey;
  static const note = HugeIcons.strokeRoundedNote;
  static const categoryCard = HugeIcons.strokeRoundedCreditCard;
  static const calendar = HugeIcons.strokeRoundedCalendar03;
  static const shield = HugeIcons.strokeRoundedShield01;
  static const hash = HugeIcons.strokeRoundedPinCode;
  static const location = HugeIcons.strokeRoundedLocation01;
  static const categoryIdentity = HugeIcons.strokeRoundedPassport;
  static const car = HugeIcons.strokeRoundedCar01;
  static const home = HugeIcons.strokeRoundedHome01;
  static const folder = HugeIcons.strokeRoundedFolder01;
  static const key = HugeIcons.strokeRoundedKey01;
  static const globe = HugeIcons.strokeRoundedGlobe02;
  static const search = HugeIcons.strokeRoundedSearch01;
  static const close = HugeIcons.strokeRoundedCancel01;
  static const copy = HugeIcons.strokeRoundedCopy01;
  static const refresh = HugeIcons.strokeRoundedRefresh;
  static const view = HugeIcons.strokeRoundedEye;
  static const viewOff = HugeIcons.strokeRoundedViewOff;
  static const eye = HugeIcons.strokeRoundedEye;
  static const eyeOff = HugeIcons.strokeRoundedViewOff;
  static const delete = HugeIcons.strokeRoundedDelete02;
  static const upload = HugeIcons.strokeRoundedUpload01;
  static const alertCircle = HugeIcons.strokeRoundedAlertCircle;
  static const file = HugeIcons.strokeRoundedFile01;
}

/// Unified icon rendering widget for Firewood.
/// Accepts an asset path (String, rendered full-color, `color` ignored),
/// HugeIcons JSON data, IconData, or a ready Widget.
class AppIcon extends StatelessWidget {
  final dynamic icon;
  final Color? color;
  final double size;
  final double strokeWidth;

  const AppIcon(
    this.icon, {
    super.key,
    this.color,
    this.size = 20,
    this.strokeWidth = 1.6,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color ?? Colors.white;

    final Widget glyph;
    if (icon is String) {
      // 3D asset icon: full-color artwork, tint never applies.
      // Displayed at nominal size (tight-cropped art has no padding).
      final double displaySize = size;
      glyph = SizedBox(
        width: displaySize,
        height: displaySize,
        child: Image.asset(
          icon as String,
          width: displaySize,
          height: displaySize,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    } else if (icon is List<List<dynamic>>) {
      glyph = SizedBox(
        width: size,
        height: size,
        child: HugeIcon(
          icon: icon as List<List<dynamic>>,
          color: effectiveColor,
          size: size,
          strokeWidth: strokeWidth,
        ),
      );
    } else if (icon is IconData) {
      glyph = SizedBox(
        width: size,
        height: size,
        child: Icon(
          icon as IconData,
          color: effectiveColor,
          size: size,
        ),
      );
    } else if (icon is Widget) {
      return icon as Widget;
    } else {
      return const SizedBox.shrink();
    }

    // InputDecorator wraps prefix/suffix icons in ConstrainedBox(min 48x48);
    // a bare SizedBox would be clamped up to 48 and the icon would paint on a
    // 48px canvas. Center loosens the constraints for the child (declared
    // size wins) and centers it inside the forced slot; the factors keep it
    // shrink-wrapped elsewhere so row/button layouts are unchanged.
    return Center(widthFactor: 1.0, heightFactor: 1.0, child: glyph);
  }
}
