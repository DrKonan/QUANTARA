import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  File? _pickedImage;
  String? _currentAvatarUrl;
  bool _saving = false;
  bool _uploadingImage = false;
  bool _signedUpWithPhone = false;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(userProfileProvider).valueOrNull;
      final email = ref.read(currentUserProvider)?.email ?? '';
      final isPhoneSignup = email.endsWith('@phone.nakora.app');

      if (profile != null) {
        _usernameCtrl.text = profile.username ?? '';
        _phoneCtrl.text = profile.phone ?? '';
        setState(() => _currentAvatarUrl = profile.avatarUrl);
      }

      // If signed up with phone, don't show the generated email
      _emailCtrl.text = isPhoneSignup ? '' : email;
      setState(() => _signedUpWithPhone = isPhoneSignup);
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Photo de profil",
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.gold),
                ),
                title: const Text("Prendre une photo", style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.emerald),
                ),
                title: const Text("Choisir dans la galerie", style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              if (_currentAvatarUrl != null || _pickedImage != null) ...[
                const SizedBox(height: 4),
                ListTile(
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_rounded, color: AppColors.error),
                  ),
                  title: const Text("Supprimer la photo", style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    setState(() {
                      _pickedImage = null;
                      _currentAvatarUrl = null;
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<String?> _uploadAvatar(File file) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;

    final ext = file.path.split('.').last;
    final path = 'avatars/$userId.$ext';

    await client.storage.from('avatars').upload(
      path,
      file,
      fileOptions: const FileOptions(upsert: true),
    );

    return client.storage.from('avatars').getPublicUrl(path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final authService = ref.read(authServiceProvider);
      String? avatarUrl = _currentAvatarUrl;

      // Upload new avatar if picked
      if (_pickedImage != null) {
        setState(() => _uploadingImage = true);
        avatarUrl = await _uploadAvatar(_pickedImage!);
        setState(() => _uploadingImage = false);
      }

      await authService.updateProfile(
        username: _usernameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        email: _signedUpWithPhone && _emailCtrl.text.trim().isNotEmpty
            ? _emailCtrl.text.trim()
            : null,
        avatarUrl: avatarUrl,
      );

      // Refresh profile
      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text("Profil mis à jour"),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur : ${e.toString().replaceAll('Exception: ', '')}"),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                  ),
                  const Expanded(
                    child: Text(
                      "Modifier le profil",
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
                          )
                        : const Text(
                            "Enregistrer",
                            style: TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 32),

                      // Avatar
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 56,
                              backgroundColor: AppColors.surface,
                              backgroundImage: _pickedImage != null
                                  ? FileImage(_pickedImage!)
                                  : _currentAvatarUrl != null
                                      ? NetworkImage(_currentAvatarUrl!) as ImageProvider
                                      : null,
                              child: (_pickedImage == null && _currentAvatarUrl == null)
                                  ? Text(
                                      _usernameCtrl.text.isNotEmpty ? _usernameCtrl.text[0].toUpperCase() : "?",
                                      style: const TextStyle(color: AppColors.gold, fontSize: 40, fontWeight: FontWeight.w700),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.background, width: 3),
                                ),
                                child: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 16),
                              ),
                            ),
                            if (_uploadingImage)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Appuyez pour changer la photo",
                        style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 12),
                      ),

                      const SizedBox(height: 36),

                      // Username
                      _buildField(
                        controller: _usernameCtrl,
                        label: "Nom d'utilisateur",
                        icon: Icons.person_rounded,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Le nom est requis";
                          if (v.trim().length < 3) return "Minimum 3 caractères";
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // Email — editable if signed up with phone, locked if signed up with email
                      _buildField(
                        controller: _signedUpWithPhone ? _emailCtrl : null,
                        initialValue: _signedUpWithPhone ? null : _emailCtrl.text,
                        label: "Email",
                        icon: Icons.email_rounded,
                        readOnly: !_signedUpWithPhone,
                        hint: _signedUpWithPhone ? "Ajoutez votre adresse email" : "Non modifiable",
                        keyboardType: TextInputType.emailAddress,
                        validator: _signedUpWithPhone
                            ? (v) {
                                if (v != null && v.trim().isNotEmpty) {
                                  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                                  if (!emailRegex.hasMatch(v.trim())) return "Email invalide";
                                }
                                return null;
                              }
                            : null,
                      ),

                      const SizedBox(height: 18),

                      // Phone — editable if signed up with email, locked if signed up with phone
                      _buildField(
                        controller: !_signedUpWithPhone ? _phoneCtrl : null,
                        initialValue: !_signedUpWithPhone ? null : _phoneCtrl.text,
                        label: "Téléphone",
                        icon: Icons.phone_rounded,
                        readOnly: _signedUpWithPhone,
                        keyboardType: TextInputType.phone,
                        hint: _signedUpWithPhone ? "Non modifiable" : "+225 XX XX XX XX XX",
                      ),

                      const SizedBox(height: 40),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _saving
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                    ),
                                    SizedBox(width: 12),
                                    Text("Enregistrement...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_rounded, size: 20),
                                    SizedBox(width: 10),
                                    Text("Enregistrer les modifications", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    required IconData icon,
    bool readOnly = false,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          readOnly: readOnly,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: readOnly ? AppColors.textSecondary.withValues(alpha: 0.5) : AppColors.gold, size: 20),
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4), fontSize: 14),
            filled: true,
            fillColor: readOnly ? AppColors.surface.withValues(alpha: 0.5) : AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gold),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            suffixIcon: readOnly
                ? Tooltip(
                    message: "Ce champ ne peut pas être modifié",
                    child: Icon(Icons.lock_rounded, color: AppColors.textSecondary.withValues(alpha: 0.4), size: 16),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
