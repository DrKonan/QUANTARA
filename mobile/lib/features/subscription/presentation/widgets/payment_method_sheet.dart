import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

class PaymentMethodSheet extends StatefulWidget {
  final String selectedPlan;
  final String? userPhone;
  final void Function({String? currency, String? phone, String? paymentMethod}) onPay;

  const PaymentMethodSheet({
    super.key,
    required this.selectedPlan,
    required this.onPay,
    this.userPhone,
  });

  @override
  State<PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends State<PaymentMethodSheet> {
  late PaymentCountry _selectedCountry;
  PaymentMethod? _selectedMethod;
  final _phoneCtrl = TextEditingController();
  bool _phoneValid = false;

  bool get _isWave => _selectedMethod?.isWave ?? false;
  bool get _canPay => _selectedMethod != null && _phoneValid;

  @override
  void initState() {
    super.initState();
    _selectedCountry =
        AppConstants.countryFromPhone(widget.userPhone) ?? AppConstants.countryFromLocale();
    if (widget.userPhone != null) {
      final dc = _selectedCountry.dialCode;
      final raw = widget.userPhone!.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final stripped = raw.startsWith('+$dc')
          ? raw.substring(dc.length + 1)
          : raw.startsWith(dc)
              ? raw.substring(dc.length)
              : raw;
      _phoneCtrl.text = stripped;
      _validatePhone();
    }
    _phoneCtrl.addListener(_validatePhone);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _validatePhone() {
    final clean = _phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-]'), '');
    setState(() => _phoneValid = clean.length >= 8);
  }

  void _onCountryChanged(PaymentCountry c) {
    setState(() {
      _selectedCountry = c;
      _selectedMethod = null;
      _phoneCtrl.clear();
      _phoneValid = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = AppConstants.currencyForCountry(_selectedCountry.code);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Paiement",
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            "Choisissez votre moyen de paiement mobile",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // ── Country selector ──
          const Text("Votre pays",
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showCountryPicker,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Row(
                children: [
                  Text(_selectedCountry.flag,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_selectedCountry.name}  (+${_selectedCountry.dialCode})',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary, size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Method selector ──
          const Text("Moyen de paiement",
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._selectedCountry.methods.map((m) {
            final isSelected = _selectedMethod?.id == m.id;
            final color = Color(m.color);
            return GestureDetector(
              onTap: () => setState(() => _selectedMethod = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.12)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : AppColors.surfaceLight,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(
                        m.isWave
                            ? Icons.waves_rounded
                            : Icons.phone_android_rounded,
                        color: color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name,
                              style: TextStyle(
                                  color: isSelected
                                      ? color
                                      : AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            m.isWave
                                ? "Paiement via l'appli Wave"
                                : "Push USSD sur votre téléphone",
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: color, size: 20),
                  ],
                ),
              ),
            );
          }),

          // ── Phone input ──
          if (_selectedMethod != null) ...[
            const SizedBox(height: 8),
            const Text("Numéro de téléphone",
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Text(
                    '+${_selectedCountry.dialCode}',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'X' * _selectedCountry.localDigits,
                      hintStyle: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.4)),
                      prefixIcon: const Icon(Icons.phone_outlined,
                          color: AppColors.textSecondary, size: 20),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.surfaceLight)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.surfaceLight)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.gold)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  _isWave
                      ? Icons.open_in_new_rounded
                      : Icons.phone_callback_outlined,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isWave
                        ? "Votre numéro Wave sera utilisé pour générer le lien de paiement."
                        : "Un code USSD sera envoyé sur votre téléphone ${_selectedCountry.flag}.",
                    style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontSize: 11),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // ── Pay button ──
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _canPay
                  ? () {
                      final phone =
                          '+${_selectedCountry.dialCode}${_phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-]'), '')}';
                      widget.onPay(
                        currency: currency,
                        phone: phone,
                        paymentMethod: _selectedMethod!.id,
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                disabledBackgroundColor: AppColors.surfaceLight,
                foregroundColor: Colors.black,
                disabledForegroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isWave ? Icons.waves_rounded : Icons.smartphone_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedMethod != null
                        ? "Payer avec ${_selectedMethod!.name}"
                        : "Choisissez un moyen de paiement",
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Choisir votre pays",
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: AppConstants.supportedCountries.length,
                itemBuilder: (ctx, i) {
                  final country = AppConstants.supportedCountries[i];
                  final isSelected = country.code == _selectedCountry.code;
                  return ListTile(
                    leading: Text(country.flag,
                        style: const TextStyle(fontSize: 24)),
                    title: Text(country.name,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14)),
                    subtitle: Text(
                      country.methods.map((m) => m.name).join(' · '),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                    trailing: Text('+${country.dialCode}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    selected: isSelected,
                    selectedTileColor: AppColors.gold.withValues(alpha: 0.08),
                    onTap: () {
                      _onCountryChanged(country);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
