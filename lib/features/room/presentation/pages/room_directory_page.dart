import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/monitoring/error_reporter.dart';
import '../../../../core/profile/player_name_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../../data/firebase_room_service.dart';
import '../../domain/entities/game_room.dart';
import '../../domain/entities/room_listing.dart';
import '../widgets/room_code_input.dart';

class RoomDirectoryPage extends StatefulWidget {
  const RoomDirectoryPage({super.key});

  @override
  State<RoomDirectoryPage> createState() => _RoomDirectoryPageState();
}

class _RoomDirectoryPageState extends State<RoomDirectoryPage>
    with WidgetsBindingObserver {
  List<RoomListing> _rooms = const [];
  String? _error;
  bool _loading = true;
  bool _joining = false;
  String? _joiningId;
  late final FirebaseRoomService _service;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = context.read<FirebaseRoomService>();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading && !_joining) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rooms = await _service.listRooms();
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _loading = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, operation: 'room_directory.list');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _message(error);
        });
      }
    }
  }

  Future<void> _join(RoomListing listing) async {
    if (_joining || listing.isFull) return;
    setState(() {
      _joining = true;
      _joiningId = listing.isPrivate ? null : listing.id;
      _error = null;
    });
    try {
      final name = context.read<PlayerNameCubit>().state!;
      final room = listing.isPrivate
          ? await showDialog<GameRoom>(
              context: context,
              barrierDismissible: true,
              builder: (_) => _PrivateRoomDialog(
                service: _service,
                listing: listing,
                displayName: name,
              ),
            )
          : await _service.joinListedRoom(directoryId: listing.id, displayName: name);
      if (room == null) return;
      if (!mounted) {
        await _service.leaveRoom(room.id);
        return;
      }
      context.go('/room/${room.id}', extra: room);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, operation: 'room_directory.join');
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) {
        setState(() {
          _joining = false;
          _joiningId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => NightStudioScaffold(
    appBar: AppBar(
      title: const Text('Odalar'),
      actions: [
        IconButton(
          tooltip: 'Listeyi yenile',
          onPressed: _loading || _joining ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Oda oluştur',
          onPressed: _joining ? null : () => context.push('/create'),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: RefreshIndicator(
            onRefresh: () async {
              if (!_loading && !_joining) await _load();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                const Text(
                  'Sağ üstteki + ile oda oluştur veya açık bir odaya doğrudan katıl. Kilitli odalar için oda kodunu gir.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 24),
                if (_loading) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _loading || _joining ? null : _load,
                    child: const Text('Tekrar dene'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!_loading && _error == null && _rooms.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 200),
                    child: Column(
                      children: [
                        Icon(
                          Icons.meeting_room_outlined,
                          size: 56,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(height: 16),
                        Text('Henüz açık oda yok', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                for (final room in _rooms) ...[
                  _RoomTile(
                    room: room,
                    busy: _joiningId == room.id,
                    enabled: !_joining,
                    onJoin: () => _join(room),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.busy,
    required this.enabled,
    required this.onJoin,
  });
  final RoomListing room;
  final bool busy;
  final bool enabled;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                room.isPrivate ? Icons.lock_outline_rounded : Icons.public_rounded,
                color: AppColors.cyan,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(room.name, style: Theme.of(context).textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(
                '${room.isPrivate ? 'Özel' : 'Açık'} oda · ${room.playerCount}/${room.capacity} oyuncu',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              FilledButton.icon(
                key: ValueKey('join-room-${room.id}'),
                onPressed: enabled && !room.isFull ? onJoin : null,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        room.isPrivate ? Icons.lock_outline_rounded : Icons.login_rounded,
                        size: 18,
                      ),
                label: Text(room.isFull ? 'Dolu' : 'Katıl'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PrivateRoomDialog extends StatefulWidget {
  const _PrivateRoomDialog({
    required this.service,
    required this.listing,
    required this.displayName,
  });
  final FirebaseRoomService service;
  final RoomListing listing;
  final String displayName;

  @override
  State<_PrivateRoomDialog> createState() => _PrivateRoomDialogState();
}

class _PrivateRoomDialogState extends State<_PrivateRoomDialog> {
  String _code = '';
  String? _error;
  bool _busy = false;
  bool get _canJoin => _code.replaceAll('-', '').length == 6 && !_busy;

  Future<void> _submit() async {
    if (!_canJoin) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final room = await widget.service.joinListedRoom(
        directoryId: widget.listing.id,
        displayName: widget.displayName,
        roomCode: _code,
      );
      if (!mounted) {
        await widget.service.leaveRoom(room.id);
        return;
      }
      Navigator.of(context).pop(room);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, operation: 'room_directory.private_join');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _message(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                ignoring: _busy,
                child: RoomCodeInput(
                  onChanged: (code) => setState(() {
                    _code = code;
                    _error = null;
                  }),
                  onSubmitted: _submit,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed: _canJoin ? _submit : null,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login_rounded),
          label: const Text('Odaya Gir'),
        ),
      ],
    ),
  );
}

String _message(Object error) => error is RoomServiceException
    ? error.message
    : 'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.';
