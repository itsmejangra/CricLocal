import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildTextField(
                label: 'Email Address',
                controller: _emailController,
                hint: 'How can we reach you?',
                icon: Icons.email_outlined,
                validator: (v) => v?.contains('@') == true ? null : 'Valid email required',
              ),
              const SizedBox(height: 20),
              _buildTextField(
                label: 'Message',
                controller: _messageController,
                hint: 'How can we help or improve?',
                icon: Icons.chat_bubble_outline,
                maxLines: 5,
                validator: (v) => (v?.length ?? 0) > 10 ? null : 'Please describe your query',
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSending ? null : _handleSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSending 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('SEND FEEDBACK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 48),
              _buildSupportInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accentTeal.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.headset_mic_outlined, size: 48, color: AppTheme.accentTeal),
        ),
        const SizedBox(height: 16),
        Text('We\'re All Ears!', style: AppTheme.headlineSmall.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Have a feature request or found a bug? Let the CricLocal team know.',
          textAlign: TextAlign.center,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: AppTheme.backgroundGray.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportInfo() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 24),
        Text('Connect directly', style: AppTheme.bodySmall),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _socialIcon(Icons.language, 'Website'),
            const SizedBox(width: 24),
            _socialIcon(Icons.terminal, 'GitHub'),
            const SizedBox(width: 24),
            _socialIcon(Icons.mail, 'Direct'),
          ],
        ),
      ],
    );
  }

  Widget _socialIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }

  void _handleSend() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSending = true);
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _isSending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thanks! We have received your message.')),
          );
          Navigator.pop(context);
        }
      });
    }
  }
}
