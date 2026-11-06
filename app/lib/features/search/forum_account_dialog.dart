import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../book_sources/forum_source.dart';
import '../../book_sources/source_settings.dart';
import '../../core/nav/overlay_motion.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_text_field.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'forum_browser_page.dart';

Future<String?> openForumLogin(
  BuildContext context,
  WidgetRef ref,
  ForumSource source,
  ForumSourceSettings settings,
) => ref.read(forumBrowserProvider)(
  context,
  ForumBrowserRequest(
    source: source,
    settings: settings,
    login: true,
    url: settings.base!.resolve('member.php?mod=logging&action=login'),
  ),
);

Future<void> showForumAccountDialog(
  BuildContext context,
  WidgetRef ref,
  ForumSource source,
) async {
  ForumSourceSettings settings = const ForumSourceSettings();
  try {
    settings = await ref.read(forumSettingsProvider(source).future);
  } catch (_) {}
  if (!context.mounted) return;
  final address = TextEditingController(text: settings.base?.toString() ?? '');
  final username = TextEditingController(text: settings.username);
  final secret = TextEditingController(text: settings.password);
  final cookie = TextEditingController(text: settings.cookie);
  bool busy = false;
  String? message;
  final route = DialogRoute<void>(
    context: context,
    animationStyle: dialogAnimationStyle(context),
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, update) {
        final spacing = AppSpacing.of(dialogContext);
        final typography = AppTypography.of(dialogContext);
        Future<void> save(bool login) async {
          if (busy) return;
          update(() {
            busy = true;
            message = null;
          });
          try {
            final Uri base = validateForumBase(address.text);
            address.text = base.toString();
            if (settings.base != null &&
                base.origin != settings.base!.origin &&
                ((cookie.text.isNotEmpty && cookie.text == settings.cookie) ||
                    (secret.text.isNotEmpty &&
                        secret.text == settings.password))) {
              throw const SourceFailure('论坛地址已改变，请重新填写该地址的账号密码或 Cookie');
            }
            await saveForumSettings(
              ref,
              source,
              base,
              cookie.text,
              username: username.text,
              password: secret.text,
            );
            if (!dialogContext.mounted) return;
            final bool hasCredentials =
                username.text.trim().isNotEmpty && secret.text.isNotEmpty;
            if (!login && !hasCredentials) {
              Navigator.pop(dialogContext);
              return;
            }
            final current = ForumSourceSettings(
              base: base,
              cookie: cookie.text,
              username: username.text,
              password: secret.text,
            );
            final client = ref.read(forumClientProvider);
            if (current.cookie.isNotEmpty &&
                await client.checkSession(base, current.cookie)) {
              await saveForumSessionCookie(
                ref,
                source,
                current,
                client.sessionCookie(base),
              );
              if (dialogContext.mounted) {
                if (login) {
                  update(() => message = '登录态有效，已复用现有 Cookie');
                } else {
                  Navigator.pop(dialogContext);
                }
              }
            } else {
              if (!dialogContext.mounted) return;
              final String? result = await openForumLogin(
                dialogContext,
                ref,
                source,
                current,
              );
              if (result != null && dialogContext.mounted) {
                cookie.text = result;
                await saveForumSessionCookie(ref, source, current, result);
                if (dialogContext.mounted) {
                  if (login) {
                    update(() => message = '登录成功，Cookie 已保存在本机');
                  } else {
                    Navigator.pop(dialogContext);
                  }
                }
              }
            }
          } catch (error) {
            if (dialogContext.mounted) {
              update(
                () => message = error is SourceFailure
                    ? error.message
                    : '连接或保存失败，请检查网络后重试',
              );
            }
          } finally {
            if (dialogContext.mounted) update(() => busy = false);
          }
        }

        return AppDialog(
          title: '${source.label}设置',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '填写账号密码，或仅填写 Cookie。有效登录态会直接复用；失效后在应用内登录，验证码由你填写。凭证加密保存在本机。',
                style: typography.secondary,
              ),
              SizedBox(height: spacing.space4),
              AppTextField(
                controller: address,
                label: '论坛最新地址（HTTPS）',
                helper: '可直接填写域名，未填写协议时自动补全 https://',
                keyboardType: TextInputType.url,
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        update(() {
                          busy = true;
                          message = null;
                        });
                        try {
                          final Uri base = await ref
                              .read(forumClientProvider)
                              .resolve(source);
                          if (!dialogContext.mounted) return;
                          if (address.text != base.toString()) {
                            cookie.clear();
                            username.clear();
                            secret.clear();
                          }
                          address.text = base.toString();
                        } catch (error) {
                          if (dialogContext.mounted) {
                            update(
                              () => message = error is SourceFailure
                                  ? error.message
                                  : '暂时无法获取最新地址',
                            );
                          }
                        } finally {
                          if (dialogContext.mounted) update(() => busy = false);
                        }
                      },
                child: Text(busy ? '处理中…' : '从导航页获取'),
              ),
              SizedBox(height: spacing.space3),
              AppTextField(
                controller: username,
                label: '账号或邮箱',
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: spacing.space3),
              AppTextField(controller: secret, label: '密码', obscureText: true),
              SizedBox(height: spacing.space3),
              AppTextField(
                controller: cookie,
                label: '登录 Cookie（可留空）',
                obscureText: true,
                helper: '只填 Cookie 也可使用；清空账号、密码和 Cookie 后保存可移除登录资料',
              ),
              if (message != null)
                Padding(
                  padding: EdgeInsets.only(top: spacing.space3),
                  child: Text(message!, style: typography.secondary),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: busy ? null : () => save(true),
              child: const Text('验证登录'),
            ),
            FilledButton(
              onPressed: busy ? null : () => save(false),
              child: const Text('保存'),
            ),
          ],
        );
      },
    ),
  );
  await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
  for (final controller in <TextEditingController>[
    address,
    username,
    secret,
    cookie,
  ]) {
    controller.dispose();
  }
}
