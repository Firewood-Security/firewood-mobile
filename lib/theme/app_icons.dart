// theme/app_icons.dart
// Centralized icon system for Firewood.
//
// Phase 3 icon migration: high-traffic icons are 3D PNG assets
// (assets/icons/cutouts/*.png) referenced as path constants; icons without
// a generated asset remain HugeIcons line icons. AppIcon renders both.
// Rollback: git revert of the migration commit; hugeicons dep retained.
// See docs/ICON_MIGRATION.md for the mapping table and gap list.

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AppIcons {
  AppIcons._();

  static const _cut = 'assets/icons/cutouts';

  // Navigation (3D assets)
  static const String home = '$_cut/home.png';
  static const String homeFilled = '$_cut/home.png';
  static const String vault = '$_cut/vault-lock.png';
  static const String vaultFilled = '$_cut/vault-lock.png';
  static const String generate = '$_cut/password-generator.png';
  static const String generateFilled = '$_cut/password-generator.png';
  static const String settings = '$_cut/settings-gear.png';
  static const String settingsFilled = '$_cut/settings-gear.png';

  // Categories & Item Types (3D assets; passport has no generated asset yet)
  static const String categoryLogin = '$_cut/user-login.png';
  static const String categoryCard = '$_cut/credit-card.png';
  static const categoryIdentity = HugeIcons.strokeRoundedPassport;
  static const String categoryNote = '$_cut/secure-note.png';
  static const categoryLicense = HugeIcons.strokeRoundedLicense;
  static const categoryBank = HugeIcons.strokeRoundedBank;

  static const String typeLogin = '$_cut/user-login.png';
  static const String typeCard = '$_cut/credit-card.png';
  static const typeIdentity = HugeIcons.strokeRoundedPassport;
  static const String typeNote = '$_cut/secure-note.png';
  static const String typeDeveloperSecret = '$_cut/api-key.png';

  // Core Actions & Security
  static const String lock = '$_cut/lock.png';
  static const String lockOpen = '$_cut/lock.png';
  static const String lockClock = '$_cut/timer-clock.png';
  static const unlock = HugeIcons.strokeRoundedLockKey;
  static const String shield = '$_cut/shield.png';
  static const String shieldCheck = '$_cut/shield-check.png';
  static const String shieldKey = '$_cut/shield-key.png';
  static const String fingerprint = '$_cut/fingerprint.png';
  static const fire = HugeIcons.strokeRoundedFire;
  static const String key = '$_cut/api-key.png';

  // Interactions & State
  static const String search = '$_cut/search.png';
  static const String add = '$_cut/plus-add.png';
  static const String addCircle = '$_cut/plus-add.png';
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
  static const share = HugeIcons.strokeRoundedShare01;
  static const qrCode = HugeIcons.strokeRoundedQrCode;
  static const String timer = '$_cut/timer-clock.png';
  static const time = HugeIcons.strokeRoundedClock01;
  static const String help = '$_cut/info.png';
  static const String alert = '$_cut/warning-triangle.png';
  static const String alertCircle = '$_cut/warning-triangle.png';
  static const error = HugeIcons.strokeRoundedAlertCircle;
  static const String info = '$_cut/info.png';
  static const String arrowBack = '$_cut/chevron-left.png';
  static const String arrowLeft = '$_cut/chevron-left.png';
  static const String arrowRight = '$_cut/chevron-right.png';
  static const String chevronRight = '$_cut/chevron-right.png';
  static const String chevronDown = '$_cut/chevron-down.png';
  static const String chevronUp = '$_cut/chevron-up.png';

  // Fields & Detail (mixed: asset where available)
  static const title = HugeIcons.strokeRoundedText;
  static const String user = '$_cut/user-login.png';
  static const link = HugeIcons.strokeRoundedLink01;
  static const String globe = '$_cut/globe-network.png';
  static const calendar = HugeIcons.strokeRoundedCalendar03;
  static const location = HugeIcons.strokeRoundedLocation01;
  static const car = HugeIcons.strokeRoundedCar01;
  static const String note = '$_cut/secure-note.png';
  static const hash = HugeIcons.strokeRoundedPinCode;
  static const number = HugeIcons.strokeRoundedPinCode;
  static const file = HugeIcons.strokeRoundedFile01;
  static const folder = HugeIcons.strokeRoundedFolder01;
  static const palette = HugeIcons.strokeRoundedPaintBoard;
  static const String download = '$_cut/download.png';
  static const String upload = '$_cut/upload.png';
  static const cloud = HugeIcons.strokeRoundedCloud;
  static const String cloudUpload = '$_cut/upload.png';
  static const cloudDownload = HugeIcons.strokeRoundedCloudDownload;
  static const sync = HugeIcons.strokeRoundedRefresh;
  static const github = HugeIcons.strokeRoundedGithub;
  static const heart = HugeIcons.strokeRoundedFavourite;
  static const sort = HugeIcons.strokeRoundedSorting01;
  static const filter = HugeIcons.strokeRoundedFilter;
  static const history = HugeIcons.strokeRoundedClock02;
  static const image = HugeIcons.strokeRoundedImage01;
  static const terminal = HugeIcons.strokeRoundedCode;
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

    if (icon is String) {
      // 3D asset icon: full-color artwork, tint never applies.
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          icon as String,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    } else if (icon is List<List<dynamic>>) {
      return SizedBox(
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
      return SizedBox(
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
    }
    return const SizedBox.shrink();
  }
}
