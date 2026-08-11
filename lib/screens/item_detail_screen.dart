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
import '../services/generator_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_3d_button.dart';
import '../theme/app_feedback.dart';

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
    _loadExistingItemData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
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

      // Populate any remaining non-standard fields as custom fields
      final standardKeys = {
        'username', 'password', 'url', 'totp_secret', 'notes',
        'cardholder', 'number', 'expiry', 'cvv', 'pin', 'zip',
        'full_name', 'id_number', 'passport', 'license', 'dob', 'address', 'phone', 'id_image', 'content'
      };

      fields.forEach((key, val) {
        if (!standardKeys.contains(key)) {
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
    setState(() {
      _passwordController.text = GeneratorService.generatePassword(length: 20);
      _obscurePassword = false;
    });
    HapticFeedback.selectionClick();
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
      icon: Icons.delete_outline,
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
          if (isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: App3DButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                variant: App3DButtonVariant.danger,
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
                      Icon(Icons.error_outline, color: cs.onErrorContainer, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
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
                        prefixIcon: const Icon(Icons.title, color: AppColors.orangeAccent),
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
                    App3DButton(
                      label: _isLoading ? 'Saving...' : (isEditing ? 'Save Changes' : 'Save Credential'),
                      icon: Icons.check_circle_outline,
                      variant: App3DButtonVariant.primary,
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceZinc,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderZinc),
      ),
      child: Row(
        children: ItemType.values.map((type) {
          final isSelected = _selectedType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedType = type);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.orangeContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? Border.all(color: AppColors.orangeAccent.withValues(alpha: 0.5)) : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      _getTypeIcon(type),
                      size: 22,
                      color: isSelected ? AppColors.orangeAccent : AppColors.textMuted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.offWhite : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
            prefixIcon: Icon(Icons.person_outline, size: 20),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.auto_awesome, color: AppColors.orangeAccent, size: 20),
                  tooltip: 'Generate Password',
                  onPressed: _generatePassword,
                ),
                IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ],
            ),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'Website URL',
            prefixIcon: Icon(Icons.link_outlined, size: 20),
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
            prefixIcon: Icon(Icons.security_outlined, size: 20),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'Notes',
            prefixIcon: Icon(Icons.notes_outlined, size: 20),
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
            prefixIcon: Icon(Icons.person_outline),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cardNumberController,
          decoration: const InputDecoration(
            labelText: 'Card Number',
            prefixIcon: Icon(Icons.credit_card_outlined),
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
                  prefixIcon: Icon(Icons.calendar_today_outlined),
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
                obscureText: _obscureCvv,
                decoration: InputDecoration(
                  labelText: 'CVV',
                  prefixIcon: const Icon(Icons.shield_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCvv ? Icons.visibility_off : Icons.visibility),
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
                obscureText: _obscurePin,
                decoration: InputDecoration(
                  labelText: 'Card PIN',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
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
                  prefixIcon: Icon(Icons.location_on_outlined),
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
            prefixIcon: Icon(Icons.notes_outlined),
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
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _idNumberController,
          decoration: const InputDecoration(
            labelText: 'National ID / SSN Number',
            prefixIcon: Icon(Icons.numbers_outlined),
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
                  prefixIcon: Icon(Icons.flight_takeoff_outlined),
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
                  prefixIcon: Icon(Icons.directions_car_outlined),
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
                  prefixIcon: Icon(Icons.cake_outlined),
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
                  prefixIcon: Icon(Icons.phone_outlined),
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
            prefixIcon: Icon(Icons.home_outlined),
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
                    const Icon(Icons.image_outlined, color: AppColors.orangeAccent, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'ID Document Photo / Attachment',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.offWhite),
                    ),
                    const Spacer(),
                    if (_idImageBase64 != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
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
                    icon: const Icon(Icons.upload_file, color: AppColors.orangeAccent),
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
            prefixIcon: Icon(Icons.category_outlined),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _devSecretKeyController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Secret Key / API Key / Private Key',
            prefixIcon: const Icon(Icons.key_outlined),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
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
            prefixIcon: Icon(Icons.dns_outlined),
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _devConfigController,
          decoration: const InputDecoration(
            labelText: 'Configuration / Environment / .env Content',
            prefixIcon: Icon(Icons.code_outlined),
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
              icon: const Icon(Icons.add, size: 18),
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
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
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

  IconData _getTypeIcon(ItemType type) {
    switch (type) {
      case ItemType.login:
        return Icons.login_outlined;
      case ItemType.card:
        return Icons.credit_card_outlined;
      case ItemType.identity:
        return Icons.badge_outlined;
      case ItemType.note:
        return Icons.note_outlined;
      case ItemType.developerSecret:
        return Icons.terminal_outlined;
    }
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