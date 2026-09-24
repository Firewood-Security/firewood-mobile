// screens/item_detail_screen.dart
// Minimalist, category-tailored credential editor supporting Login, Card, Identity (with ID image attachments), and Notes

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item_type.dart';
import '../services/item_service.dart';
import '../services/lock_service.dart';
import '../services/generator_service.dart';
import '../widgets/password_strength_meter.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_button.dart';
import '../theme/app_feedback.dart';
import '../widgets/category_segmented_bar.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final SecretKey secretKey;
  final ItemService itemService;
  final DecryptedItem? existingItem;

  const ItemDetailScreen({
    super.key,
    required this.secretKey,
    required this.itemService,
    this.existingItem,
  });

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  ItemType _selectedType = ItemType.login;

  // Category specific controllers
  // Login
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();
  final _totpController = TextEditingController();

  // Card
  final _cardholderController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _pinController = TextEditingController();
  final _zipController = TextEditingController();

  // Identity
  final _fullNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _passportController = TextEditingController();
  final _licenseController = TextEditingController();
  final _dobController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _idImageBase64;

  // Note
  final _noteController = TextEditingController();

  // Developer Secret
  final _devSecretTypeController = TextEditingController();
  final _devSecretKeyController = TextEditingController();
  final _devPublicKeyController = TextEditingController();
  final _devConfigController = TextEditingController();

  // Focus nodes to immediately re-mask when moving to a new field
  final _passwordFocusNode = FocusNode();
  final _cvvFocusNode = FocusNode();
  final _pinFocusNode = FocusNode();
  final _devSecretKeyFocusNode = FocusNode();

  // Custom Extra Fields
  final List<_CustomField> _customFields = [];

  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureCvv = true;
  bool _obscurePin = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Mask immediately when unfocused / moving to another field
    _passwordFocusNode.addListener(() {
      if (!_passwordFocusNode.hasFocus && mounted) {
        setState(() => _obscurePassword = true);
      }
    });
    _cvvFocusNode.addListener(() {
      if (!_cvvFocusNode.hasFocus && mounted) {
        setState(() => _obscureCvv = true);
      }
    });
    _pinFocusNode.addListener(() {
      if (!_pinFocusNode.hasFocus && mounted) {
        setState(() => _obscurePin = true);
      }
    });
    _devSecretKeyFocusNode.addListener(() {
      if (!_devSecretKeyFocusNode.hasFocus && mounted) {
        setState(() => _obscurePassword = true);
      }
    });

    _passwordController.addListener(_onPasswordChanged);

    _loadExistingItemData();
  }

  void _onPasswordChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _fadeController.dispose();
    _passwordFocusNode.dispose();
    _cvvFocusNode.dispose();
    _pinFocusNode.dispose();
    _devSecretKeyFocusNode.dispose();
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _totpController.dispose();
    _cardholderController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _pinController.dispose();
    _zipController.dispose();
    _fullNameController.dispose();
    _idNumberController.dispose();
    _passportController.dispose();
    _licenseController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    for (final f in _customFields) {
      f.dispose();
    }
    super.dispose();
  }

  void _loadExistingItemData() {
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _titleController.text = item.title;
      _selectedType = ItemTypeExt.fromString(item.type);
      final fields = item.fields;

      switch (_selectedType) {
        case ItemType.login:
          _usernameController.text = fields['username']?.toString() ?? '';
          _passwordController.text = fields['password']?.toString() ?? '';
          _urlController.text = fields['url']?.toString() ?? '';
          _totpController.text = fields['totp_secret']?.toString() ?? '';
          _noteController.text = fields['notes']?.toString() ?? '';
          break;

        case ItemType.card:
          _cardholderController.text = fields['cardholder']?.toString() ?? '';
          _cardNumberController.text = fields['number']?.toString() ?? '';
          _expiryController.text = fields['expiry']?.toString() ?? '';
          _cvvController.text = fields['cvv']?.toString() ?? '';
          _pinController.text = fields['pin']?.toString() ?? '';
          _zipController.text = fields['zip']?.toString() ?? '';
          _noteController.text = fields['notes']?.toString() ?? '';
          break;

        case ItemType.identity:
          _fullNameController.text = fields['full_name']?.toString() ?? '';
          _idNumberController.text = fields['id_number']?.toString() ?? '';
          _passportController.text = fields['passport']?.toString() ?? '';
          _licenseController.text = fields['license']?.toString() ?? '';
          _dobController.text = fields['dob']?.toString() ?? '';
          _addressController.text = fields['address']?.toString() ?? '';
          _phoneController.text = fields['phone']?.toString() ?? '';
          _idImageBase64 = fields['id_image']?.toString();
          _noteController.text = fields['notes']?.toString() ?? '';
          break;

        case ItemType.note:
          _noteController.text = fields['content']?.toString() ?? fields['notes']?.toString() ?? '';
          break;

        case ItemType.developerSecret:
          _devSecretTypeController.text = fields['secret_type']?.toString() ?? '';
          _devSecretKeyController.text = fields['secret_key']?.toString() ?? '';
          _devPublicKeyController.text = fields['public_key']?.toString() ?? '';
          _devConfigController.text = fields['config_data']?.toString() ?? '';
          _noteController.text = fields['notes']?.toString() ?? '';
          break;
      }

      // Populate any remaining non-standard fields as custom fields (never include timestamps, dates, or known category keys)
      final ignoredKeys = {
        'username', 'password', 'url', 'totp_secret', 'notes',
        'cardholder', 'number', 'expiry', 'cvv', 'pin', 'zip',
        'full_name', 'id_number', 'passport', 'license', 'dob', 'address', 'phone', 'id_image', 'content',
        'secret_type', 'secret_key', 'public_key', 'config_data',
        'createdAt', 'updatedAt', 'created_at', 'updated_at', 'timestamp', 'date', 'date_created', 'date_modified',
        'dateCreated', 'dateModified', 'lastModified', 'id', 'uuid', 'isFavorite', 'is_favorite', 'trash'
      };

      fields.forEach((key, val) {
        if (!ignoredKeys.contains(key) && val != null && val.toString().trim().isNotEmpty) {
          _customFields.add(_CustomField(
            keyController: TextEditingController(text: key),
            valueController: TextEditingController(text: val.toString()),
          ));
        }
      });
    }
  }

  Future<void> _pickIdentityImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final base64Str = base64Encode(bytes);
        setState(() {
          _idImageBase64 = base64Str;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _generatePassword() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PasswordGeneratorSheet(
        initialPassword: _passwordController.text,
      ),
    ).then((generated) {
      if (generated != null && generated.isNotEmpty) {
        setState(() {
          _passwordController.text = generated;
          _obscurePassword = false;
        });
        HapticFeedback.selectionClick();
        if (mounted) {
          AppToast.show(
            context,
            message: 'Password applied to credential',
            type: ToastType.success,
          );
        }
      }
    });
  }

  Map<String, dynamic> _buildPayload() {
    final fields = <String, dynamic>{};

    switch (_selectedType) {
      case ItemType.login:
        if (_usernameController.text.isNotEmpty) fields['username'] = _usernameController.text.trim();
        if (_passwordController.text.isNotEmpty) fields['password'] = _passwordController.text;
        if (_urlController.text.isNotEmpty) fields['url'] = _urlController.text.trim();
        if (_totpController.text.isNotEmpty) fields['totp_secret'] = _totpController.text.trim();
        if (_noteController.text.isNotEmpty) fields['notes'] = _noteController.text.trim();
        break;

      case ItemType.card:
        if (_cardholderController.text.isNotEmpty) fields['cardholder'] = _cardholderController.text.trim();
        if (_cardNumberController.text.isNotEmpty) fields['number'] = _cardNumberController.text.trim();
        if (_expiryController.text.isNotEmpty) fields['expiry'] = _expiryController.text.trim();
        if (_cvvController.text.isNotEmpty) fields['cvv'] = _cvvController.text.trim();
        if (_pinController.text.isNotEmpty) fields['pin'] = _pinController.text.trim();
        if (_zipController.text.isNotEmpty) fields['zip'] = _zipController.text.trim();
        if (_noteController.text.isNotEmpty) fields['notes'] = _noteController.text.trim();
        break;

      case ItemType.identity:
        if (_fullNameController.text.isNotEmpty) fields['full_name'] = _fullNameController.text.trim();
        if (_idNumberController.text.isNotEmpty) fields['id_number'] = _idNumberController.text.trim();
        if (_passportController.text.isNotEmpty) fields['passport'] = _passportController.text.trim();
        if (_licenseController.text.isNotEmpty) fields['license'] = _licenseController.text.trim();
        if (_dobController.text.isNotEmpty) fields['dob'] = _dobController.text.trim();
        if (_addressController.text.isNotEmpty) fields['address'] = _addressController.text.trim();
        if (_phoneController.text.isNotEmpty) fields['phone'] = _phoneController.text.trim();
        if (_idImageBase64 != null) fields['id_image'] = _idImageBase64;
        if (_noteController.text.isNotEmpty) fields['notes'] = _noteController.text.trim();
        break;

      case ItemType.note:
        if (_noteController.text.isNotEmpty) fields['content'] = _noteController.text.trim();
        break;

      case ItemType.developerSecret:
        if (_devSecretTypeController.text.isNotEmpty) fields['secret_type'] = _devSecretTypeController.text.trim();
        if (_devSecretKeyController.text.isNotEmpty) fields['secret_key'] = _devSecretKeyController.text;
        if (_devPublicKeyController.text.isNotEmpty) fields['public_key'] = _devPublicKeyController.text.trim();
        if (_devConfigController.text.isNotEmpty) fields['config_data'] = _devConfigController.text;
        if (_noteController.text.isNotEmpty) fields['notes'] = _noteController.text.trim();
        break;
    }

    // Custom fields
    for (final cf in _customFields) {
      final k = cf.keyController.text.trim();
      final v = cf.valueController.text.trim();
      if (k.isNotEmpty && v.isNotEmpty) {
        fields[k] = v;
      }
    }

    return fields;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final payload = _buildPayload();
    if (payload.isEmpty) {
      setState(() => _error = 'Please fill out at least one field');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final title = _titleController.text.trim();
      final typeStr = _selectedType.label;

      if (widget.existingItem != null) {
        await widget.itemService.updateItem(
          key: widget.secretKey,
          itemId: widget.existingItem!.itemId,
          newFields: payload,
          newTitle: title,
        );
      } else {
        await widget.itemService.addItem(
          key: widget.secretKey,
          type: typeStr,
          title: title,
          fields: payload,
        );
      }

      if (mounted) {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = 'Failed to save credential: $e');
      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmDelete() async {
    final confirm = await AppDialog.showConfirmation(
      context,
      title: 'Delete Credential?',
      message: 'Delete "${widget.existingItem!.title}" permanently from your encrypted vault?',
      confirmLabel: 'Delete',
      isDanger: true,
      icon: AppIcons.delete,
    );

    if (confirm == true) {
      try {
        await widget.itemService.deleteItem(widget.existingItem!.itemId);
        if (mounted) {
          AppToast.show(context, message: 'Credential deleted successfully', type: ToastType.info);
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) AppToast.show(context, message: 'Failed to delete: $e', type: ToastType.error);
      }
    }
  }

  void _showCategoryFieldGuide(BuildContext context) {
    HapticFeedback.lightImpact();
    final activeAccent = Theme.of(context).colorScheme.primary;

    final List<_FieldGuideItem> guideItems;
    final String categoryTitle;
    final String categoryDesc;
    final dynamic categoryIcon;

    switch (_selectedType) {
      case ItemType.login:
        categoryTitle = 'Login Credentials Guide';
        categoryDesc = 'Security guidelines for web accounts, logins, and 2FA keys';
        categoryIcon = AppIcons.lock;
        guideItems = const [
          _FieldGuideItem(
            name: 'Title *',
            description: 'Name of the service, website, or application (e.g. Google, GitHub, Netflix).',
            icon: AppIcons.title,
          ),
          _FieldGuideItem(
            name: 'Username / Email',
            description: 'Account login identifier, handle, or registered email address.',
            icon: AppIcons.user,
          ),
          _FieldGuideItem(
            name: 'Password',
            description: 'Confidential account secret. Auto-obscures on field change. Tap the wand icon to generate high-entropy passwords.',
            icon: AppIcons.key,
          ),
          _FieldGuideItem(
            name: 'Website URL',
            description: 'Login page URL for fast browser access and credential association.',
            icon: AppIcons.link,
          ),
          _FieldGuideItem(
            name: '2FA / TOTP Secret Key',
            description: 'Base32 authenticator secret (e.g. JBSWY3DPEHPK3PXP). Generates real-time 6-digit rolling 2FA codes without third-party apps.',
            icon: AppIcons.shieldCheck,
          ),
          _FieldGuideItem(
            name: 'Custom Extra Fields',
            description: 'Store recovery codes, security questions, or secondary account IDs.',
            icon: AppIcons.addCircle,
          ),
        ];
        break;

      case ItemType.card:
        categoryTitle = 'Payment Card Guide';
        categoryDesc = 'Sensitive credit, debit, and banking card protection';
        categoryIcon = AppIcons.categoryCard;
        guideItems = const [
          _FieldGuideItem(
            name: 'Cardholder Name',
            description: 'Full name printed on the card.',
            icon: AppIcons.user,
          ),
          _FieldGuideItem(
            name: 'Card Number',
            description: '16-digit PAN stored in the encrypted vault.',
            icon: AppIcons.categoryCard,
          ),
          _FieldGuideItem(
            name: 'Expiry Date',
            description: 'Card validity month and year (MM/YY).',
            icon: AppIcons.calendar,
          ),
          _FieldGuideItem(
            name: 'CVV / CVC Security Code',
            description: '3 or 4 digit security verification code. Obscured by default.',
            icon: AppIcons.shield,
          ),
          _FieldGuideItem(
            name: 'Card PIN',
            description: 'ATM or merchant chip PIN code for contactless & debit transactions.',
            icon: AppIcons.hash,
          ),
          _FieldGuideItem(
            name: 'Billing ZIP / Postal Code',
            description: 'Address verification code required for online transactions.',
            icon: AppIcons.location,
          ),
        ];
        break;

      case ItemType.identity:
        categoryTitle = 'Identity Document Guide';
        categoryDesc = 'Government-issued IDs, passports, driver licenses, and scanned attachments';
        categoryIcon = AppIcons.categoryIdentity;
        guideItems = const [
          _FieldGuideItem(
            name: 'Full Legal Name',
            description: 'Full legal name as it appears on official government records.',
            icon: AppIcons.user,
          ),
          _FieldGuideItem(
            name: 'Date of Birth & Address',
            description: 'Official identity demographics for fast copy & paste during verification.',
            icon: AppIcons.location,
          ),
          _FieldGuideItem(
            name: 'ID Document Attachment',
            description: 'Encrypted local document photo. Stored securely offline in your vault.',
            icon: AppIcons.image,
          ),
        ];
        break;

      case ItemType.note:
        categoryTitle = 'Secure Note Guide';
        categoryDesc = 'Guidelines for confidential notes, recovery seeds, and memos';
        categoryIcon = AppIcons.categoryNote;
        guideItems = const [
          _FieldGuideItem(
            name: 'Title *',
            description: 'Identifiable subject title for this confidential note.',
            icon: AppIcons.title,
          ),
          _FieldGuideItem(
            name: 'Secure Note Content',
            description: 'Freeform text, recovery mnemonics (12/24 words), private memos, or server keys.',
            icon: AppIcons.note,
          ),
          _FieldGuideItem(
            name: 'Custom Extra Fields',
            description: 'Add key-value metadata pairs for structured secrets.',
            icon: AppIcons.addCircle,
          ),
        ];
        break;

      case ItemType.developerSecret:
        categoryTitle = 'Developer Secret Guide';
        categoryDesc = 'Guidelines for API keys, SSH credentials, and environment configs';
        categoryIcon = AppIcons.typeDeveloperSecret;
        guideItems = const [
          _FieldGuideItem(
            name: 'Secret Sub-Type',
            description: 'Tag or identifier (e.g. AWS_ACCESS_KEY, Stripe API, SSH Key, DB URI).',
            icon: AppIcons.typeDeveloperSecret,
          ),
          _FieldGuideItem(
            name: 'Secret / Private Key',
            description: 'Confidential API key, secret token, or private PEM cryptographic key.',
            icon: AppIcons.key,
          ),
          _FieldGuideItem(
            name: 'Public Key / Endpoint',
            description: 'Public SSH key, server host URL, or webhook receiving endpoint.',
            icon: AppIcons.globe,
          ),
          _FieldGuideItem(
            name: 'Configuration Data',
            description: 'Multi-line .env, JSON, or YAML configuration payload.',
            icon: AppIcons.file,
          ),
        ];
        break;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF16161A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderZinc,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      AppIcon(categoryIcon, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              categoryTitle,
                              style: const TextStyle(
                                color: AppColors.offWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              categoryDesc,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...guideItems.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceZinc,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppIcon(item.icon, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      color: AppColors.offWhite,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.description,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isEditing = widget.existingItem != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundZinc,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit ${widget.existingItem!.title}' : 'Add Credential'),
        actions: [
          IconButton(
            icon: AppIcon(AppIcons.help, color: AppColors.orangeAccent, size: 22),
            tooltip: 'Category & Fields Guide',
            onPressed: () => _showCategoryFieldGuide(context),
          ),
          if (isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AppButton(
                label: 'Delete',
                icon: AppIcons.delete,
                variant: AppButtonVariant.danger,
                height: 36,
                fontSize: 12,
                onPressed: _confirmDelete,
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              if (_error != null)
                Container(
                  width: double.infinity,
                  color: cs.errorContainer,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      AppIcon(AppIcons.alert, color: cs.onErrorContainer, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                  children: [
                    // Category Selection Header Tabs
                    _buildCategorySelector(),
                    const SizedBox(height: 24),

                    // Title Input Field
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title *',
                        hintText: _selectedType == ItemType.login
                            ? 'e.g. Google, GitHub, Netflix'
                            : _selectedType == ItemType.card
                                ? 'e.g. Chase Freedom, Amex Platinum'
                                : _selectedType == ItemType.identity
                                    ? 'e.g. Passport, Driver License'
                                    : 'e.g. Recovery Phrase, Server Keys',
                        prefixIcon: AppIcon(AppIcons.title, color: AppColors.orangeAccent),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title required' : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),

                    // Category Specific Forms
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildCategoryForm(),
                    ),

                    const SizedBox(height: 24),

                    // Custom Extra Fields
                    _buildCustomFieldsSection(),
                    const SizedBox(height: 32),

                    // Save Action Button
                    AppButton(
                      label: _isLoading ? 'Saving...' : (isEditing ? 'Save Changes' : 'Save Credential'),
                      icon: AppIcons.checkCircle,
                      variant: AppButtonVariant.primary,
                      isLoading: _isLoading,
                      fullWidth: true,
                      height: 52,
                      onPressed: _isLoading ? null : _save,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return CategorySegmentedBar(
      selectedType: _selectedType,
      onSelected: (type) {
        setState(() => _selectedType = type);
      },
    );
  }

  Widget _buildCategoryForm() {
    switch (_selectedType) {
      case ItemType.login:
        return _buildLoginForm();
      case ItemType.card:
        return _buildCardForm();
      case ItemType.identity:
        return _buildIdentityForm();
      case ItemType.note:
        return _buildNoteForm();
      case ItemType.developerSecret:
        return _buildDeveloperSecretForm();
    }
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login_form'),
      children: [
        TextFormField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Username / Email',
            prefixIcon: AppIcon(AppIcons.user, size: 20),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const AppIcon(AppIcons.lock, size: 20),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_passwordController.text.isNotEmpty)
                  IconButton(
                    icon: const AppIcon(AppIcons.copy, color: AppColors.textMuted, size: 18),
                    tooltip: 'Copy Password',
                    onPressed: () {
                      ref.read(lockServiceProvider).copySecret(_passwordController.text);
                      HapticFeedback.selectionClick();
                      AppToast.show(
                        context,
                        message: 'Password copied to clipboard',
                        type: ToastType.success,
                      );
                    },
                  ),
                IconButton(
                  icon: AppIcon(AppIcons.refresh, color: AppColors.orangeAccent, size: 20),
                  tooltip: 'Generate Password',
                  onPressed: _generatePassword,
                ),
                IconButton(
                  icon: AppIcon(_obscurePassword ? AppIcons.viewOff : AppIcons.view, size: 20),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ],
            ),
          ),
          textInputAction: TextInputAction.next,
        ),
        if (_passwordController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: PasswordStrengthMeter(
              password: _passwordController.text,
              compact: true,
            ),
          ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'Website URL',
            prefixIcon: AppIcon(AppIcons.link, size: 20),
            hintText: 'https://example.com',
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _totpController,
          decoration: const InputDecoration(
            labelText: '2FA / TOTP Secret Key',
            prefixIcon: AppIcon(AppIcons.shieldKey, size: 20),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'Notes',
            prefixIcon: AppIcon(AppIcons.note, size: 20),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildCardForm() {
    return Column(
      key: const ValueKey('card_form'),
      children: [
        TextFormField(
          controller: _cardholderController,
          decoration: const InputDecoration(
            labelText: 'Cardholder Name',
            prefixIcon: AppIcon(AppIcons.user),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cardNumberController,
          decoration: const InputDecoration(
            labelText: 'Card Number',
            prefixIcon: AppIcon(AppIcons.categoryCard),
            hintText: '0000 0000 0000 0000',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _CreditCardFormatter(),
          ],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _expiryController,
                decoration: const InputDecoration(
                  labelText: 'Expiry (MM/YY)',
                  prefixIcon: AppIcon(AppIcons.calendar),
                  hintText: 'MM/YY',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ExpiryDateFormatter(),
                ],
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _cvvController,
                focusNode: _cvvFocusNode,
                obscureText: _obscureCvv,
                decoration: InputDecoration(
                  labelText: 'CVV',
                  prefixIcon: const AppIcon(AppIcons.shield),
                  suffixIcon: IconButton(
                    icon: AppIcon(_obscureCvv ? AppIcons.viewOff : AppIcons.view),
                    onPressed: () => setState(() => _obscureCvv = !_obscureCvv),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _pinController,
                focusNode: _pinFocusNode,
                obscureText: _obscurePin,
                decoration: InputDecoration(
                  labelText: 'Card PIN',
                  prefixIcon: const AppIcon(AppIcons.hash),
                  suffixIcon: IconButton(
                    icon: AppIcon(_obscurePin ? AppIcons.viewOff : AppIcons.view),
                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _zipController,
                decoration: const InputDecoration(
                  labelText: 'ZIP / Postal Code',
                  prefixIcon: AppIcon(AppIcons.location),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'Notes',
            prefixIcon: AppIcon(AppIcons.note),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildIdentityForm() {
    return Column(
      key: const ValueKey('identity_form'),
      children: [
        TextFormField(
          controller: _fullNameController,
          decoration: const InputDecoration(
            labelText: 'Full Legal Name',
            prefixIcon: AppIcon(AppIcons.user),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _idNumberController,
          decoration: const InputDecoration(
            labelText: 'National ID / SSN Number',
            prefixIcon: AppIcon(AppIcons.hash),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _passportController,
                decoration: const InputDecoration(
                  labelText: 'Passport #',
                  prefixIcon: AppIcon(AppIcons.categoryIdentity),
                ),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _licenseController,
                decoration: const InputDecoration(
                  labelText: 'Driver License #',
                  prefixIcon: AppIcon(AppIcons.car),
                ),
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _dobController,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  prefixIcon: AppIcon(AppIcons.calendar),
                  hintText: 'YYYY-MM-DD',
                ),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: AppIcon(AppIcons.user),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            prefixIcon: AppIcon(AppIcons.home),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),

        // Identity Image Attachment Card
        Card(
          color: AppColors.surfaceZinc,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppIcon(AppIcons.file, color: AppColors.orangeAccent, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'ID Document Photo / Attachment',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.offWhite),
                    ),
                    const Spacer(),
                    if (_idImageBase64 != null)
                      IconButton(
                        icon: const AppIcon(AppIcons.delete, color: Colors.redAccent, size: 20),
                        onPressed: () => setState(() => _idImageBase64 = null),
                        tooltip: 'Remove Attachment',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_idImageBase64 != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(_idImageBase64!),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickIdentityImage,
                    icon: AppIcon(AppIcons.upload, color: AppColors.orangeAccent),
                    label: Text(
                      _idImageBase64 != null ? 'Replace ID Photo' : 'Upload ID Photo / Scan',
                      style: const TextStyle(color: AppColors.offWhite),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteForm() {
    return Column(
      key: const ValueKey('note_form'),
      children: [
        TextFormField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'Secure Note Content',
            hintText: 'Enter confidential markdown, SSH keys, or recovery seeds...',
            alignLabelWithHint: true,
          ),
          maxLines: 8,
          style: const TextStyle(fontFamily: 'Monospace'),
        ),
      ],
    );
  }

  Widget _buildDeveloperSecretForm() {
    return Column(
      key: const ValueKey('developer_secret_form'),
      children: [
        TextFormField(
          controller: _devSecretTypeController,
          decoration: const InputDecoration(
            labelText: 'Secret Sub-Type (e.g. API Key, SSH Key, DB, .env)',
            prefixIcon: AppIcon(AppIcons.folder),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _devSecretKeyController,
          focusNode: _devSecretKeyFocusNode,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Secret Key / API Key / Private Key',
            prefixIcon: const AppIcon(AppIcons.key),
            suffixIcon: IconButton(
              icon: AppIcon(_obscurePassword ? AppIcons.viewOff : AppIcons.view),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          maxLines: _obscurePassword ? 1 : 4,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _devPublicKeyController,
          decoration: const InputDecoration(
            labelText: 'Public Key / Endpoint / Host',
            prefixIcon: AppIcon(AppIcons.globe),
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _devConfigController,
          decoration: const InputDecoration(
            labelText: 'Configuration / Environment / .env Content',
            prefixIcon: AppIcon(AppIcons.title),
          ),
          maxLines: 5,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildCustomFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Custom Extra Fields',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _customFields.add(_CustomField(
                    keyController: TextEditingController(),
                    valueController: TextEditingController(),
                  ));
                });
              },
              icon: const AppIcon(AppIcons.add, size: 18),
              label: const Text('Add Field'),
            ),
          ],
        ),
        if (_customFields.isNotEmpty) const SizedBox(height: 8),
        ..._customFields.asMap().entries.map((entry) {
          final idx = entry.key;
          final cf = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: cf.keyController,
                    decoration: const InputDecoration(
                      labelText: 'Field Name',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: cf.valueController,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const AppIcon(AppIcons.close, color: Colors.redAccent, size: 20),
                  onPressed: () {
                    setState(() {
                      cf.dispose();
                      _customFields.removeAt(idx);
                    });
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _CustomField {
  final TextEditingController keyController;
  final TextEditingController valueController;

  _CustomField({
    required this.keyController,
    required this.valueController,
  });

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

class _CreditCardFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    String formatted = '';
    if (digits.isNotEmpty) {
      int month = int.parse(digits.substring(0, digits.length >= 2 ? 2 : 1));
      if (month > 12) month = 12;
      formatted = month.toString().padLeft(2, '0');
    }
    if (digits.length >= 3) {
      formatted += '/${digits.substring(2, digits.length > 4 ? 4 : digits.length)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _FieldGuideItem {
  final String name;
  final String description;
  final dynamic icon;

  const _FieldGuideItem({
    required this.name,
    required this.description,
    required this.icon,
  });
}

enum _SheetGenMode { password, passphrase, pin }

class _PasswordGeneratorSheet extends StatefulWidget {
  final String initialPassword;
  const _PasswordGeneratorSheet({required this.initialPassword});

  @override
  State<_PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<_PasswordGeneratorSheet> {
  _SheetGenMode _mode = _SheetGenMode.password;

  double _passwordLength = 18;
  bool _includeUpper = true;
  bool _includeLower = true;
  bool _includeDigits = true;
  bool _includeSymbols = true;
  bool _excludeAmbiguous = false;

  double _wordCount = 4;
  String _separator = '-';
  bool _capitalizePassphrase = true;
  bool _includePassphraseNumber = true;

  double _pinLength = 6;

  String _generated = '';

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    String result = '';
    switch (_mode) {
      case _SheetGenMode.password:
        result = GeneratorService.generatePassword(
          length: _passwordLength.round(),
          includeUppercase: _includeUpper,
          includeLowercase: _includeLower,
          includeDigits: _includeDigits,
          includeSymbols: _includeSymbols,
          excludeAmbiguous: _excludeAmbiguous,
        );
        break;
      case _SheetGenMode.passphrase:
        result = GeneratorService.generatePassphrase(
          wordCount: _wordCount.round(),
          separator: _separator,
          capitalize: _capitalizePassphrase,
          includeNumber: _includePassphraseNumber,
        );
        break;
      case _SheetGenMode.pin:
        result = GeneratorService.generatePIN(
          length: _pinLength.round(),
        );
        break;
    }
    setState(() => _generated = result);
  }

  @override
  Widget build(BuildContext context) {
    final activeAccent = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.borderZinc, width: 1),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderZinc,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GENERATE SECURE PASSWORD',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppColors.textMuted,
                  ),
                ),
                IconButton(
                  icon: const AppIcon(AppIcons.close, color: AppColors.textMuted, size: 20),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mode Tabs
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surfaceZinc,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  _buildTabItem(_SheetGenMode.password, 'Password', activeAccent),
                  _buildTabItem(_SheetGenMode.passphrase, 'Passphrase', activeAccent),
                  _buildTabItem(_SheetGenMode.pin, 'PIN', activeAccent),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Output Display Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceZinc,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: activeAccent.withValues(alpha: 0.4), width: 1.2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          _generated,
                          style: TextStyle(
                            fontFamily: 'Monospace',
                            fontSize: _generated.length > 24 ? 13 : 16,
                            fontWeight: FontWeight.bold,
                            color: activeAccent,
                            letterSpacing: _mode == _SheetGenMode.pin ? 3.0 : 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const AppIcon(AppIcons.refresh, size: 20),
                        tooltip: 'Regenerate',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _regenerate();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  PasswordStrengthMeter(
                    password: _generated,
                    compact: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Config Controls
            if (_mode == _SheetGenMode.password) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Length', style: TextStyle(color: AppColors.offWhite, fontSize: 13)),
                  Text('${_passwordLength.round()} chars', style: TextStyle(color: activeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Slider(
                value: _passwordLength,
                min: 8,
                max: 48,
                activeColor: activeAccent,
                onChanged: (val) {
                  setState(() => _passwordLength = val);
                  _regenerate();
                },
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildChip('A-Z', _includeUpper, activeAccent, (v) { setState(() => _includeUpper = v); _regenerate(); }),
                  _buildChip('a-z', _includeLower, activeAccent, (v) { setState(() => _includeLower = v); _regenerate(); }),
                  _buildChip('0-9', _includeDigits, activeAccent, (v) { setState(() => _includeDigits = v); _regenerate(); }),
                  _buildChip('!@#\$%', _includeSymbols, activeAccent, (v) { setState(() => _includeSymbols = v); _regenerate(); }),
                  _buildChip('No Ambiguous', _excludeAmbiguous, activeAccent, (v) { setState(() => _excludeAmbiguous = v); _regenerate(); }),
                ],
              ),
            ] else if (_mode == _SheetGenMode.passphrase) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Words', style: TextStyle(color: AppColors.offWhite, fontSize: 13)),
                  Text('${_wordCount.round()} words', style: TextStyle(color: activeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Slider(
                value: _wordCount,
                min: 3,
                max: 7,
                divisions: 4,
                activeColor: activeAccent,
                onChanged: (val) {
                  setState(() => _wordCount = val);
                  _regenerate();
                },
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildChip('Capitalize', _capitalizePassphrase, activeAccent, (v) { setState(() => _capitalizePassphrase = v); _regenerate(); }),
                  _buildChip('+4 Digits', _includePassphraseNumber, activeAccent, (v) { setState(() => _includePassphraseNumber = v); _regenerate(); }),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Separator', style: TextStyle(color: AppColors.offWhite, fontSize: 13)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? activeAccent : AppColors.surfaceZinc,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isSelected ? activeAccent : AppColors.borderZinc),
                          ),
                          child: Text(sep == ' ' ? 'Space' : sep, style: TextStyle(color: isSelected ? Colors.white : AppColors.offWhite, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ] else if (_mode == _SheetGenMode.pin) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('PIN Digits', style: TextStyle(color: AppColors.offWhite, fontSize: 13)),
                  Text('${_pinLength.round()} digits', style: TextStyle(color: activeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Slider(
                value: _pinLength,
                min: 4,
                max: 10,
                divisions: 6,
                activeColor: activeAccent,
                onChanged: (val) {
                  setState(() => _pinLength = val);
                  _regenerate();
                },
              ),
            ],

            const SizedBox(height: 20),

            // Action Button
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context, _generated);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: activeAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              icon: const AppIcon(AppIcons.checkCircle, size: 20, color: Colors.white),
              label: const Text(
                'Apply to Password Field',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(_SheetGenMode mode, String label, Color activeAccent) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _mode = mode);
          _regenerate();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeAccent.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: isSelected ? activeAccent : Colors.transparent),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textMuted,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool value, Color activeAccent, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label, style: TextStyle(color: value ? Colors.white : AppColors.offWhite, fontSize: 12)),
      selected: value,
      selectedColor: activeAccent.withValues(alpha: 0.3),
      backgroundColor: AppColors.surfaceZinc,
      side: BorderSide(color: value ? activeAccent : AppColors.borderZinc),
      checkmarkColor: activeAccent,
      onSelected: onChanged,
    );
  }
}