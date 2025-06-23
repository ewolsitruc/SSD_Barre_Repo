import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:image_picker/image_picker.dart'; // For image picking
import 'package:firebase_storage/firebase_storage.dart'; // For Firebase Storage
import 'dart:io'; // For File

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

  DateTime? _selectedBirthday;
  bool _allowCommentsOnProfile = true; // Default value
  bool _isLoading = false;
  bool _isUploadingImage = false; // New state for image upload progress
  User? _currentUser;
  String? _profileImageUrl; // State for profile image URL

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
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    if (_currentUser == null) return;

    setState(() { _isLoading = true; });

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        _firstNameController.text = data?['firstName'] ?? '';
        _lastNameController.text = data?['lastName'] ?? '';
        // Convert List<dynamic> to comma-separated string for TextField
        _childrenNamesController.text = (data?['childrenNames'] as List<dynamic>?)?.join(', ') ?? '';
        _bioController.text = data?['bio'] ?? '';
        _phoneNumberController.text = data?['phoneNumber'] ?? '';
        _allowCommentsOnProfile = data?['allowCommentsOnProfile'] ?? true;
        
        final Timestamp? birthdayTimestamp = data?['birthday'] as Timestamp?;
        if (birthdayTimestamp != null) {
          _selectedBirthday = birthdayTimestamp.toDate();
        }
        _profileImageUrl = data?['profileImageUrl']; // Load profile image URL
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      _showSnackBar('Failed to load profile data.');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      if (_currentUser == null) {
        _showSnackBar('You must be logged in to save your profile.');
        setState(() { _isLoading = false; });
        return;
      }

      try {
        // Convert comma-separated string to List<String>
        List<String> childrenNamesList = _childrenNamesController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'childrenNames': childrenNamesList,
          'bio': _bioController.text.trim(),
          'phoneNumber': _phoneNumberController.text.trim(),
          'birthday': _selectedBirthday != null ? Timestamp.fromDate(_selectedBirthday!) : null,
          'allowCommentsOnProfile': _allowCommentsOnProfile,
          // profileImageUrl is updated directly in _pickProfileImage,
          // so no need to update it here unless it's changed by another means.
        });

        _showSnackBar('Profile updated successfully!');
        if (mounted) {
          Navigator.pop(context); // Go back to the main Edit Profile Page
        }
      } catch (e) {
        debugPrint('Error saving profile: $e');
        _showSnackBar('Failed to save profile: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              surface: Theme.of(context).colorScheme.background,
              onSurface: Theme.of(context).colorScheme.onBackground,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedBirthday) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // New and updated image picker functionality
  Future<void> _pickProfileImage() async {
    if (_currentUser == null) {
      _showSnackBar('You must be logged in to change your profile picture.');
      return;
    }

    setState(() {
      _isUploadingImage = true; // Show loading indicator
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery); // Or .camera

      if (image != null) {
        debugPrint('Picked image path: ${image.path}');
        File imageFile = File(image.path);

        // Upload image to Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child(_currentUser!.uid)
            .child('profile_picture.jpg'); // Unique path per user

        final uploadTask = storageRef.putFile(imageFile);
        final snapshot = await uploadTask.whenComplete(() => {});
        final downloadUrl = await snapshot.ref.getDownloadURL();

        debugPrint('Image uploaded. Download URL: $downloadUrl');

        // Update profileImageUrl in Firestore
        await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({
          'profileImageUrl': downloadUrl,
        });

        setState(() {
          _profileImageUrl = downloadUrl; // Update local state to reflect new image
          _showSnackBar('Profile picture updated!');
        });
      } else {
        _showSnackBar('No image selected.');
      }
    } catch (e) {
      debugPrint('Error picking or uploading image: $e');
      _showSnackBar('Failed to update profile picture: $e');
    } finally {
      setState(() {
        _isUploadingImage = false; // Hide loading indicator
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile Information'),
      ),
      body: _isLoading || _isUploadingImage // Show loading if either data is loading or image is uploading
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
                        onTap: _pickProfileImage,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: primaryColor.withOpacity(0.2),
                          backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                              ? NetworkImage(_profileImageUrl!) as ImageProvider
                              : null,
                          child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                              ? Icon(Icons.camera_alt, size: 50, color: primaryColor)
                              : null,
                        ),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: _pickProfileImage,
                        child: Text(
                          _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                              ? 'Change Profile Picture'
                              : 'Add Profile Picture',
                          style: TextStyle(color: primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name', prefixIcon: Icon(Icons.person)),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name', prefixIcon: Icon(Icons.person_outline)),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your last name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _childrenNamesController,
                      decoration: const InputDecoration(
                        labelText: 'Children\'s Names (Comma-separated)',
                        hintText: 'e.g., Charlee, Morgan, Abby',
                        prefixIcon: Icon(Icons.child_care),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        hintText: 'Tell us a little about yourself...',
                        prefixIcon: Icon(Icons.info_outline),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectBirthday(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Birthday (Optional)',
                          hintText: _selectedBirthday == null
                              ? 'Select your birthday'
                              : DateFormat('MMM dd,ญี่ป�').format(_selectedBirthday!),
                          prefixIcon: const Icon(Icons.cake),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          _selectedBirthday == null
                              ? 'Tap to select date'
                              : DateFormat('MMM dd,ญี่ป�').format(_selectedBirthday!),
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedBirthday == null ? Colors.grey[600] : textOnBackground,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      title: Text(
                        'Allow comments on My Profile',
                        style: TextStyle(color: textOnBackground),
                      ),
                      value: _allowCommentsOnProfile,
                      onChanged: (bool value) {
                        setState(() {
                          _allowCommentsOnProfile = value;
                        });
                      },
                      activeColor: primaryColor,
                      tileColor: Theme.of(context).colorScheme.surface, // Card-like background
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton(
                        onPressed: _isLoading || _isUploadingImage ? null : _saveProfile,
                        child: const Text('Save Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
