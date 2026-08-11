// models/item_type.dart
// Enum for supported item types in the vault

enum ItemType { login, card, note, identity, developerSecret }

extension ItemTypeExt on ItemType {
  String get label {
    switch (this) {
      case ItemType.login:
        return 'Login';
      case ItemType.card:
        return 'Card';
      case ItemType.note:
        return 'Note';
      case ItemType.identity:
        return 'Identity';
      case ItemType.developerSecret:
        return 'API Key';
    }
  }

  static ItemType fromString(String s) {
    final clean = s.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    if (clean == 'developersecret' || clean == 'apikey' || clean == 'secret') {
      return ItemType.developerSecret;
    }
    return ItemType.values.firstWhere(
      (e) => e.name.toLowerCase() == clean || e.label.toLowerCase().replaceAll(' ', '') == clean,
      orElse: () => ItemType.note,
    );
  }
}