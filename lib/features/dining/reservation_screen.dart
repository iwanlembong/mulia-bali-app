import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

class ReservationScreen extends StatefulWidget {
  final String? restaurantName; // Opsional, bisa null

  const ReservationScreen({super.key, this.restaurantName});

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers untuk input field
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  late String _selectedRestaurant;
  
  // State untuk dropdown dan picker
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  int _guestCount = 2;
  
  // Daftar restoran (Pastikan string di sini konsisten)
  final List<String> _restaurants = [
    'Table8 - Chinese Fine Dining',
    'Soleil - Mediterranean',
    'The Cafe - International Buffet',
    'Sky Bar - Cocktails & Light Bites',
    'Kaizetsu - Japanese',
    'MAMAS - Indonesian',
  ];

  @override
  void initState() {
    super.initState();
    
    // LOGIKA PINTAR: Cari kecocokan nama restoran
    if (widget.restaurantName != null) {
      // Cari di daftar _restaurants yang mengandung nama yang dikirim (case-insensitive)
      _selectedRestaurant = _restaurants.firstWhere(
        (r) => r.toLowerCase().contains(widget.restaurantName!.toLowerCase()),
        orElse: () => 'Table8 - Chinese Fine Dining', // Fallback jika tidak ditemukan
      );
    } else {
      _selectedRestaurant = 'Table8 - Chinese Fine Dining'; // Default
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
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
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submitReservation() {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Reservation Confirmed',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontWeight: FontWeight.bold,
              color: AppColors.darkCharcoal,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, color: AppColors.primaryGold, size: 48),
              const SizedBox(height: 16),
              _buildConfirmRow('Guest', _nameController.text),
              _buildConfirmRow('Restaurant', _selectedRestaurant),
              _buildConfirmRow('Date', '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
              _buildConfirmRow('Time', _selectedTime.format(context)),
              _buildConfirmRow('Party Size', '$_guestCount guests'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Tutup dialog
                Navigator.pop(context); // Kembali ke halaman Dining
              },
              child: const Text(
                'Done',
                style: TextStyle(
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Lato',
                color: AppColors.textGrey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Lato',
                color: AppColors.darkCharcoal,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text(
          'Reserve a Table',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
            color: AppColors.darkCharcoal,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkCharcoal),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete Your Reservation',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkCharcoal,
                ),
              ).animate().fadeIn().slideX(begin: -0.2, end: 0),
              
              const SizedBox(height: 8),
              
              const Text(
                'Please fill in the details below to secure your dining experience.',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 14,
                  color: AppColors.textGrey,
                ),
              ).animate().fadeIn(delay: 200.ms),
              
              const SizedBox(height: 32),
              
              // Pilih Restoran
              _buildSectionTitle('Select Restaurant'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedRestaurant,
                    items: _restaurants.map((restaurant) {
                      return DropdownMenuItem(
                        value: restaurant,
                        child: Text(
                          restaurant,
                          style: const TextStyle(fontFamily: 'Lato', fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRestaurant = value!;
                      });
                    },
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
              
              const SizedBox(height: 24),
              
              // Tanggal & Waktu
              _buildSectionTitle('Date & Time'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildPickerButton(
                      icon: Icons.calendar_today,
                      label: '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      onTap: _selectDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPickerButton(
                      icon: Icons.access_time,
                      label: _selectedTime.format(context),
                      onTap: _selectTime,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms),
              
              const SizedBox(height: 24),
              
              // Jumlah Tamu
              _buildSectionTitle('Number of Guests'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.primaryGold),
                      onPressed: _guestCount > 1 ? () => setState(() => _guestCount--) : null,
                    ),
                    Text(
                      '$_guestCount ${_guestCount == 1 ? 'Guest' : 'Guests'}',
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryGold),
                      onPressed: _guestCount < 20 ? () => setState(() => _guestCount++) : null,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 500.ms),
              
              const SizedBox(height: 24),
              
              // Informasi Tamu
              _buildSectionTitle('Guest Information'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_outline,
                validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
              ).animate().fadeIn(delay: 600.ms),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter your email';
                  if (!value.contains('@')) return 'Please enter a valid email';
                  return null;
                },
              ).animate().fadeIn(delay: 700.ms),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Please enter your phone number' : null,
              ).animate().fadeIn(delay: 800.ms),
              
              const SizedBox(height: 24),
              
              // Permintaan Khusus
              _buildSectionTitle('Special Requests (Optional)'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                ),
                child: TextField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Allergies, dietary preferences, special occasions...',
                    hintStyle: TextStyle(fontFamily: 'Lato', fontSize: 14, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ).animate().fadeIn(delay: 900.ms),
              
              const SizedBox(height: 32),
              
              // Tombol Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitReservation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Confirm Reservation',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.2, end: 0),
              ),
              
              const SizedBox(height: 16),
              
              Center(
                child: Text(
                  'A confirmation email will be sent to you shortly.',
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 12,
                    color: AppColors.textGrey.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.darkCharcoal,
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryGold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 14,
                  color: AppColors.darkCharcoal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'Lato', fontSize: 14, color: AppColors.textGrey),
          prefixIcon: Icon(icon, color: AppColors.primaryGold, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}