import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';

class EmailRegistrationCodeScreen extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final String password;

  const EmailRegistrationCodeScreen({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
  });

  @override
  State<EmailRegistrationCodeScreen> createState() =>
      _EmailRegistrationCodeScreenState();
}

class _EmailRegistrationCodeScreenState
    extends State<EmailRegistrationCodeScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _resending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showError(context.readStrings.enterSixDigitCode);
      return;
    }

    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().verifyEmailRegistrationCode(
            email: widget.email,
            code: code,
          );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) _showError(context.readStrings.errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await context.read<AuthProvider>().requestEmailRegistrationCode(
            name: widget.name,
            email: widget.email,
            phone: widget.phone,
            password: widget.password,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.readStrings.codeSentAgain)),
      );
    } catch (error) {
      if (mounted) _showError(context.readStrings.errorMessage(error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 28),
                onPressed: _loading ? null : () => Navigator.pop(context),
              ),
              const SizedBox(height: 32),
              Text(
                strings.emailVerificationCodeTitle,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Georgia',
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                strings.emailVerificationCodeSent(widget.email),
                style: TextStyle(
                  fontSize: 16,
                  color: scheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.emailVerificationHelp,
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 36),
              TextField(
                controller: _codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  labelText: strings.emailVerificationCode,
                ),
                onSubmitted: (_) {
                  if (!_loading) _verify();
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  child: _loading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : Text(strings.confirm),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _resending || _loading ? null : _resend,
                  child: Text(
                    _resending ? strings.sending : strings.resendCode,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
