import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/core/utils/titra_id_utils.dart';
import 'package:titra/core/widgets/app_button.dart';
import 'package:titra/features/auth/data/user_repository.dart';
import 'package:titra/features/home/presentation/view_models/add_person_view_model.dart';

/// Screen to add a person by Titra ID only. Search happens only with Titra ID.
class AddPersonScreen extends StatelessWidget {
  const AddPersonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AddPersonViewModel(),
      child: const _AddPersonView(),
    );
  }
}

class _AddPersonView extends StatelessWidget {
  const _AddPersonView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AddPersonViewModel>();

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
          'Add Person',
          style: TextStyle(
            color: AppColors.black,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. TOP ILLUSTRATIVE ICON/GRAPHIC AREA
              Center(
                child: Container(
                  height: 90,
                  width: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_person_outlined,
                    size: 42,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Headers
              Text(
                'Search by Titra ID only',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.onBackgroundLight,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Enter the 10-digit Titra ID of the person you want to add. Searching by name or phone number is not available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onBackgroundLight.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 2. INPUT CARD SURFACE
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: vm.idController,
                      focusNode: vm.idFocusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                        _TitraIdInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        hintText: 'e.g. 884-902-1102',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                        prefixIcon: Icon(
                          Icons.lock_person_outlined,
                          size: 22,
                          color: AppColors.primary.withValues(alpha: 0.7),
                        ),
                        suffixIcon: vm.isValidId
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green,
                                size: 22,
                              )
                            : const SizedBox.shrink(),
                        filled: true,
                        fillColor: AppColors.backgroundLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.outlineLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.outlineLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        fontFamily: 'monospace',
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: vm.onIdChanged,
                      onSubmitted: (_) => _onSearch(context, vm),
                    ),

                    // Animated Error section inside the card
                    vm.searchError != null
                        ? Column(
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                vm.searchError!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ) : const SizedBox.shrink(),

                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action button wrapper
              AppButton(
                label: 'Search by ID',
                loading: vm.searching,
                onPressed: vm.isValidId && !vm.searching
                    ? () => _onSearch(context, vm)
                    : null,
                icon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              // 4. CLEANER TIPS CONTAINER
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Want others to find you? Go to your Profile screen to copy and share your unique 10-digit Titra ID.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.onBackgroundLight.withValues(
                            alpha: 0.75,
                          ),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSearch(BuildContext context, AddPersonViewModel vm) {
    return vm.search(
      context,
      repo: context.read<UserRepository>(),
      session: context.read<SessionController>(),
    );
  }
}

/// Formats 10 digits as XXX-XXX-XXXX with intelligent cursor positioning
class _TitraIdInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 10) return oldValue;

    final formatted = formatTitraIdDashed(text);

    // Dynamically calculate cursor offset so typing/deleting from the middle works properly
    int selectionOffset = formatted.length;
    if (newValue.selection.end < newValue.text.length) {
      int count = 0;
      for (int i = 0; i < newValue.selection.end; i++) {
        if (RegExp(r'[0-9]').hasMatch(newValue.text[i])) {
          count++;
        }
      }
      int formattedCount = 0;
      for (int i = 0; i < formatted.length; i++) {
        if (RegExp(r'[0-9]').hasMatch(formatted[i])) {
          formattedCount++;
        }
        if (formattedCount == count) {
          selectionOffset = i + 1;
          break;
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionOffset),
    );
  }
}
