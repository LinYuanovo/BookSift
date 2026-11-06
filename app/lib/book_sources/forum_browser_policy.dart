import 'dart:convert';

bool isForumNavigationAllowed(Uri base, Uri target) =>
    target.scheme == 'https' &&
    target.origin == base.origin &&
    target.userInfo.isEmpty;

String forumLoginScript(Uri base, String username, String password) =>
    '''
(() => {
  const expectedOrigin = ${jsonEncode(base.origin)};
  if (location.origin !== expectedOrigin) return 'blocked';
  const documents = [document];
  for (const frame of document.querySelectorAll('iframe')) {
    try { if (frame.contentWindow.location.origin === expectedOrigin) documents.push(frame.contentDocument); } catch (_) {}
  }
  for (const current of documents) {
    if (current.querySelector('a[href*="action=logout"], #um .vwmy')) return 'authenticated';
    const secret = current.querySelector('input[type="password"]');
    const form = secret && secret.form;
    if (!form) continue;
    const action = new URL(form.action || current.URL, current.URL);
    if (action.origin !== expectedOrigin || action.searchParams.get('action') !== 'login') continue;
    const account = form.querySelector('input[name="username"], input[name="email"]');
    if (!account) continue;
    const fill = (field, value) => { field.value = value; field.dispatchEvent(new Event('input', {bubbles: true})); field.dispatchEvent(new Event('change', {bubbles: true})); };
    fill(account, ${jsonEncode(username)});
    fill(secret, ${jsonEncode(password)});
    const mode = form.querySelector('select[name="loginfield"]');
    if (mode) fill(mode, ${jsonEncode(username.contains('@') ? 'email' : 'username')});
    const captcha = form.querySelector('input[name="seccodeverify"], input[name="secanswer"], iframe[src*="captcha"], .g-recaptcha');
    if (captcha) { if (captcha.focus) captcha.focus(); return 'captcha'; }
    const submit = form.querySelector('button[name="loginsubmit"], input[name="loginsubmit"], button[type="submit"], input[type="submit"]');
    if (submit) { submit.click(); return 'submitted'; }
    return 'filled';
  }
  return 'no-form';
})()
''';

String forumDocumentScript(Uri base) =>
    '''
(() => {
  const expectedOrigin = ${jsonEncode(base.origin)};
  if (location.origin !== expectedOrigin) return '';
  let source = document.documentElement.outerHTML;
  for (const frame of document.querySelectorAll('iframe')) {
    try { if (frame.contentWindow.location.origin === expectedOrigin) source += frame.contentDocument.documentElement.outerHTML; } catch (_) {}
  }
  return source;
})()
''';
