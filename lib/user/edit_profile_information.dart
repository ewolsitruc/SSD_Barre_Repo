import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ssd_barre_new/widgets/labeled_text_form_field.dart';

class EditProfileInformationPage extends StatefulWidget {
  const EditProfileInformationPage({super.key});

  @override
  State<EditProfileInformationPage> createState() => _EditProfileInformationPageState();
}

class _EditProfileInformationPageState extends State<EditProfileInformationPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _childrenNamesController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();

  DateTime? _selectedBirthday;
  bool _allowCommentsOnProfile = true;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _showChangePasswordSection = false;
  bool _isUpdatingPassword = false;

  User? _currentUser;
  String? _profileImageUrl;
  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadProfileData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _childrenNamesController.dispose();
    _bioController.dispose();
    _phoneNumberController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    if (_currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        _firstNameController.text = data?['firstName'] ?? '';
        _lastNameController.text = data?['lastName'] ?? '';

        final rawChildrenNames = data?['childrenNames'];
        if (rawChildrenNames is List) {
          _childrenNamesController.text = rawChildrenNames.join(', ');
        } else if (rawChildrenNames is String) {
          _childrenNamesController.text = rawChildrenNames;
        } else {
          _childrenNamesController.text = '';
        }

        _bioController.text = data?['bio'] ?? '';
        _phoneNumberController.text = data?['phoneNumber'] ?? '';
        _allowCommentsOnProfile = data?['allowCommentsOnProfile'] ?? true;
        _displayNameController.text = data?['displayName'] ?? '';
        _emailController.text = data?['email'] ?? _currentUser?.email ?? '';

        final Timestamp? birthdayTimestamp = data?['birthday'] as Timestamp?;
        if (birthdayTimestamp != null) {
          _selectedBirthday = birthdayTimestamp.toDate();
        }
        _profileImageUrl = data?['profileImageUrl'];
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      _showSnackBar('Failed to load profile data.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isUploadingImage = true;
    });

    if (_currentUser == null) {
      _showSnackBar('You must be logged in to save your profile.');
      setState(() {
        _isLoading = false;
        _isUploadingImage = false;
      });
      return;
    }

    try {
      List<String> childrenNamesList = _childrenNamesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      String? uploadedImageUrl;
      if (_selectedImageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child(_currentUser!.uid)
            .child('profile.jpg');

        UploadTask uploadTask = storageRef.putFile(_selectedImageFile!);
        final snapshot = await uploadTask.whenComplete(() => {});

        if (snapshot.state == TaskState.success) {
          uploadedImageUrl = await snapshot.ref.getDownloadURL();
        } else {
          throw FirebaseException(
            plugin: 'firebase_storage',
            code: 'upload-failed',
            message: 'Profile image upload failed.',
          );
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({
        'firstName': _firstNameController.text.trim(),
        'firstNameLowercase': _firstNameController.text.trim().toLowerCase(),
        'lastName': _lastNameController.text.trim(),
        'lastNameLowercase': _lastNameController.text.trim().toLowerCase(),
        'childrenNames': childrenNamesList,
        'bio': _bioController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'birthday': _selectedBirthday != null ? Timestamp.fromDate(_selectedBirthday!) : null,
        'allowCommentsOnProfile': _allowCommentsOnProfile,
        'displayName': _displayNameController.text.trim(),
        'displayNameLowercase': _displayNameController.text.trim().toLowerCase(),
        if (uploadedImageUrl != null) 'profileImageUrl': uploadedImageUrl,
      });

      await _currentUser!.updateDisplayName(_displayNameController.text.trim());

      _showSnackBar('Profile updated successfully!');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving profile: $e');
      _showSnackBar('Failed to save profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _submitPasswordChange() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmNewPasswordController.text.trim();

    if (newPassword.length < 6) {
      _showSnackBar('New password must be at least 6 characters.');
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnackBar('New password and confirmation do not match.');
      return;
    }
    if (_currentUser?.email == null) {
      _showSnackBar('Cannot verify user. Please re-login.');
      return;
    }

    setState(() => _isUpdatingPassword = true);

    try {
      final credential = EmailAuthProvider.credential(
        email: _currentUser!.email!,
        password: currentPassword,
      );
      await _currentUser!.reauthenticateWithCredential(credential);
      await _currentUser!.updatePassword(newPassword);

      _showSnackBar('Password updated successfully.');
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmNewPasswordController.clear();
      setState(() => _showChangePasswordSection = false);
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.code == 'wrong-password' ? 'Incorrect current password.' : 'Failed: ${e.message}');
    } catch (e) {
      _showSnackBar('An error occurred while updating password.');
      debugPrint('Password change error: $e');
    } finally {
      setState(() => _isUpdatingPassword = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImageFile = File(pickedFile.path));
    }
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedBirthday = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile Information')),
      body: _isLoading || _isUploadingImage
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _selectedImageFile != null
                        ? FileImage(_selectedImageFile!)
                        : (_profileImageUrl != null
                        ? NetworkImage(_profileImageUrl!) as ImageProvider
                        : const AssetImage('assets/default_avatar.png')),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              LabeledTextFormField(label: 'Email (read-only)', controller: _emailController, readOnly: true),
              LabeledTextFormField(label: 'Display Name', controller: _displayNameController),
              LabeledTextFormField(label: 'First Name', controller: _firstNameController),
              LabeledTextFormField(label: 'Last Name', controller: _lastNameController),
              LabeledTextFormField(label: "Children's Names (Comma-separated)", controller: _childrenNamesController),
              LabeledTextFormField(label: 'Phone Number', controller: _phoneNumberController, keyboardType: TextInputType.phone),
              LabeledTextFormField(label: 'Bio', controller: _bioController, maxLines: 3),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Birthday:'),
                  const SizedBox(width: 10),
                  Text(
                    _selectedBirthday != null
                        ? DateFormat.yMMMd().format(_selectedBirthday!)
                        : 'Not set',
                    style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                  ),
                  const Spacer(),
                  TextButton(onPressed: _pickBirthday, child: const Text('Pick Date')),
                ],
              ),
              SwitchListTile(
                title: const Text('Allow Comments on Profile'),
                value: _allowCommentsOnProfile,
                onChanged: (value) => setState(() => _allowCommentsOnProfile = value),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _saveProfile, child: const Text('Save Profile')),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => setState(() => _showChangePasswordSection = !_showChangePasswordSection),
                icon: const Icon(Icons.lock),
                label: const Text('Change Password'),
              ),
              if (_showChangePasswordSection) ...[
                const SizedBox(height: 24),
                LabeledTextFormField(label: 'Current Password', controller: _currentPasswordController, obscureText: true),
                LabeledTextFormField(label: 'New Password', controller: _newPasswordController, obscureText: true),
                LabeledTextFormField(label: 'Confirm New Password', controller: _confirmNewPasswordController, obscureText: true),
                const SizedBox(height: 16),
                _isUpdatingPassword
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Update Password'),
                  onPressed: _submitPasswordChange,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
