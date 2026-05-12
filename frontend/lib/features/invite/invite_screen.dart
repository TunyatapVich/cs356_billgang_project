import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  static const primaryBlue = Color(0xFF4E54C8);
  static const bgLight = Color(0xFFF6F8FD);
  static const cardWhite = Colors.white;
  static const textDark = Color(0xFF2C3246);
  static const textGray = Color(0xFF8E95A9);
  static const inputBorder = Color(0xFFDCDFEA);
  static const errorRed = Color(0xFFD94848);

  String? _inviteCode;
  String? _billId;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode() async {
    final billId = GoRouterState.of(context).pathParameters['id'];
    if (billId == null || billId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Bill not found';
      });
      return;
    }
    _billId = billId;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ref.read(authDioProvider).post('/bills/$_billId/invite');
      final data = response.data as Map<String, dynamic>;
      final code = (data['invite_code'] ?? data['inviteCode'] ?? '') as String;

      if (!mounted) return;
      setState(() {
        _inviteCode = code;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _copyCode() async {
    if (_inviteCode == null) return;
    await Clipboard.setData(ClipboardData(text: _inviteCode!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryBlue),
          onPressed: () => context.go('/bill/$_billId/summary'),
        ),
        title: const Text(
          'Invite',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          _buildHero(),
          const SizedBox(height: 24),
          const Text(
            'Invite Friends',
            style: TextStyle(
              color: textDark,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Share this code with your friends to split the bill together.',
            style: TextStyle(color: textGray, fontSize: 16, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildCodeCard(),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _buildErrorWidget(_error!),
          ],
          const SizedBox(height: 24),
          _buildDivider(),
          const SizedBox(height: 24),
          _buildBackButton(),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: const BoxDecoration(
            color: Color(0xFFE4E6FF),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.group_add, color: primaryBlue, size: 72),
        ),
        Positioned(
          right: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withValues(alpha: 0.24),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.share, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeCard() {
    return Container(
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: inputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Text(
              _inviteCode ?? '',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                color: primaryBlue,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _copyCode,
              icon: const Icon(Icons.content_copy, size: 18),
              label: const Text(
                'Copy Code',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(Object error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: errorRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error.toString(),
              style: const TextStyle(color: errorRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: inputBorder)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('or', style: TextStyle(color: textGray, fontSize: 14)),
        ),
        Expanded(child: Container(height: 1, color: inputBorder)),
      ],
    );
  }

  Widget _buildBackButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        onPressed: () => context.go('/bill/$_billId/summary'),
        icon: const Icon(Icons.arrow_back, size: 20),
        label: const Text(
          'Back to Summary',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: errorRed, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Unable to load invite code',
              style: TextStyle(
                color: textDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error.toString(),
              style: const TextStyle(color: textGray, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loadCode,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
