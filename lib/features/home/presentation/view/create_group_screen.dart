import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/services/snackbar_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/core/utils/titra_id_utils.dart';
import 'package:titra/core/widgets/app_button.dart';
import 'package:titra/features/chat/presentation/view/chat_screen.dart';
import 'package:titra/features/home/data/conversations_repository.dart';
import 'package:titra/features/home/presentation/view_models/create_group_view_model.dart';

/// Create a group and open the chat.
class CreateGroupScreen extends StatelessWidget {
  const CreateGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateGroupViewModel(),
      child: const _CreateGroupView(),
    );
  }
}

class _CreateGroupView extends StatelessWidget {
  const _CreateGroupView();

  Future<void> _create(BuildContext context, CreateGroupViewModel vm) async {
    final created = await vm.create(
      repo: context.read<ConversationsRepository>(),
      snackbar: context.read<SnackbarService>(),
    );
    if (!context.mounted || created == null) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          conversationId: created.conversationId,
          contactName: created.title,
          contactId: created.conversationId,
          isGroup: true,
          participantNames: created.memberNames.isEmpty
              ? null
              : created.memberNames,
          groupMemberUserIds: created.memberUserIds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CreateGroupViewModel>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          color: AppColors.black,
        ),
        title: const Text(
          'New group',
          style: TextStyle(
            color: AppColors.black,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: vm.titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Group name',
                  hintText: 'e.g. Weekend trip',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.outlineLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Members',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onBackgroundLight.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: vm.memberIdController,
                      focusNode: vm.memberFocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                        _TitraIdInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        hintText: '10-digit Titra ID',
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.outlineLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                      onChanged: vm.onMemberIdChanged,
                      onSubmitted: (_) => vm.addMember(
                        snackbar: context.read<SnackbarService>(),
                        session: context.read<SessionController>(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Material(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      child: IconButton(
                        onPressed: () => vm.addMember(
                          snackbar: context.read<SnackbarService>(),
                          session: context.read<SessionController>(),
                        ),
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (vm.memberAccountIds.isEmpty)
                Text(
                  'Add one or more people by Titra ID. You will be included automatically.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: vm.memberAccountIds.map((id) {
                    return Chip(
                      label: Text(formatTitraIdWithPrefix(id)),
                      onDeleted: () => vm.removeMember(id),
                    );
                  }).toList(),
                ),
              const Spacer(),
              AppButton(
                label: 'Create group',
                loading: vm.submitting,
                onPressed: vm.submitting ? null : () => _create(context, vm),
                icon: const Icon(
                  Icons.group_add_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitraIdInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 10) return oldValue;
    final formatted = formatTitraIdDashed(text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
