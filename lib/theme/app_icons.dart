// theme/app_icons.dart
// Centralized icon system for Firewood.
//
// HugeIcons-only icon registry: every icon is a HugeIcons line icon so the
// app has exactly one icon system. The single exception is `lock3d`, the 3D
// artwork on the top app-bar Lock Vault button. AppIcon renders both.
// Rollback: git revert; hugeicons dep retained.
// See docs/ICON_MIGRATION.md for the mapping table and gap list.

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AppIcons {
  AppIcons._();

  // 3D artwork directory (only `lock3d` still uses it).
  static const _cut = 'assets/icons/cutouts_dark';

  // Navigation
  static const home = HugeIcons.strokeRoundedHome01;
  static const homeFilled = HugeIcons.strokeRoundedHome01;
  static const vault = HugeIcons.strokeRoundedSafeBox;
  static const vaultFilled = HugeIcons.strokeRoundedSafeBox;
  static const generate = HugeIcons.strokeRoundedDice;
  static const generateFilled = HugeIcons.strokeRoundedDice;
  static const settings = HugeIcons.strokeRoundedSettings01;
  static const settingsFilled = HugeIcons.strokeRoundedSettings01;

  // Categories & Item Types
  static const categoryLogin = HugeIcons.strokeRoundedUser;
  static const categoryCard = HugeIcons.strokeRoundedCreditCard;
  static const categoryIdentity = HugeIcons.strokeRoundedPassport;
  static const categoryNote = HugeIcons.strokeRoundedNote;
  static const categoryLicense = HugeIcons.strokeRoundedLicense;
  static const categoryBank = HugeIcons.strokeRoundedBank;

  static const typeLogin = HugeIcons.strokeRoundedUser;
  static const typeCard = HugeIcons.strokeRoundedCreditCard;
  static const typeIdentity = HugeIcons.strokeRoundedPassport;
  static const typeNote = HugeIcons.strokeRoundedNote;
  static const typeDeveloperSecret = HugeIcons.strokeRoundedCode;

  // Core Actions & Security
  static const lock = HugeIcons.strokeRoundedLock;
  // The ONE 3D asset in the app: the top app-bar Lock Vault button.
  static const String lock3d = '$_cut/lock.png';
  static const lockOpen = HugeIcons.strokeRoundedLockPassword;
  static const lockClock = HugeIcons.strokeRoundedClock01;
  static const unlock = HugeIcons.strokeRoundedLockPassword;
  static const shield = HugeIcons.strokeRoundedShield01;
  static const shieldCheck = HugeIcons.strokeRoundedShield02;
  static const shieldKey = HugeIcons.strokeRoundedShieldKey;
  static const fingerprint = HugeIcons.strokeRoundedFingerPrint;
  static const fire = HugeIcons.strokeRoundedFire;
  static const key = HugeIcons.strokeRoundedKey01;

  // Interactions & State
  static const search = HugeIcons.strokeRoundedSearch01;
  static const add = HugeIcons.strokeRoundedPlusSign;
  static const addCircle = HugeIcons.strokeRoundedPlusSignCircle;
  static const copy = HugeIcons.strokeRoundedCopy01;
  static const edit = HugeIcons.strokeRoundedEdit01;
  static const delete = HugeIcons.strokeRoundedDelete02;
  static const trash = HugeIcons.strokeRoundedDelete02;
  static const view = HugeIcons.strokeRoundedEye;
  static const viewOff = HugeIcons.strokeRoundedViewOff;
  static const eye = HugeIcons.strokeRoundedEye;
  static const eyeOff = HugeIcons.strokeRoundedViewOff;
  static const check = HugeIcons.strokeRoundedCheckmarkCircle01;
  static const checkCircle = HugeIcons.strokeRoundedCheckmarkCircle01;
  static const close = HugeIcons.strokeRoundedCancel01;
  static const refresh = HugeIcons.strokeRoundedRefresh;
  static const magic = HugeIcons.strokeRoundedAiMagic;
  static const sparkles = HugeIcons.strokeRoundedSparkles;
  static const star = HugeIcons.strokeRoundedStar;
  static const share = HugeIcons.strokeRoundedShare01;
  static const qrCode = HugeIcons.strokeRoundedQrCode;
  static const timer = HugeIcons.strokeRoundedTimer01;
  static const time = HugeIcons.strokeRoundedClock01;
  static const help = HugeIcons.strokeRoundedInformationCircle;
  static const alert = HugeIcons.strokeRoundedAlertCircle;
  static const alertCircle = HugeIcons.strokeRoundedAlertCircle;
  static const error = HugeIcons.strokeRoundedAlertCircle;
  static const info = HugeIcons.strokeRoundedInformationCircle;
  static const arrowBack = HugeIcons.strokeRoundedArrowLeft01;
  static const arrowLeft = HugeIcons.strokeRoundedArrowLeft01;
  static const arrowRight = HugeIcons.strokeRoundedArrowRight01;
  static const chevronRight = HugeIcons.strokeRoundedArrowRight01;
  static const chevronDown = HugeIcons.strokeRoundedArrowDown01;
  static const chevronUp = HugeIcons.strokeRoundedArrowUp01;

  // Fields & Detail (mixed: asset where available)
  static const title = HugeIcons.strokeRoundedText;
  static const user = HugeIcons.strokeRoundedUser;
  static const link = HugeIcons.strokeRoundedLink01;
  static const globe = HugeIcons.strokeRoundedGlobe02;
  static const calendar = HugeIcons.strokeRoundedCalendar03;
  static const location = HugeIcons.strokeRoundedLocation01;
  static const car = HugeIcons.strokeRoundedCar01;
  static const note = HugeIcons.strokeRoundedNote;
  static const hash = HugeIcons.strokeRoundedPinCode;
  static const number = HugeIcons.strokeRoundedPinCode;
  static const file = HugeIcons.strokeRoundedFile01;
  static const folder = HugeIcons.strokeRoundedFolder01;
  static const palette = HugeIcons.strokeRoundedPaintBrush01;
  static const download = HugeIcons.strokeRoundedDownload01;
  static const upload = HugeIcons.strokeRoundedUpload01;
  static const cloud = HugeIcons.strokeRoundedCloud;
  static const cloudUpload = HugeIcons.strokeRoundedUpload01;
  static const cloudDownload = HugeIcons.strokeRoundedCloudDownload;
  static const sync = HugeIcons.strokeRoundedRefresh;
  static const github = HugeIcons.strokeRoundedGithub;
  static const heart = HugeIcons.strokeRoundedFavourite;
  static const sort = HugeIcons.strokeRoundedArrowUpDown;
  static const filter = HugeIcons.strokeRoundedFilter;
  static const history = HugeIcons.strokeRoundedClock01;
  static const image = HugeIcons.strokeRoundedImage01;
  static const terminal = HugeIcons.strokeRoundedTerminal;
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
