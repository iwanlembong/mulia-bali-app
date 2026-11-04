class FormValidators {
  // Email validation dengan regex
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    // Regex untuk validasi email
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  // Password validation (min 8 karakter, huruf besar, angka)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    
    return null;
  }

  // Nama (min 2 karakter, hanya huruf dan spasi)
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return 'Name can only contain letters and spaces';
    }
    
    return null;
  }

  // Nomor telepon (format Indonesia/internasional)
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    
    // Hapus spasi dan tanda +
    final cleaned = value.replaceAll(RegExp(r'[\s+]'), '');
    
    if (!RegExp(r'^[0-9]{10,15}$').hasMatch(cleaned)) {
      return 'Please enter a valid phone number (10-15 digits)';
    }
    
    return null;
  }

  // Required field (generic)
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // Confirm password
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (value != password) {
      return 'Passwords do not match';
    }
    
    return null;
  }

  // ✅ BARU: Validasi Angka Positif (Untuk Jumlah Tamu & Kamar)
  static String? validatePositiveInteger(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    final number = int.tryParse(value);
    if (number == null || number <= 0) {
      return '$fieldName must be at least 1';
    }
    return null;
  }

  // ✅ BARU: Validasi Tanggal Check-out (Harus setelah Check-in)
  static String? validateCheckoutDate(DateTime? checkIn, DateTime? checkOut) {
    if (checkOut == null) return 'Check-out date is required';
    if (checkIn != null && !checkOut.isAfter(checkIn)) {
      return 'Check-out date must be after Check-in date';
    }
    return null;
  }
}