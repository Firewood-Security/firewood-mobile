// theme/app_icons.dart
// Centralized Hugeicons design system for Firewood

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AppIcons {
  AppIcons._();

  // Navigation
  static const home = HugeIcons.strokeRoundedHome01;
  static const homeFilled = HugeIcons.strokeRoundedHome02;
  static const vault = HugeIcons.strokeRoundedLockPassword;
  static const vaultFilled = HugeIcons.strokeRoundedLockPassword;
  static const generate = HugeIcons.strokeRoundedSlidersHorizontal;
  static const generateFilled = HugeIcons.strokeRoundedPasswordValidation;
  static const settings = HugeIcons.strokeRoundedSettings01;
  static const settingsFilled = HugeIcons.strokeRoundedSettings02;

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
  static const typeDeveloperSecret = HugeIcons.strokeRoundedKey01;

  // Core Actions & Security
  static const lock = HugeIcons.strokeRoundedLockPassword;
  static const lockOpen = HugeIcons.strokeRoundedLockKey;
  static const lockClock = HugeIcons.strokeRoundedClock01;
  static const unlock = HugeIcons.strokeRoundedLockKey;
  static const shield = HugeIcons.strokeRoundedShield01;
  static const shieldCheck = HugeIcons.strokeRoundedShield01;
  static const shieldKey = HugeIcons.strokeRoundedShieldKey;
  static const fingerprint = HugeIcons.strokeRoundedFingerPrint;
  static const fire = HugeIcons.strokeRoundedFire;
  static const key = HugeIcons.strokeRoundedKey01;

  // Interactions & State
  static const search = HugeIcons.strokeRoundedSearch01;
  static const add = HugeIcons.strokeRoundedPlusSign;
  static const addCircle = HugeIcons.strokeRoundedPlusSignCircle;
  static const copy = HugeIcons.strokeRoundedCopy01;
  static const edit = HugeIcons.strokeRoundedEdit02;
  static const delete = HugeIcons.strokeRoundedDelete02;
  static const trash = HugeIcons.strokeRoundedDelete02;
  static const view = HugeIcons.strokeRoundedEye;
  static const viewOff = HugeIcons.strokeRoundedViewOff;
  static const eye = HugeIcons.strokeRoundedEye;
  static const eyeOff = HugeIcons.strokeRoundedViewOff;
  static const check = HugeIcons.strokeRoundedTick01;
  static const checkCircle = HugeIcons.strokeRoundedCheckmarkCircle02;
  static const close = HugeIcons.strokeRoundedCancel01;
  static const refresh = HugeIcons.strokeRoundedRefresh;
  static const magic = HugeIcons.strokeRoundedAiMagic;
  static const sparkles = HugeIcons.strokeRoundedSparkles;
  static const star = HugeIcons.strokeRoundedStar;
  static const share = HugeIcons.strokeRoundedShare01;
  static const qrCode = HugeIcons.strokeRoundedQrCode;
  static const timer = HugeIcons.strokeRoundedClock01;
  static const help = HugeIcons.strokeRoundedHelpCircle;
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

  // Fields & Detail
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
  static const palette = HugeIcons.strokeRoundedPaintBoard;
  static const download = HugeIcons.strokeRoundedDownload01;
  static const upload = HugeIcons.strokeRoundedUpload01;
  static const cloud = HugeIcons.strokeRoundedCloud;
  static const cloudUpload = HugeIcons.strokeRoundedCloudUpload;
  static const cloudDownload = HugeIcons.strokeRoundedCloudDownload;
  static const sync = HugeIcons.strokeRoundedRefresh;
  static const github = HugeIcons.strokeRoundedGithub;
  static const heart = HugeIcons.strokeRoundedFavourite;
  static const sort = HugeIcons.strokeRoundedSorting01;
  static const filter = HugeIcons.strokeRoundedFilter;
  static const history = HugeIcons.strokeRoundedClock02;
  static const time = HugeIcons.strokeRoundedClock01;
  static const image = HugeIcons.strokeRoundedImage01;
  static const terminal = HugeIcons.strokeRoundedCode;
}

/// Unified icon rendering widget for Firewood
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

    if (icon is List<List<dynamic>>) {
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
