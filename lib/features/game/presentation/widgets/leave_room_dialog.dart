import 'package:flutter/material.dart';

import '../../../../core/monitoring/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';

class LeaveRoomDialog extends StatefulWidget {
  const LeaveRoomDialog({
    required this.isHost,
    required this.onLeave,
    super.key,
  });

  final bool isHost;
  final Future<String?> Function() onLeave;

  @override
  State<LeaveRoomDialog> createState() => _LeaveRoomDialogState();
}

class _LeaveRoomDialogState extends State<LeaveRoomDialog> {
  final _status = ValueNotifier<({bool leaving, String? error})>((
    leaving: false,
    error: null,
  ));
  bool get _isLeaving => _status.value.leaving;
  String? get _error => _status.value.error;

  @override
  void dispose() {
    _status.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_isLeaving) return;
    _status.value = (leaving: true, error: null);
    String? error;
    try {
      error = await widget.onLeave();
    } catch (exception, stackTrace) {
      ErrorReporter.report(
        exception,
        stackTrace,
        operation: 'leave_dialog.submit',
      );
      error = 'Odadan çıkılamadı. Tekrar dene.';
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      _status.value = (leaving: false, error: error);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _status,
    builder: (context, status, _) => PopScope(
      canPop: !_isLeaving,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceMuted,
        title: const Text('Odadan çıkmak istediğine emin misin?'),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isHost
                  ? 'Başka oyuncu varsa oda sahipliği devredilir; son oyuncuysan oda kapanır.'
                  : 'Bu odadan ayrılacaksın.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: _isLeaving ? null : () => Navigator.pop(context, false),
            child: const Text('Kal'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isLeaving ? null : _leave,
            icon: _isLeaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : const Icon(Icons.logout_rounded),
            label: const Text('Odadan Çık'),
          ),
        ],
      ),
    ),
  );
}
