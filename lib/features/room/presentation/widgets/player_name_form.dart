import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/profile/player_name_cubit.dart';

class PlayerNameForm extends StatefulWidget {
  const PlayerNameForm({required this.onSaved, this.onCancel, super.key});

  final VoidCallback onSaved;
  final VoidCallback? onCancel;

  @override
  State<PlayerNameForm> createState() => _PlayerNameFormState();
}

class _PlayerNameFormState extends State<PlayerNameForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: context.read<PlayerNameCubit>().state ?? '',
  );

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (context.read<PlayerNameCubit>().saveName(_name.text)) {
      FocusScope.of(context).unfocus();
      widget.onSaved();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        TextFormField(
          key: const ValueKey('player-name-input'),
          controller: _name,
          textAlign: TextAlign.center,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.nickname],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) => PlayerNameCubit.validate(value ?? ''),
          onFieldSubmitted: (_) => _save(),
          decoration: const InputDecoration(
            counterText: '',
            hintText: 'Oyuncu Adın',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('save-player-name'),
          onPressed: _save,
          label: const Text('Devam'),
        ),
        if (widget.onCancel != null)
          TextButton(onPressed: widget.onCancel, child: const Text('Vazgeç')),
      ],
    ),
  );
}
