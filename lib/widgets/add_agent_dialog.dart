import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/agent_cli.dart';
import '../services/custom_cli_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Dialog for adding a custom agent CLI to the local environments list.
///
/// The user provides a display name and a binary (bare command name resolved
/// via `which`, or an absolute path picked/typed directly). The new agent is
/// persisted via [CustomCliService] and joins the normal detection flow.
class AddAgentDialog extends StatefulWidget {
  /// Called with the newly created agent definition; the caller should
  /// trigger a rescan so the agent gets detected.
  final ValueChanged<AgentCli> onAdded;

  const AddAgentDialog({super.key, required this.onAdded});

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<AgentCli> onAdded,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.black60,
      builder: (_) => AddAgentDialog(onAdded: onAdded),
    );
  }

  @override
  State<AddAgentDialog> createState() => _AddAgentDialogState();
}

class _AddAgentDialogState extends State<AddAgentDialog> {
  final _nameCtl = TextEditingController();
  final _binaryCtl = TextEditingController();
  final _versionFlagCtl = TextEditingController(text: '--version');

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtl.dispose();
    _binaryCtl.dispose();
    _versionFlagCtl.dispose();
    super.dispose();
  }

  Future<void> _pickBinary() async {
    final result = await FilePicker.pickFiles();
    final path = result?.files.single.path;
    if (path != null && path.isNotEmpty) {
      setState(() {
        _binaryCtl.text = path;
        // Auto-fill name from the binary file name if still empty.
        if (_nameCtl.text.trim().isEmpty) {
          final base = path.split('/').last;
          _nameCtl.text = base;
        }
      });
    }
  }

  Future<void> _onAdd() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final name = _nameCtl.text.trim();
    final binary = _binaryCtl.text.trim();
    if (name.isEmpty || binary.isEmpty) {
      setState(() => _error = l10n.nameAndBinaryRequired);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final cli = await CustomCliService.add(
      displayName: name,
      binary: binary,
      versionFlag: _versionFlagCtl.text,
    );

    if (!mounted) return;
    if (cli == null) {
      setState(() {
        _saving = false;
        _error = l10n.agentAlreadyExists;
      });
      return;
    }

    Navigator.of(context).pop();
    widget.onAdded(cli);
  }

  InputDecoration _input({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodySmall,
        filled: true,
        fillColor: AppColors.bg800,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border800)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border800)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accent400)),
      );

  Widget _field(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: 6),
          child,
        ],
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: AppColors.bg900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border700),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(children: [
                  const Icon(Icons.add_circle_outline,
                      size: 18, color: AppColors.accent400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.addCustomAgent,
                        style: AppTypography.cardTitle),
                  ),
                  IconButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.text400,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ]),
              ),
              const Divider(height: 1, color: AppColors.border700),

              // ── Body ──
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(
                      l10n.displayNameLabel,
                      TextField(
                        controller: _nameCtl,
                        enabled: !_saving,
                        style: AppTypography.body,
                        decoration:
                            _input(hint: l10n.displayNameHint),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _field(
                      l10n.binaryLabel,
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _binaryCtl,
                            enabled: !_saving,
                            style: AppTypography.body,
                            decoration: _input(
                                hint: l10n.binaryHint),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _saving ? null : _pickBinary,
                          tooltip: l10n.browse,
                          icon: const Icon(Icons.folder_open,
                              size: 18, color: AppColors.accent400),
                          style: IconButton.styleFrom(
                            side: const BorderSide(
                                color: AppColors.border700),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    _field(
                      l10n.versionFlagLabel,
                      TextField(
                        controller: _versionFlagCtl,
                        enabled: !_saving,
                        style: AppTypography.body,
                        decoration: _input(hint: '--version'),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.red400)),
                    ],
                  ],
                ),
              ),

              // ── Footer ──
              const Divider(height: 1, color: AppColors.border700),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.text400),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _saving ? null : _onAdd,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent400,
                      foregroundColor: AppColors.bg950,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.bg950))
                        : Text(l10n.addAgentButton),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
