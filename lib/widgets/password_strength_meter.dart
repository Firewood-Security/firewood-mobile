// widgets/password_strength_meter.dart
// Visual cryptographic password strength meter with animated segmented bars, entropy rating, and crack-time estimation

import 'package:flutter/material.dart';
import '../services/generator_service.dart';
import '../theme/app_theme.dart';

class PasswordStrengthMeter extends StatelessWidget {
  final String password;
  final bool compact;
  final bool showRecommendation;

  const PasswordStrengthMeter({
    super.key,
    required this.password,
    this.compact = false,
    this.showRecommendation = false,
  });

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    final evaluation = GeneratorService.evaluateStrength(password);
    final score = evaluation.score; // 0 to 4
    final color = evaluation.color;

    return Container(
      margin: EdgeInsets.only(top: compact ? 6 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 4-Segment Strength Progress Bar
          Row(
            children: List.generate(4, (index) {
              final isFilled = index < score;
              return Expanded(
                child: Container(
                  height: compact ? 4 : 5,
                  margin: EdgeInsets.symmetric(horizontal: index == 0 ? 0 : 2),
                  decoration: BoxDecoration(
                    color: isFilled ? color : AppColors.surfaceZinc,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isFilled
                          ? color
                          : AppColors.borderZinc,
                      width: 0.8,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),

          // Label and Entropy Metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    evaluation.label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 11 : 12,
                    ),
                  ),
                ],
              ),
              Text(
                '~${evaluation.entropyBits.toStringAsFixed(0)} bits · ${evaluation.crackTimeEstimate}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontFamily: 'Monospace',
                ),
              ),
            ],
          ),

          if (showRecommendation && evaluation.recommendation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              evaluation.recommendation,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
