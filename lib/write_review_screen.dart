import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart'; // ADD THIS

class WriteReviewScreen extends StatefulWidget {
  final String userId;

  const WriteReviewScreen({required this.userId, Key? key}) : super(key: key);

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  double rating = 0;
  final TextEditingController commentController = TextEditingController();

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  void submitReview() async {
    if (_formKey.currentState!.validate() && rating > 0) {
      await FirebaseFirestore.instance.collection('reviews').add({
        'reviewedUserId': widget.userId,
        'reviewerId': FirebaseAuth.instance.currentUser!.uid,
        'rating': rating,
        'comment': commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Review submitted')));
        Navigator.pop(context);
      }
    } else if (rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write a Review')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              RatingBar.builder(
                initialRating: 0,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) =>
                    const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (value) {
                  setState(() {
                    rating = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: commentController,
                decoration: const InputDecoration(labelText: 'Comment'),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please enter a comment'
                    : null,
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: submitReview,
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
