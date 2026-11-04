import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/property_model.dart';
import '../../core/services/property_service.dart';
import '../../core/services/reservation_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/review_service.dart'; // ✅ Pastikan import ini ada

class PropertyDetailScreen extends StatefulWidget {
  final String propertyId;

  const PropertyDetailScreen({super.key, required this.propertyId});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  bool _isLoading = true;
  DbProperty? _property;
  List<DbRoom> _rooms = [];
  String? _errorMessage;

  // ✅ STATE VARIABLES UNTUK BOOKING
  DateTime? _checkIn;
  DateTime? _checkOut;
  int _adults = 2;
  int _children = 0;
  int _roomCount = 1;
  DbRoom? _selectedRoom;
  bool _isCheckingAvailability = false;
  int? _availableRooms;

  // ✅ STATE UNTUK REVIEW
  double _averageRating = 0.0;
  int _totalReviews = 0;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchReviews(); // ✅ Ambil data review saat halaman dibuka
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dbProperty = await PropertyService.getPropertyById(widget.propertyId);
      final dbRooms = await PropertyService.getRoomsByPropertyId(widget.propertyId);

      if (mounted) {
        if (dbProperty != null && dbRooms.isNotEmpty) {
          setState(() {
            _property = dbProperty;
            _rooms = dbRooms;
            _isLoading = false;
          });
        } else {
          // Fallback logic tetap dipertahankan
          final fallbackProperty = baliProperties.firstWhere(
            (p) => p.id == widget.propertyId,
            orElse: () => throw Exception('Property not found'),
          );
          setState(() {
            _property = DbProperty(
              id: fallbackProperty.id,
              name: fallbackProperty.name,
              tagline: fallbackProperty.tagline,
              description: fallbackProperty.description,
              coverImage: fallbackProperty.heroImageUrl,
              highlights: [],
              isActive: true,
            );
            _rooms = []; 
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load property details.';
          _isLoading = false;
        });
      }
    }
  }

  // ✅ 1. Method untuk Mengambil Data Review
  Future<void> _fetchReviews() async {
    setState(() => _isLoadingReviews = true);
    
    // ✅ Gunakan widget.propertyId sebagai target review properti
    final targetId = widget.propertyId; 

    final avgRating = await ReviewService.getAverageRating('property', targetId);
    final reviews = await ReviewService.getReviews('property', targetId);

    if (mounted) {
      setState(() {
        _averageRating = avgRating;
        _totalReviews = reviews.length;
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    }
  }

  // ✅ 2. Widget UI untuk Menampilkan Review
  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 24),
        
        const Text(
          'Guest Reviews',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.darkCharcoal,
          ),
        ),
        const SizedBox(height: 16),

        // Loading State
        if (_isLoadingReviews)
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: AppColors.primaryGold),
          ))
        
        // Empty State
        else if (_reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              children: [
                Icon(Icons.rate_review_outlined, size: 40, color: AppColors.textGrey),
                SizedBox(height: 12),
                Text(
                  'No reviews yet. Be the first to share your stay experience!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey),
                ),
              ],
            ),
          )
        
        // List Reviews
        else ...[
          // Rating Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  _averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < _averageRating.round() ? Icons.star : Icons.star_border,
                          color: AppColors.primaryGold,
                          size: 16,
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on $_totalReviews reviews',
                      style: const TextStyle(fontFamily: 'Lato', fontSize: 12, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Individual Review Cards
          ..._reviews.map((review) {
            final userName = review['user_name'] ?? 'Valued Guest';
            final comment = review['comment'] ?? '';
            final rating = review['rating'] as int;
            final date = DateTime.parse(review['created_at']);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primaryGold.withOpacity(0.2),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'G',
                          style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              DateFormat('dd MMM yyyy').format(date),
                              style: const TextStyle(fontFamily: 'Lato', fontSize: 11, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: AppColors.primaryGold,
                            size: 14,
                          );
                        }),
                      ),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(
                      comment,
                      style: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.darkCharcoal, height: 1.5),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  void _openBookingSheet(DbRoom room) {
    setState(() {
      _selectedRoom = room;
      _checkIn = null;
      _checkOut = null;
      _availableRooms = null;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedRoom!.name,
                          style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal),
                          maxLines: 2,
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('IDR ${_formatPrice(_selectedRoom!.pricePerNight)} / night', style: const TextStyle(fontFamily: 'Lato', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryGold)),
                  const SizedBox(height: 24),

                  const Text('Select Dates', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Lato')),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDateRange: _checkIn != null && _checkOut != null ? DateTimeRange(start: _checkIn!, end: _checkOut!) : null,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryGold, onPrimary: Colors.white)),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setModalState(() {
                          _checkIn = picked.start;
                          _checkOut = picked.end;
                          _availableRooms = null;
                        });
                        _checkAvailability(setModalState);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.textGrey.withOpacity(0.3)), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: AppColors.primaryGold),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _checkIn != null && _checkOut != null
                                  ? '${DateFormat('dd MMM').format(_checkIn!)} - ${DateFormat('dd MMM yyyy').format(_checkOut!)}'
                                  : 'Tap to select check-in & check-out',
                              style: TextStyle(color: _checkIn != null ? AppColors.darkCharcoal : AppColors.textGrey, fontFamily: 'Lato'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Guests & Rooms', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Lato')),
                  const SizedBox(height: 8),
                  _buildCounterRow('Adults', _adults, (val) => setModalState(() => _adults = val), min: 1),
                  const SizedBox(height: 12),
                  _buildCounterRow('Children', _children, (val) => setModalState(() => _children = val), min: 0),
                  const SizedBox(height: 12),
                  _buildCounterRow('Rooms', _roomCount, (val) {
                    setModalState(() => _roomCount = val);
                    _checkAvailability(setModalState);
                  }, min: 1),

                  const SizedBox(height: 24),

                  if (_isCheckingAvailability)
                    const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
                  else if (_availableRooms != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _availableRooms! > 0 ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(_availableRooms! > 0 ? Icons.check_circle : Icons.error, color: _availableRooms! > 0 ? Colors.green : Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _availableRooms! > 0 ? 'Available! ($_availableRooms rooms left)' : 'Fully booked for these dates.',
                              style: TextStyle(color: _availableRooms! > 0 ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold, fontFamily: 'Lato'),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  if (_checkIn != null && _checkOut != null && _availableRooms != null && _availableRooms! > 0) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Price', style: TextStyle(color: AppColors.textGrey, fontFamily: 'Lato')),
                            Text('IDR ${_formatPrice(_calculateTotal())}', style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () {
                            context.pop();
                            _proceedToBookingForm();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.darkCharcoal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('BOOK NOW', style: TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCounterRow(String label, int value, Function(int) onChanged, {int min = 0}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Lato', color: AppColors.textGrey)),
        Row(
          children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline), color: value <= min ? Colors.grey : AppColors.darkCharcoal, onPressed: value <= min ? null : () => onChanged(value - 1)),
            SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Lato', fontSize: 16, fontWeight: FontWeight.bold))),
            IconButton(icon: const Icon(Icons.add_circle_outline), color: AppColors.darkCharcoal, onPressed: () => onChanged(value + 1)),
          ],
        ),
      ],
    );
  }

  Future<void> _checkAvailability(StateSetter setModalState) async {
    if (_checkIn == null || _checkOut == null || _selectedRoom == null) return;
    setModalState(() => _isCheckingAvailability = true);
    
    final available = await ReservationService.checkAvailability(
      roomId: _selectedRoom!.id,
      checkIn: _checkIn!,
      checkOut: _checkOut!,
      roomCount: _roomCount,
    );

    setModalState(() {
      _isCheckingAvailability = false;
      _availableRooms = available;
    });
  }

  int _calculateTotal() {
    if (_checkIn == null || _checkOut == null || _selectedRoom == null) return 0;
    final nights = _checkOut!.difference(_checkIn!).inDays;
    return _selectedRoom!.pricePerNight * nights * _roomCount;
  }

  void _proceedToBookingForm() {
    if (!AuthService.isLoggedIn) {
      AuthService.setReturnPath('/property/${widget.propertyId}');
      context.push('/login');
      return;
    }

    context.push('/reservation-form', extra: {
      'propertyId': widget.propertyId,
      'roomId': _selectedRoom!.id,
      'roomName': _selectedRoom!.name,
      'roomImageUrl': _selectedRoom!.imageUrl,
      'checkIn': _checkIn,
      'checkOut': _checkOut,
      'pricePerNight': _selectedRoom!.pricePerNight,
      'roomCount': _roomCount,
      'adults': _adults,
      'children': _children,
      'totalAmount': _calculateTotal(),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
      );
    }

    if (_errorMessage != null || _property == null) {
      return Scaffold(
        backgroundColor: AppColors.offWhite,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage ?? 'Property not found', style: const TextStyle(fontFamily: 'Lato', color: AppColors.textGrey)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => context.pop(), child: const Text('Go Back')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _property!.coverImage ?? 'https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?auto=format&fit=crop&w=800&q=80',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: AppColors.darkCharcoal),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_property!.name.toUpperCase(), style: const TextStyle(color: AppColors.primaryGold, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text(_property!.tagline ?? '', style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(_property!.location ?? 'Bali, Indonesia', style: const TextStyle(color: AppColors.textGrey, fontSize: 14)),
                      const Spacer(),
                      ...List.generate(_property!.starRating, (index) => const Icon(Icons.star, size: 16, color: AppColors.primaryGold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  
                  // ✅ Bagian About Property
                  const Text('About', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                  const SizedBox(height: 12),
                  Text(_property!.description ?? 'No description available.', style: const TextStyle(fontFamily: 'Lato', fontSize: 15, color: AppColors.textGrey, height: 1.6)),
                  const SizedBox(height: 32),
                  
                  // ✅ Bagian Available Rooms
                  const Text('Available Rooms', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                  const SizedBox(height: 16),
                  if (_rooms.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No rooms currently available.', style: TextStyle(color: AppColors.textGrey))))
                  else
                    ..._rooms.map((room) => _buildRoomCard(room)).toList(),
                  
                  const SizedBox(height: 32),

                  // ✅ 3. TAMBAHKAN BAGIAN REVIEW DI SINI (Setelah daftar kamar)
                  _buildReviewsSection(),

                  const SizedBox(height: 100), // Jarak aman untuk bottom UI
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(DbRoom room) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              room.imageUrl ?? _property!.coverImage ?? 'https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?auto=format&fit=crop&w=600&q=80',
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 180, color: AppColors.offWhite, child: const Icon(Icons.image_not_supported)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name, style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (room.bedType != null) ...[
                      const Icon(Icons.king_bed_outlined, size: 16, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(room.bedType!, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                      const SizedBox(width: 12),
                    ],
                    if (room.sizeSqm != null) ...[
                      const Icon(Icons.square_foot_outlined, size: 16, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text('${room.sizeSqm} sqm', style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Starting from', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                        Text('IDR ${_formatPrice(room.pricePerNight)}', style: const TextStyle(fontFamily: 'Lato', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryGold)),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => _openBookingSheet(room),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkCharcoal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Select & Book', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}