import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'sms_code_screen.dart';

enum _LoginMode { email, phone }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  _LoginMode _mode = _LoginMode.email;
  PhoneCountry _phoneCountry = PhoneCountry.countries.first;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_mode == _LoginMode.email) {
        await context.read<AuthProvider>().login(
              email: _emailCtrl.text.trim(),
              password: _passwordCtrl.text,
            );
      } else {
        final phone =
            '+${_phoneCountry.dialCode}${_phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}';
        await context.read<AuthProvider>().requestPhoneCode(phone: phone);
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SMSCodeScreen(phone: phone)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[700]),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  strings.welcome,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Georgia',
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.signInSubtitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: scheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 48),
                _buildModeSwitch(),
                const SizedBox(height: 24),
                if (_mode == _LoginMode.email) ...[
                  _AuthField(
                    controller: _emailCtrl,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),
                  _AuthField(
                    controller: _passwordCtrl,
                    label: strings.password,
                    obscure: _obscure,
                    validator: _validatePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordScreen(
                            initialEmail: _emailCtrl.text.trim(),
                          ),
                        ),
                      ),
                      child: Text(
                        strings.forgotPassword,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  _buildPhoneField(strings.phoneNumber),
                  const SizedBox(height: 12),
                  Text(
                    strings.phoneCodeHelp,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : Text(
                            _mode == _LoginMode.email
                                ? strings.signIn
                                : strings.getCode,
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    Text(
                      strings.noAccount,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      ),
                      child: Text(
                        strings.register,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitch() {
    final scheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: strings.email,
            selected: _mode == _LoginMode.email,
            onTap: _loading
                ? null
                : () => setState(() => _mode = _LoginMode.email),
          ),
          _ModeButton(
            label: strings.phone,
            selected: _mode == _LoginMode.phone,
            onTap: _loading
                ? null
                : () => setState(() => _mode = _LoginMode.phone),
          ),
        ],
      ),
    );
  }

  String? _validateEmail(String? v) {
    final strings = context.readStrings;
    if (v == null || v.trim().isEmpty) return strings.enterEmail;
    if (!v.contains('@')) return strings.invalidEmail;
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return context.readStrings.enterPassword;
    return null;
  }

  String? _validatePhone(String? v) {
    final strings = context.readStrings;
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return strings.enterPhoneNumber;
    if (digits.length != _phoneCountry.maxDigits ||
        _phoneCountry.dialCode.length + digits.length < 10 ||
        _phoneCountry.dialCode.length + digits.length > 15) {
      return strings.invalidPhoneNumber;
    }
    return null;
  }

  Widget _buildPhoneField(String label) {
    final formatter = _PhoneMaskFormatter(_phoneCountry.groups);
    return TextFormField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      inputFormatters: [formatter],
      validator: _validatePhone,
      decoration: InputDecoration(
        labelText: label,
        prefixIconConstraints: const BoxConstraints(minWidth: 116),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 8, right: 4),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<PhoneCountry>(
              value: _phoneCountry,
              isExpanded: false,
              onChanged: _loading
                  ? null
                  : (country) {
                      if (country == null) return;
                      setState(() {
                        _phoneCountry = country;
                        final oldValue =
                            TextEditingValue(text: _phoneCtrl.text);
                        _phoneCtrl.value = _PhoneMaskFormatter(country.groups)
                            .formatEditUpdate(oldValue, oldValue);
                      });
                    },
              items: PhoneCountry.countries
                  .map(
                    (country) => DropdownMenuItem(
                      value: country,
                      child: Text(
                        '${country.flag}  ${country.name}  +${country.dialCode}',
                      ),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (context) => PhoneCountry.countries
                  .map(
                    (country) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text('${country.flag} +${country.dialCode}'),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class PhoneCountry {
  final String name;
  final String flag;
  final String dialCode;
  final List<int> groups;

  const PhoneCountry(this.name, this.flag, this.dialCode, this.groups);

  int get maxDigits => groups.fold(0, (total, group) => total + group);

  static const countries = [
    PhoneCountry('Россия', '🇷🇺', '7', [3, 3, 2, 2]),
    PhoneCountry('Казахстан', '🇰🇿', '7', [3, 3, 2, 2]),
    PhoneCountry('США', '🇺🇸', '1', [3, 3, 4]),
    PhoneCountry('Канада', '🇨🇦', '1', [3, 3, 4]),
    PhoneCountry('Великобритания', '🇬🇧', '44', [4, 3, 3]),
    PhoneCountry('Германия', '🇩🇪', '49', [3, 3, 4]),
    PhoneCountry('Франция', '🇫🇷', '33', [1, 2, 2, 2, 2]),
    PhoneCountry('Беларусь', '🇧🇾', '375', [2, 3, 2, 2]),
    PhoneCountry('Украина', '🇺🇦', '380', [2, 3, 2, 2]),
    PhoneCountry('Армения', '🇦🇲', '374', [2, 3, 2, 2]),
    PhoneCountry('Грузия', '🇬🇪', '995', [3, 2, 2, 2]),
    PhoneCountry('Турция', '🇹🇷', '90', [3, 3, 2, 2]),
    PhoneCountry('Узбекистан', '🇺🇿', '998', [2, 3, 2, 2]),
    PhoneCountry('Израиль', '🇮🇱', '972', [2, 3, 4]),
    PhoneCountry('Индия', '🇮🇳', '91', [5, 5]),
    PhoneCountry('Китай', '🇨🇳', '86', [3, 4, 4]),
    PhoneCountry('Япония', '🇯🇵', '81', [2, 4, 4]),
    PhoneCountry('Испания', '🇪🇸', '34', [3, 2, 2, 2]),
    PhoneCountry('Италия', '🇮🇹', '39', [3, 3, 4]),
    PhoneCountry('Польша', '🇵🇱', '48', [3, 3, 3]),
    PhoneCountry('Австралия', '🇦🇺', '61', [3, 3, 3]),
  ];
}

class _PhoneMaskFormatter extends TextInputFormatter {
  final List<int> groups;

  _PhoneMaskFormatter(this.groups);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final cursor = newValue.selection.baseOffset;
    final digitsBeforeCursor = cursor < 0
        ? digits.length
        : newValue.text
            .substring(0, cursor.clamp(0, newValue.text.length))
            .replaceAll(RegExp(r'\D'), '')
            .length;
    final maxDigits = groups.fold<int>(0, (total, group) => total + group);
    final limited = digits.substring(0, digits.length.clamp(0, maxDigits));
    final formatted = StringBuffer();
    var offset = 0;
    for (final group in groups) {
      if (offset >= limited.length) break;
      if (formatted.isNotEmpty) formatted.write(' ');
      final end = (offset + group).clamp(0, limited.length);
      formatted.write(limited.substring(offset, end));
      offset = end;
    }
    final text = formatted.toString();
    final targetDigitCount = digitsBeforeCursor.clamp(0, limited.length);
    var selectionOffset = 0;
    var seenDigits = 0;
    while (selectionOffset < text.length && seenDigits < targetDigitCount) {
      if (RegExp(r'\d').hasMatch(text[selectionOffset])) seenDigits++;
      selectionOffset++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: selectionOffset),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha:
                            scheme.brightness == Brightness.dark ? 0.28 : 0.08,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected
                  ? scheme.onSurface
                  : scheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;

  const _AuthField({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffix,
      ),
    );
  }
}
