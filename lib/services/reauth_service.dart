// services/reauth_service.dart
// Re-authentication gate for critical actions inside an unlocked session.
//
// Auth policy (2026-09-27): the vault unlock at login is the ONE session
// authentication — browsing an unlocked vault (opening credential pages,
// reading titles/usernames/notes) never re-prompts. Critical actions must
// re-verify through [ReauthService.confirm] before they run:
//   - deleting credentials
//   - masked password reads (reveals / copies of sensitive fields)
//   - enabling biometric unlock
//   - overriding credentials (editing an existing entry, importing over
//     the vault)
//   - AirShare sends
//   - imports / exports / .env dumps / vault burns
// The session itself is time-bounded (LockService session cap and the
// lock-in-recents option), so "never prompt while browsing" never means
// "never prompt again".

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'biometric_service.dart';
import 'native_security_bridge.dart';
import 'vault_service.dart';

class ReauthService {
  ReauthService._();

  /// Returns true only after the user re-verified — biometrics / device
  /// PIN first, master password as fallback. Fails closed: cancellation,
  /// an unreadable native rate-limit state, or a wrong password is `false`.
  static Future<bool> confirm(
    BuildContext context, {
    required String reason,
  }) async {
    if (await BiometricAuthService.authenticateUser(reason: reason)) {
      return true;
    }
    if (!context.mounted) return false;
    return _confirmWithPassword(context, reason);
  }

  static Future<bool> _confirmWithPassword(
    BuildContext context,
    String reason,
  ) async {
    final pwdCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var busy = false;

    final verified = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(builder: (ctx, setDialogState) {
          Future<void> submit() async {
            if (busy) return;
            if (!(formKey.currentState?.validate() ?? false)) return;
            setDialogState(() {
              busy = true;
              error = null;
            });
            final password = pwdCtrl.text;

            // REQ-AUTH-02 / V-026: every password entry point is rate
            // limited, fail closed when the native state cannot be read.
            bool isLockedOut;
            int remainingMs;
            try {
              final lockout = await NativeSecurityBridge.getLockoutStatus();
              isLockedOut = lockout.isLockedOut;
              remainingMs = lockout.lockoutRemainingMs;
            } catch (_) {
              if (ctx.mounted) {
                setDialogState(() {
                  busy = false;
                  error = 'Could not verify unlock rate limit. Try again.';
                });
              }
              return;
            }
            if (isLockedOut) {
              if (ctx.mounted) {
                setDialogState(() {
                  busy = false;
                  error = 'Too many failed attempts. '
                      'Wait ${remainingMs ~/ 1000}s.';
                });
              }
              return;
            }

            try {
              await VaultService().unlock(password);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } on VaultException catch (e) {
              // Best-effort record: even if it fails, the next attempt's
              // fail-closed status read above still refuses to guess.
              try {
                await NativeSecurityBridge.recordFailedUnlockAttempt();
              } catch (_) {}
              if (ctx.mounted) {
                setDialogState(() {
                  busy = false;
                  error = e.message;
                });
              }
            } catch (_) {
              try {
                await NativeSecurityBridge.recordFailedUnlockAttempt();
              } catch (_) {}
              if (ctx.mounted) {
                setDialogState(() {
                  busy = false;
                  error = 'Invalid master password';
                });
              }
            }
          }

          return AlertDialog(
            backgroundColor: AppColors.surfaceZinc,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.borderZinc),
            ),
            title: const Text(
              'Verification Required',
              style: TextStyle(
                color: AppColors.offWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reason,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: pwdCtrl,
                    obscureText: true,
                    style: const TextStyle(color: AppColors.offWhite),
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Master Password',
                      prefixIcon: Icon(Icons.lock_outline, size: 18),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Password required' : null,
                    onFieldSubmitted: (_) => submit(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: const TextStyle(
                          color: AppColors.roseAccent, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: busy ? null : submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orangeAccent,
                  foregroundColor: Colors.white,
                ),
                child: Text(busy ? 'Checking…' : 'Verify'),
              ),
            ],
          );
        });
      },
    );

    // Deliberately NOT disposed: showDialog's future completes at pop,
    // while the route's exit animation is still rebuilding the field —
    // disposing the controller right here crashes that animation ("used
    // after being disposed"). The controller is call-scoped and is
    // collected once the route leaves the tree.
    return verified == true;
  }
}
