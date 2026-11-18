import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/auth_provider.dart';
import '../widgets/common_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_idCtrl.text, _passCtrl.text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Login failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 820;
    return Scaffold(
      backgroundColor: Colors.white,
      body: wide
          ? Row(
              children: [
                Expanded(flex: 5, child: _brandPanel(context, fill: true)),
                Expanded(
                  flex: 6,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(48),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: _form(context),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _brandPanel(context, fill: false),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _form(context),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _brandPanel(BuildContext context, {required bool fill}) {
    final top = MediaQuery.of(context).padding.top;
    final header = Row(
      children: [
        const NyayVaaniEmblem(size: 44),
        const SizedBox(width: 12),
        Text(
          'NyayVanni',
          style: GoogleFonts.notoSans(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
    return Container(
      color: AppTheme.primaryDark,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(32, top + 28, 32, fill ? 40 : 24),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (fill) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Police Documentation System',
                  style: GoogleFonts.notoSans(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Container(width: 56, height: 3, color: AppTheme.accent),
                const SizedBox(height: 16),
                Text(
                  'Record a complainant’s statement in Hindi, Marathi or English and prepare a structured FIR draft for review.',
                  style: GoogleFonts.notoSans(
                    fontSize: 15,
                    color: Colors.white70,
                    height: 1.6,
                  ),
                ),
              ],
            ),
            Text(
              'For authorised police personnel only.',
              style: GoogleFonts.notoSans(fontSize: 12, color: Colors.white54),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Text(
              'Police Documentation System',
              style: GoogleFonts.notoSans(fontSize: 13, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  Widget _form(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sign in',
          style: GoogleFonts.notoSans(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter the Officer ID and password issued by your administrator.',
          style: GoogleFonts.notoSans(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        NyayaTextField(
          label: 'Officer ID',
          hint: 'e.g. NV-PO-2026-0001',
          controller: _idCtrl,
        ),
        const SizedBox(height: 16),
        NyayaTextField(
          label: 'Password',
          controller: _passCtrl,
          obscureText: true,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: auth.busy ? null : _submit,
            child: Text(auth.busy ? 'Signing in…' : 'Sign in'),
          ),
        ),
        const SizedBox(height: 28),
        const Divider(color: AppTheme.divider),
        const SizedBox(height: 14),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Don’t have an account? ',
              style: GoogleFonts.notoSans(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              ),
              child: Text(
                'Request access',
                style: GoogleFonts.notoSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
