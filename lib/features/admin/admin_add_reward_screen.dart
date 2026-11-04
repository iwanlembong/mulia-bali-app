import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/reward_model.dart';
import '../../core/services/reward_service.dart';

class AdminAddRewardScreen extends StatefulWidget {
  // ✅ Terima data reward opsional untuk mode edit
  final Reward? rewardToEdit;
  const AdminAddRewardScreen({super.key, this.rewardToEdit});

  @override
  State<AdminAddRewardScreen> createState() => _AdminAddRewardScreenState();
}

class _AdminAddRewardScreenState extends State<AdminAddRewardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();

  String _selectedType = 'discount_percentage';
  String _selectedApplicable = 'all';
  bool _isSaving = false;
  bool get _isEditMode => widget.rewardToEdit != null; // ✅ Cek mode

  @override
  void initState() {
    super.initState();
    // ✅ Jika mode edit, isi form dengan data yang ada
    if (_isEditMode) {
      _titleCtrl.text = widget.rewardToEdit!.title;
      _descCtrl.text = widget.rewardToEdit!.description;
      _pointsCtrl.text = widget.rewardToEdit!.pointsRequired.toString();
      _valueCtrl.text = widget.rewardToEdit!.rewardValue;
      _selectedType = widget.rewardToEdit!.rewardType;
      _selectedApplicable = widget.rewardToEdit!.applicableTo;
    }
  }

  Future<void> _saveReward() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final rewardData = Reward(
      id: _isEditMode ? widget.rewardToEdit!.id : '',
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      pointsRequired: int.parse(_pointsCtrl.text.trim()),
      rewardType: _selectedType,
      rewardValue: _valueCtrl.text.trim(),
      applicableTo: _selectedApplicable,
      isActive: _isEditMode ? widget.rewardToEdit!.isActive : true,
    );

    // ✅ Panggil method yang sesuai (Insert atau Update)
    final success = _isEditMode
        ? await RewardService.updateReward(rewardData)
        : await RewardService.createReward(rewardData);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Reward successfully updated!'
                : 'Reward successfully added!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      if (success) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: Text(
          _isEditMode ? 'Edit Reward' : 'Add Reward',
          style: const TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isSaving
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGold),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      _titleCtrl,
                      'Reward Title (e.g., 10% Spa Discount)',
                      true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _descCtrl,
                      'Brief Description',
                      false,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _pointsCtrl,
                            'Points Required',
                            true,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            _valueCtrl,
                            'Value (e.g., 10 or 50000)',
                            true,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ✅ 1. DROPDOWN TIPE REWARD
                    // (Teks judul dihapus, dipindah ke labelText)
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Reward Type', // ✅ Label mengambang
                        labelStyle: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.textGrey),
                        floatingLabelStyle: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'discount_percentage', child: Text('Percentage Discount (%)')),
                        DropdownMenuItem(value: 'discount_fixed', child: Text('Nominal Discount (Rp)')),
                        DropdownMenuItem(value: 'free_service', child: Text('Free Service')),
                      ],
                      onChanged: (val) => setState(() => _selectedType = val!),
                    ),

                    const SizedBox(height: 16),

                    // ✅ 2. DROPDOWN BERLAKU UNTUK
                    // (Teks judul dihapus, dipindah ke labelText)
                    DropdownButtonFormField<String>(
                      value: _selectedApplicable,
                      decoration: InputDecoration(
                        labelText: 'Applies to', // ✅ Label mengambang
                        labelStyle: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.textGrey),
                        floatingLabelStyle: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All (Services & Accommodation)')),
                        DropdownMenuItem(value: 'services', child: Text('Services Only (Spa, Dining, etc.)')),
                        DropdownMenuItem(value: 'accommodation', child: Text('Accommodation Only (Room)')),
                      ],
                      onChanged: (val) => setState(() => _selectedApplicable = val!),
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveReward,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _isEditMode ? 'UPDATE REWARD' : 'SAVE REWARD',
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, bool isRequired, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        // ✅ PERBAIKAN: Gunakan labelText agar label tetap terlihat (mengambang) saat form terisi
        labelText: label, 
        labelStyle: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.textGrey),
        floatingLabelStyle: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.primaryGold, fontWeight: FontWeight.bold),
        
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: isRequired ? (val) => val == null || val.trim().isEmpty ? 'Is Required' : null : null,
    );
  }
}
