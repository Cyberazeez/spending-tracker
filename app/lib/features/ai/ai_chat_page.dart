import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/lock.dart' show clockProvider;
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_form.dart';
import '../../ui/tokens.dart';
import '../insights/providers.dart';
import '../obligations/logic.dart' show riyadhToday;
import '../transactions/providers.dart' show categoriesProvider;
import 'ai_aggregates.dart';
import 'ai_messages.dart';

/// Chat about the month's totals: dig into a category or a budget. The assistant only ever sees the same totals the
/// tips use (never merchants or messages), and the conversation lives on this screen only.
class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _Turn {
  const _Turn(this.fromUser, this.text);
  final bool fromUser;
  final String text;
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <_Turn>[];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _aggregates() {
    final ins = ref.read(insightsProvider).value;
    if (ins == null) return null;
    return buildAiAggregates(
      ins,
      ref.read(categoriesProvider).value ?? const [],
      ref.read(budgetsProvider).value ?? const [],
      riyadhToday(ref.read(clockProvider)()),
    );
  }

  /// The last turns that fit the server's limit, starting with the person's own message.
  List<Map<String, String>> _history() {
    var turns = _turns.length > 11
        ? _turns.sublist(_turns.length - 11)
        : _turns;
    while (turns.isNotEmpty && !turns.first.fromUser) {
      turns = turns.sublist(1);
    }
    return [
      for (final t in turns)
        {'role': t.fromUser ? 'user' : 'assistant', 'content': t.text},
    ];
  }

  Future<void> _ask(String question) async {
    final q = question.trim();
    if (q.isEmpty || _busy) return;
    _input.clear();
    setState(() => _turns.add(_Turn(true, q)));
    await _run();
  }

  Future<void> _run() async {
    final agg = _aggregates();
    final t = AppLocalizations.of(context);
    if (agg == null) {
      setState(() => _error = t.aiChatNoData);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    _toEnd();
    final lang = ref.read(localeProvider).languageCode;
    final out = await ref
        .read(dataRepositoryProvider)
        .aiChat(agg, _history(), lang);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (out.ok) {
        _turns.add(_Turn(false, out.reply));
      } else {
        _error = aiReasonText(t, out.reason);
      }
    });
    _toEnd();
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<String> _prompts(AppLocalizations t) {
    final agg = _aggregates();
    final cats = (agg?['categories'] as List?) ?? const [];
    final top = cats.isEmpty ? null : (cats.first as Map)['name'] as String?;
    return [
      t.aiChatPromptCut,
      t.aiChatPromptBudget,
      t.aiChatPromptLast,
      if (top != null) t.aiChatPromptCategory(top),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final card = AppTokens.card.resolveFrom(context);
    final accent = AppTokens.accent.resolveFrom(context);
    final onAccent = AppTokens.onAccent.resolveFrom(context);
    final danger = AppTokens.danger.resolveFrom(context);
    // Watched so the totals stay loaded while this screen is open (they are auto-disposed providers).
    ref
      ..watch(insightsProvider)
      ..watch(categoriesProvider)
      ..watch(budgetsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final canSend = !_busy && _input.text.trim().isNotEmpty;

    Widget bubble(_Turn turn) => Align(
      alignment: turn.fromUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(maxWidth: width * 0.85),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: turn.fromUser ? accent : card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          turn.text,
          style: TextStyle(
            color: turn.fromUser ? onAccent : text,
            fontSize: 15,
            height: 1.35,
          ),
        ),
      ),
    );

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.aiChatTitle),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  if (_turns.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
                      child: Text(
                        t.aiChatIntro,
                        style: TextStyle(color: muted, fontSize: 14),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in _prompts(t))
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(44, 44),
                            onPressed: () => _ask(p),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                p,
                                style: TextStyle(color: accent, fontSize: 14),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  for (final turn in _turns) bubble(turn),
                  if (_busy)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const CupertinoActivityIndicator(),
                          const SizedBox(width: 8),
                          Text(
                            t.aiChatThinking,
                            style: TextStyle(color: muted, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: danger, fontSize: 14),
                            ),
                          ),
                          if (_turns.isNotEmpty && _turns.last.fromUser)
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(44, 44),
                              onPressed: _run,
                              child: Text(
                                t.aiChatRetry,
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _input,
                      placeholder: t.aiChatHint,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 500,
                      textInputAction: TextInputAction.send,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _ask,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      style: TextStyle(color: text),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: t.aiChatSend,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      onPressed: canSend ? () => _ask(_input.text) : null,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: canSend ? accent : card,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.arrowUp,
                          size: 20,
                          color: canSend ? onAccent : muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
