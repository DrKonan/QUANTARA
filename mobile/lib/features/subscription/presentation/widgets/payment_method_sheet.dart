import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

class PaymentMethodSheet extends ConsumerStatefulWidget {
  final String selectedPlan;
  final String? userPhone;
  final void Function({String? currency, String? phone, String? paymentMethod}) onPay;

  const PaymentMethodSheet({
    super.key,
    required this.selectedPlan,
    this.userPhone,
    required this.onPay,
  });

  @override
  ConsumerState<PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends ConsumerState<PaymentMethodSheet> {
  late PaymentCountry _country;
  PaymentMethod? _selectedMethod;
  late TextEditingController _phoneCtrl;
  bool _phoneValid = false;

  @override
  void initState() {
    super.initState();
    _country = _detectCountry();
    _selectedMethod = _country.methods.isNotEmpty ? _country.methods.first : null;
    final initialPhone = _stripCountryCode(widget.userPhone ?? '', _country.dialCode);
    _phoneCtrl = TextEditingController(text: initialPhone);
    _phoneValid = initialPhone.length >= 7;
    _phoneCtrl.addListener(_onPhoneChange);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  PaymentCountry _detectCountry() {
    final phone = widget.userPhone ?? '';
    if (phone.isNotEmpty) {
      final clean = phone.replaceAll('+', '').replaceAll(' ', '');
      for (final c in AppConstants.supportedCountries) {
        if (clean.startsWith(c.dialCode)) return c;
      }
    }
    return AppConstants.countryFromLocale();
  }

  String _stripCountryCode(String phone, String dialCode) {
    final clean = phone.replaceAll('+', '').replaceAll(' ', '');
    if (clean.startsWith(dialCode)) return clean.substring(dialCode.length);
    return clean;
  }

  String get _e164Phone {
    final local = _phoneCtrl.text.trim().replaceAll(' ', '');
    return '+${_country.dialCode}$local';
  }

  String get _currency {
    const xafCountries = {'CM', 'GA', 'CG', 'CD', 'CF', 'GQ', 'TD'};
    return xafCountries.contains(_country.code) ? 'XAF' : 'XOF';
  }

  void _onPhoneChange() {
    setState(() {
      _phoneValid = _phoneCtrl.text.trim().length >= 7;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'Moyen de paiement',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          // Country selector
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickCountry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.textSecondary.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Text(_country.flag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _country.name,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Methods
          if (_country.methods.isNotEmpty) ...[
            const Text(
              'Opérateur',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _country.methods.map((m) => _MethodChip(
                method: m,
                selected: _selectedMethod?.id == m.id,
                onTap: () => setState(() => _selectedMethod = m),
              )).toList(),
            ),
            const SizedBox(height: 14),
          ],

          // Phone field
          const Text(
            'Numéro de téléphone',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textSecondary.withOpacity(0.15)),
                ),
                child: Text(
                  '+${_country.dialCode}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Numéro local',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 14),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.15)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pay button
          ElevatedButton(
            onPressed: (_selectedMethod != null && _phoneValid) ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              disabledBackgroundColor: AppColors.gold.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _selectedMethod != null
                  ? 'Payer avec ${_selectedMethod!.name}'
                  : 'Sélectionnez un opérateur',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_selectedMethod == null) return;
    HapticFeedback.mediumImpact();
    widget.onPay(
      currency: _currency,
      phone: _e164Phone,
      paymentMethod: _selectedMethod!.id,
    );
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<PaymentCountry>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CountryPickerSheet(countries: AppConstants.supportedCountries),
    );
    if (picked != null) {
      setState(() {
        _country = picked;
        _selectedMethod = picked.methods.isNotEmpty ? picked.methods.first : null;
        _phoneCtrl.text = _stripCountryCode(widget.userPhone ?? '', picked.dialCode);
      });
    }
  }
}

// ── Method chip ──────────────────────────────────────────────
class _MethodChip extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _MethodChip({required this.method, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Color(method.color).withOpacity(0.15) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Color(method.color) : AppColors.textSecondary.withOpacity(0.15),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_circle, color: Color(method.color), size: 14),
              const SizedBox(width: 4),
            ],
            Text(
              method.name,
              style: TextStyle(
                color: selected ? Color(method.color) : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Country picker ──────────────────────────────────────────
class _CountryPickerSheet extends StatelessWidget {
  final List<PaymentCountry> countries;
  const _CountryPickerSheet({required this.countries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          'Choisir un pays',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: countries.length,
            itemBuilder: (ctx, i) {
              final c = countries[i];
              return ListTile(
                leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                title: Text(c.name, style: const TextStyle(color: AppColors.textPrimary)),
                subtitle: Text('+${c.dialCode}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, c),
              );
            },
          ),
        ),
      ],
    );
  }
}
