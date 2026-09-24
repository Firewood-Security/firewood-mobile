// providers/workspace_provider.dart
// Desktop "Hearth workspace" UI state: active section, density, focus mode,
// command palette visibility and the resizable list-pane width.

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum WorkspaceDensity { comfortable, compact }

extension WorkspaceDensityX on WorkspaceDensity {
  bool get isCompact => this == WorkspaceDensity.compact;

  String get label =>
      this == WorkspaceDensity.compact ? 'Compact' : 'Comfortable';

  WorkspaceDensity get toggled =>
      this == WorkspaceDensity.compact ? WorkspaceDensity.comfortable : WorkspaceDensity.compact;
}

/// Active workspace section. 0 Dashboard, 1 Vault, 2 Generator, 3 Settings.
final desktopTabProvider = StateProvider<int>((ref) => 0);

final workspaceDensityProvider =
    StateProvider<WorkspaceDensity>((ref) => WorkspaceDensity.comfortable);

final focusModeProvider = StateProvider<bool>((ref) => false);

final commandPaletteOpenProvider = StateProvider<bool>((ref) => false);

/// Width of the master (item list) pane in the three-pane vault workspace.
final listPaneWidthProvider = StateProvider<double>((ref) => 360.0);
