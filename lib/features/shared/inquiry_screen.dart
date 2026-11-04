import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

class InquiryScreen extends StatefulWidget {
  final String title;
  final String subtitle;

  const InquiryScreen({super.key, required this.title, required this.subtitle});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  DateTime? _selectedDate;

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGold,
              onPrimary: Colors.white,
              onSurface: AppColors.darkCharcoal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _submitInquiry() {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Inquiry Received', style: TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.primaryGold, size: 48),
              const SizedBox(height: 16),
              Text('Thank you, ${_nameController.text}!', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Our team will contact you shortly regarding your inquiry.', textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Tutup dialog
                Navigator.pop(context); // Kembali ke halaman sebelumnya
              },
              child: const Text('Done', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose(); _emailController.dispose();
    _phoneController.dispose(); _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.darkCharcoal), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.subtitle, style: const TextStyle(fontFamily: 'Lato', fontSize: 14, color: AppColors.textGrey)).animate().fadeIn(),
              const SizedBox(height: 32),
              
              _buildTextField(_nameController, 'Full Name', Icons.person_outline, 'Please enter your name'),
              const SizedBox(height: 16),
              _buildTextField(_emailController, 'Email Address', Icons.email_outlined, 'Please enter a valid email', TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildTextField(_phoneController, 'Phone Number', Icons.phone_outlined, 'Please enter your phone number', TextInputType.phone),
              const SizedBox(height: 16),
              
              // Date Picker
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3))),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.primaryGold, size: 20),
                      const SizedBox(width: 12),
                      Text(_selectedDate == null ? 'Preferred Date (Optional)' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                          style: TextStyle(fontFamily: 'Lato', fontSize: 14, color: _selectedDate == null ? Colors.grey : AppColors.darkCharcoal)),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms),
              
              const SizedBox(height: 16),
              
              // Message
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3))),
                child: TextFormField(
                  controller: _messageController,
                  maxLines: 4,
                  validator: (value) => value!.isEmpty ? 'Please enter your message or specific requests' : null,
                  decoration: const InputDecoration(
                    hintText: 'Your message or specific requests...',
                    hintStyle: TextStyle(fontFamily: 'Lato', fontSize: 14, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms),
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitInquiry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Submit Inquiry', style: TextStyle(fontFamily: 'Lato', fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, String errorText, [TextInputType? type]) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3))),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        validator: (value) => value!.isEmpty ? errorText : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'Lato', fontSize: 14, color: AppColors.textGrey),
          prefixIcon: Icon(icon, color: AppColors.primaryGold, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }
}