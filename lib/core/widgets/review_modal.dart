import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/review_service.dart';

class ReviewModal extends StatefulWidget {
  final String itemType;
  final String itemId;
  final VoidCallback onReviewSubmitted;

  const ReviewModal({
    super.key,
    required this.itemType,
    required this.itemId,
    required this.onReviewSubmitted,
  });

  @override
  State<ReviewModal> createState() => _ReviewModalState();
}

class _ReviewModalState extends State<ReviewModal> {
  int _selectedRating = 5;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a comment'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await ReviewService.submitReview(
      itemType: widget.itemType,
      itemId: widget.itemId,
      rating: _selectedRating,
      comment: _commentController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        widget.onReviewSubmitted(); // Callback untuk refresh UI
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your review!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit review'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Rate Your Experience',
              style: TextStyle(fontFamily: 'Playfair Display', fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),

          // ⭐ Star Rating Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => setState(() => _selectedRating = index + 1),
                child: Icon(
                  index < _selectedRating ? Icons.star : Icons.star_border,
                  color: AppColors.primaryGold,
                  size: 40,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          const Text(
            'Your Review',
            style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 📝 Comment Input
          TextField(
            controller: _commentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Share your experience with other guests...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: AppColors.offWhite,
            ),
          ),
          const SizedBox(height: 24),

          // 🚀 Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkCharcoal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SUBMIT REVIEW', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}