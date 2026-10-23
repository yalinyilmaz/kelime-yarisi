import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/room_listing.dart';
import '../cubit/room_directory_cubit.dart';
import 'room_code_input.dart';

class PrivateRoomDialog extends StatefulWidget {
  const PrivateRoomDialog({
    required this.listing,
    required this.displayName,
    super.key,
  });
  final RoomListing listing;
  final String displayName;

  @override
  State<PrivateRoomDialog> createState() => _PrivateRoomDialogState();
}

class _PrivateRoomDialogState extends State<PrivateRoomDialog> {
  final _code = ValueNotifier('');
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cubit = context.read<RoomDirectoryCubit>();
    if (_code.value.replaceAll('-', '').length != 6 || cubit.state.submitting) {
      return;
    }
    final room = await cubit.join(
      widget.listing,
      widget.displayName,
      roomCode: _code.value,
    );
    if (room == null) return;
    if (!mounted) {
      await cubit.releaseJoinedRoom(room);
      return;
    }
    Navigator.of(context).pop(room);
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<RoomDirectoryCubit, RoomDirectoryState>(
        buildWhen: (a, b) => a.submitting != b.submitting || a.error != b.error,
        builder: (context, state) => PopScope(
          canPop: !state.submitting,
          child: AlertDialog(
            backgroundColor: AppColors.surfaceMuted,
            title: Row(
              children: [
                Expanded(child: Text(widget.listing.name)),
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Bu oda özel. Katılmak için oda kodunu gir.'),
                    const SizedBox(height: 20),
                    IgnorePointer(
                      ignoring: state.submitting,
                      child: RoomCodeInput(
                        onChanged: (code) {
                          _code.value = code;
                          context.read<RoomDirectoryCubit>().clearError();
                        },
                        onSubmitted: _submit,
                      ),
                    ),
                    if (state.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              ValueListenableBuilder(
                valueListenable: _code,
                builder: (context, code, _) => FilledButton.icon(
                  onPressed:
                      code.replaceAll('-', '').length == 6 && !state.submitting
                      ? _submit
                      : null,
                  icon: state.submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded),
                  label: const Text('Odaya Gir'),
                ),
              ),
            ],
          ),
        ),
      );
}
