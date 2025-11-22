import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _swapDetailsController = TextEditingController();
  final _priceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedAction = 'Borrow';
  String? _selectedCategory;
  String? _selectedCondition;
  final List<File> _selectedImages = [];
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'School Uniforms',
    'Bags',
    'Shoes',
    'Pens',
    'Art Materials',
    'Papers',
    'Others',
  ];

  final List<String> _conditions = ['New', 'Like New', 'Good', 'Fair', 'Used'];

  @override
  void initState() {
    super.initState();
    _selectedImages.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          // Removed const
          'Post Item',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageUploadSection(),
              const SizedBox(height: 24),
              _buildTextField(
                label: 'Title',
                controller: _titleController,
                hint: 'Enter item title',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildCategoryDropdown(),
              const SizedBox(height: 20),
              _buildConditionDropdown(),
              const SizedBox(height: 20),
              _buildTextField(
                label: 'Description',
                controller: _descriptionController,
                hint: 'Describe your item, condition, and details...',
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildActionSelection(),
              const SizedBox(height: 20),
              if (_selectedAction == 'Sell') _buildPriceSection(),
              if (_selectedAction == 'Swap') _buildSwapSection(),
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.withOpacity(0.3)
                  : Colors.grey[300]!,
            ),
          ),
          child: _selectedImages.isEmpty
              ? _buildUploadPrompt()
              : _buildImageGrid(),
        ),
        if (_selectedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_selectedImages.length}/3 photos',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUploadPrompt() {
    return InkWell(
      onTap: _handleImageUpload,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate,
            size: 40,
            color: Theme.of(context).iconTheme.color?.withOpacity(0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Add Photos',
            style: TextStyle(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
          ),
          Text(
            'Up to 3 images',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          ..._selectedImages.asMap().entries.map((entry) {
            int index = entry.key;
            File image = entry.value;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        image,
                        height: 80,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          if (_selectedImages.length < 3)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: InkWell(
                  onTap: _handleImageUpload,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[700]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.withOpacity(0.3)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Icon(
                      Icons.add,
                      size: 24,
                      color: Theme.of(
                        context,
                      ).iconTheme.color?.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
            prefixText: prefixText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[50],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          validator: (value) =>
              value == null ? 'Please select a category' : null,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          dropdownColor: Theme.of(context).cardColor,
          decoration: InputDecoration(
            hintText: 'Select category',
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[50],
          ),
          items: _categories
              .map(
                (category) =>
                    DropdownMenuItem(value: category, child: Text(category)),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedCategory = value),
        ),
      ],
    );
  }

  Widget _buildConditionDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Condition',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCondition,
          validator: (value) =>
              value == null ? 'Please select condition' : null,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          dropdownColor: Theme.of(context).cardColor,
          decoration: InputDecoration(
            hintText: 'Select item condition',
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[50],
          ),
          items: _conditions
              .map(
                (condition) =>
                    DropdownMenuItem(value: condition, child: Text(condition)),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedCondition = value),
        ),
      ],
    );
  }

  Widget _buildActionSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What would you like to do?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildActionChip('Borrow', Colors.green),
            const SizedBox(width: 8),
            _buildActionChip('Sell', Colors.orange),
            const SizedBox(width: 8),
            _buildActionChip('Swap', Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildActionChip(String action, Color color) {
    bool isSelected = _selectedAction == action;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedAction = action),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color
                : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]
                      : Colors.grey[200]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            action,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[300]
                        : Colors.grey[700]),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          label: 'Price *',
          controller: _priceController,
          hint: 'Enter price amount',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          prefixText: '₱ ',
          validator: (value) {
            if (_selectedAction == 'Sell' && (value == null || value.isEmpty)) {
              return 'Please enter a price';
            }
            if (value != null && value.isNotEmpty) {
              final price = int.tryParse(value);
              if (price == null || price <= 0) {
                return 'Please enter a valid price';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSwapSection() {
    return const SizedBox.shrink();
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getActionColor(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Post $_selectedAction Request',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Color _getActionColor() {
    switch (_selectedAction) {
      case 'Borrow':
        return Colors.green;
      case 'Sell':
        return Colors.orange;
      case 'Swap':
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }

  void _handleImageUpload() async {
    if (_selectedImages.length >= 3) {
      _showSnackBar('Maximum 3 images allowed', Colors.orange);
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 300,
        imageQuality: 40,
      );

      if (image != null) {
        File imageFile = File(image.path);
        if (!await imageFile.exists()) {
          _showSnackBar('Image file not found', Colors.red);
          return;
        }

        int fileSizeInBytes = await imageFile.length();
        double fileSizeInKB = fileSizeInBytes / 1024;

        if (fileSizeInBytes > 50 * 1024) {
          _showSnackBar(
            'Image too large (${fileSizeInKB.toStringAsFixed(1)}KB). Must be under 50KB.',
            Colors.red,
          );
          return;
        }

        try {
          Uint8List testRead = await imageFile.readAsBytes();
          if (testRead.isEmpty) {
            _showSnackBar('Image appears corrupted', Colors.red);
            return;
          }
        } catch (readError) {
          _showSnackBar('Cannot read image file', Colors.red);
          return;
        }

        setState(() {
          _selectedImages.add(imageFile);
        });
        _showSnackBar(
          'Image added (${fileSizeInKB.toStringAsFixed(1)}KB)',
          Colors.green,
        );
      }
    } catch (e) {
      print('Image upload error: $e');
      _showSnackBar('Error selecting image', Colors.red);
    }
  }

  void _removeImage(int index) {
    if (index >= 0 && index < _selectedImages.length) {
      setState(() {
        _selectedImages.removeAt(index);
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final User? user = _auth.currentUser;
    if (user == null) {
      _showSnackBar('Please sign in to post', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      GeoPoint? userLocation;
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        userLocation = GeoPoint(position.latitude, position.longitude);
        print(
          '📍 Location obtained: ${position.latitude}, ${position.longitude}',
        );
      } catch (locationError) {
        print('⚠️ Location error: $locationError');
      }

      String? priceForDb;
      if (_selectedAction == 'Sell' && _priceController.text.isNotEmpty) {
        priceForDb = '₱${_priceController.text}';
      }

      Map<String, dynamic> postData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory ?? '',
        'action': _selectedAction,
        'condition': _selectedCondition ?? 'Good',
        'price': priceForDb ?? '',
        'swapDetails': _swapDetailsController.text.trim(),
        'images': [],
        'imageCount': 0,
        'userId': user.uid,
        'userName':
            user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous',
        'userEmail': user.email ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'isActive': true,
        'location': userLocation,
      };

      DocumentReference docRef = await _firestore
          .collection('items')
          .add(postData);

      if (_selectedImages.isNotEmpty) {
        await _processImagesForDocument(docRef);
      }

      if (mounted) {
        _showSnackBar(
          '$_selectedAction request posted successfully!',
          Colors.green,
        );
        await Future.delayed(const Duration(milliseconds: 200));
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print('Post submission error: $e');
      String errorMessage = 'Failed to post item';
      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        errorMessage = 'Network error. Check connection.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Sign in again.';
      }

      _showSnackBar(errorMessage, Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processImagesForDocument(DocumentReference docRef) async {
    try {
      List<String> base64Images = [];

      for (int i = 0; i < _selectedImages.length && i < 3; i++) {
        try {
          File image = _selectedImages[i];
          Uint8List? imageBytes;

          try {
            imageBytes = await image.readAsBytes();
            if (imageBytes.length > 50 * 1024) {
              print('Skipping oversized image $i');
              continue;
            }

            String base64String = base64Encode(imageBytes);
            base64Images.add('data:image/jpeg;base64,$base64String');
            imageBytes = null;
            await Future.delayed(const Duration(milliseconds: 200));
          } catch (encodeError) {
            print('Error encoding image $i: $encodeError');
            continue;
          }
        } catch (imageError) {
          print('Error processing image $i: $imageError');
          continue;
        }
      }

      if (base64Images.isNotEmpty) {
        await docRef.update({
          'images': base64Images,
          'imageCount': base64Images.length,
        });
      }
    } catch (updateError) {
      print('Error updating with images: $updateError');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _swapDetailsController.dispose();
    _priceController.dispose();
    _selectedImages.clear();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
    }
  }
}
