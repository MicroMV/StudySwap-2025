import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _schoolController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _createUserDocument(
    User user,
    String displayName,
    String school,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': displayName.isNotEmpty
            ? displayName
            : user.email?.split('@')[0] ?? 'User',
        'displayName_lowercase': displayName.toLowerCase(),
        'email': user.email ?? 'unknown@example.com',
        'school': school.isNotEmpty ? school : 'No School Listed',
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'photoURL': user.photoURL,
        'lastLogin': FieldValue.serverTimestamp(),
        'profileCompleted': true,
      });
      print('Created user document for ${user.uid}');
    } catch (e) {
      print('Error creating user document: $e');
      throw e;
    }
  }

  // Google Sign-Up method with profile completion
  Future<void> _signUpWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // If user cancels the sign-in
      if (googleUser == null) return;

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      if (userCredential.user != null) {
        final user = userCredential.user!;

        //  Does user already exist?
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          // USER ALREADY EXISTS - Redirect to login
          await FirebaseAuth.instance.signOut();
          await GoogleSignIn().signOut();

          if (!mounted) return;

          _showErrorSnackBar(
            'Account already exists. Please sign in instead',
            Icons.account_circle,
            Colors.orange,
          );
          return;
        }

        //  NEW USER - Create basic profile and redirect to complete profile
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': user.displayName ?? 'User',
          'displayName_lowercase': (user.displayName ?? 'user').toLowerCase(),
          'email': user.email ?? 'unknown@example.com',
          'school': '', // Empty - user needs to complete profile
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'photoURL': user.photoURL,
          'lastLogin': FieldValue.serverTimestamp(),
          'profileCompleted': false,
        });

        if (!mounted) return;

        // Navigate to profile completion screen
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/complete-profile',
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String errorMessage;
      IconData errorIcon = Icons.error_outline;
      Color errorColor = Colors.red;

      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage =
              'An account with this email already exists. Try signing in instead';
          errorIcon = Icons.account_circle;
          break;

        case 'invalid-credential':
          errorMessage = 'Invalid credentials. Please try again';
          errorIcon = Icons.lock_outline;
          break;

        case 'operation-not-allowed':
          errorMessage =
              'Google Sign-In is not enabled. Please contact support';
          errorIcon = Icons.error_outline;
          break;

        case 'user-disabled':
          errorMessage =
              'This account has been disabled. Please contact support';
          errorIcon = Icons.block;
          break;

        case 'network-request-failed':
          errorMessage =
              'Connection problem. Please check your internet and try again';
          errorIcon = Icons.wifi_off;
          errorColor = Colors.orange;
          break;

        default:
          errorMessage = 'Unable to sign up with Google. Please try again';
          errorIcon = Icons.error_outline;
      }

      _showErrorSnackBar(errorMessage, errorIcon, errorColor);
    } catch (e) {
      if (!mounted) return;

      _showErrorSnackBar(
        'Something went wrong. Please try again',
        Icons.error_outline,
        Colors.red,
      );
    }
  }

  Future<void> _signup() async {
    // Validate display name
    if (_displayNameController.text.trim().isEmpty) {
      _showErrorSnackBar(
        'Please enter your full name',
        Icons.person_outline,
        Colors.red,
      );
      return;
    }

    // ✅ ADD: Validate school (now mandatory)
    if (_schoolController.text.trim().isEmpty) {
      _showErrorSnackBar(
        'Please enter your school/university',
        Icons.school_outlined,
        Colors.red,
      );
      return;
    }

    // Validate email
    if (_emailController.text.trim().isEmpty ||
        !_emailController.text.contains('@')) {
      _showErrorSnackBar(
        'Please enter a valid email address',
        Icons.email_outlined,
        Colors.red,
      );
      return;
    }

    // Validate passwords match
    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      _showErrorSnackBar(
        'Passwords do not match',
        Icons.lock_outline,
        Colors.red,
      );
      return;
    }

    // Validate password length
    if (_passwordController.text.trim().length < 6) {
      _showErrorSnackBar(
        'Password must be at least 6 characters',
        Icons.lock_outline,
        Colors.red,
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Create user with Firebase Auth
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      if (credential.user != null) {
        // Update display name in Firebase Auth
        await credential.user!.updateDisplayName(
          _displayNameController.text.trim(),
        );

        // Create user document in Firestore
        await _createUserDocument(
          credential.user!,
          _displayNameController.text.trim(),
          _schoolController.text.trim(),
        );

        // Send email verification
        await credential.user!.sendEmailVerification();
      }

      if (!mounted) return;

      // Show success message
      _showSuccessSnackBar('Account created successfully!', Icons.check_circle);

      // Clear the entire navigation stack and go to home
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String errorMessage;
      IconData errorIcon = Icons.error_outline;
      Color errorColor = Colors.red;

      switch (e.code) {
        case 'weak-password':
          errorMessage =
              'Please use a stronger password with letters and numbers';
          errorIcon = Icons.lock_outline;
          break;

        case 'email-already-in-use':
          errorMessage = 'An account with this email already exists';
          errorIcon = Icons.email_outlined;
          break;

        case 'invalid-email':
          errorMessage = 'Please enter a valid email address';
          errorIcon = Icons.email_outlined;
          break;

        case 'operation-not-allowed':
          errorMessage =
              'Email/password accounts are not enabled. Please contact support';
          errorIcon = Icons.error_outline;
          break;

        case 'network-request-failed':
          errorMessage =
              'Connection problem. Please check your internet and try again';
          errorIcon = Icons.wifi_off;
          errorColor = Colors.orange;
          break;

        default:
          errorMessage = 'Unable to create account. Please try again';
          errorIcon = Icons.error_outline;
      }

      _showErrorSnackBar(errorMessage, errorIcon, errorColor);
    } catch (e) {
      if (!mounted) return;

      String errorMessage =
          'Connection problem. Please check your internet and try again';
      IconData errorIcon = Icons.wifi_off;
      Color errorColor = Colors.orange;

      final errorString = e.toString().toLowerCase();

      if (errorString.contains('network') ||
          errorString.contains('timeout') ||
          errorString.contains('connection') ||
          errorString.contains('host') ||
          errorString.contains('socket')) {
        errorMessage =
            'Network connection error. Please check your internet and try again';
        errorIcon = Icons.wifi_off;
        errorColor = Colors.orange;
      } else {
        errorMessage = 'Something went wrong. Please try again';
        errorIcon = Icons.error_outline;
        errorColor = Colors.red;
      }

      _showErrorSnackBar(errorMessage, errorIcon, errorColor);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  //  Error message handler with auto-dismiss
  void _showErrorSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  //  Success message handler
  void _showSuccessSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xFF6366F1),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Spacer(),
                  const Text(
                    'Sign Up',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            const SizedBox(height: 30),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create new account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Full Name field
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey[800]
                              : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey[700]!
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: TextField(
                          controller: _displayNameController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                          textCapitalization: TextCapitalization.words,
                          maxLength: 50,
                          decoration: InputDecoration(
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[700] : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.person_outline,
                                color: isDark
                                    ? Colors.grey[400]
                                    : const Color(0xFF6B7280),
                                size: 20,
                              ),
                            ),
                            hintText: 'Full name',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey[500]
                                  : const Color(0xFF9CA3AF),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email field
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey[800]
                              : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey[700]!
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: TextField(
                          controller: _emailController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[700] : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.email_outlined,
                                color: isDark
                                    ? Colors.grey[400]
                                    : const Color(0xFF6B7280),
                                size: 20,
                              ),
                            ),
                            hintText: 'Email address',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey[500]
                                  : const Color(0xFF9CA3AF),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Password field
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey[800]
                              : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey[700]!
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: TextField(
                          controller: _passwordController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[700] : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.lock_outline,
                                color: isDark
                                    ? Colors.grey[400]
                                    : const Color(0xFF6B7280),
                                size: 20,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: isDark
                                    ? Colors.grey[400]
                                    : const Color(0xFF6B7280),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            hintText: 'Password',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey[500]
                                  : const Color(0xFF9CA3AF),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Confirm Password field
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey[800]
                              : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey[700]!
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: TextField(
                          controller: _confirmPasswordController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[700] : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.lock_outline,
                                color: isDark
                                    ? Colors.grey[400]
                                    : const Color(0xFF6B7280),
                                size: 20,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: isDark
                                    ? Colors.grey[400]
                                    : const Color(0xFF6B7280),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                            hintText: 'Confirm Password',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey[500]
                                  : const Color(0xFF9CA3AF),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // School field
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey[800]
                              : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey[700]!
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: TextField(
                          controller: _schoolController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[700] : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.school_outlined,
                                color: isDark
                                    ? Colors.grey[400]
                                    : const Color(0xFF6B7280),
                                size: 20,
                              ),
                            ),
                            hintText: 'School/University',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey[500]
                                  : const Color(0xFF9CA3AF),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Sign Up button with keyboard dismissal
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  // Dismiss keyboard first, then signup
                                  FocusScope.of(context).unfocus();
                                  _signup();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // OR divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? Colors.grey[700]
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[500]
                                    : const Color(0xFF9CA3AF),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? Colors.grey[700]
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Google button - rectangular, full width
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey[700]!
                                : const Color(0xFFE5E7EB),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextButton.icon(
                          onPressed: _signUpWithGoogle,
                          style: TextButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white
                                : Colors.black87,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Image.asset(
                            'assets/google_logo.png',
                            height: 24,
                            width: 24,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.g_mobiledata,
                                color: Colors.red,
                                size: 24,
                              );
                            },
                          ),
                          label: Text(
                            'Sign up with Google',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Sign in link
                      Center(
                        child: GestureDetector(
                          onTap: () =>
                              Navigator.pushReplacementNamed(context, '/login'),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: "Already have an account? ",
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[500]
                                        : const Color(0xFF9CA3AF),
                                    fontSize: 16,
                                  ),
                                ),
                                const TextSpan(
                                  text: 'Sign in',
                                  style: TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _schoolController.dispose();
    super.dispose();
  }
}
