# 尚香书苑与搜书吧接入

## 使用

搜索页右上角「书源搜索与下载」，或书籍详情页「搜索下载本书」，进入独立的书源搜索页。

1. 选择书源，打开「书源设置」。
2. 从导航页解析最新地址，或填写已确认的 HTTPS 论坛首页地址。
3. 需要账号时，在浏览器登录并将 Cookie 保存到该书源。Cookie 只进入系统安全存储，并绑定论坛 origin；换域名必须重新登录。
4. 搜索书名，点击结果选择附件；下载完成后通过系统文件对话框选择保存位置。Android 使用系统文档提供器，Windows 使用保存文件对话框。
5. 可取消下载或取消保存。临时文件会删除，不留下半成品。单个附件上限 64 MiB；更大文件、站外下载、购买/回复/验证码等步骤使用原帖浏览器入口。

## 现场调查（2026-11-06）

- `https://sxsy.pw/` 导航页的 `#enterButton` 指向 `https://sxsy33.com`，访问后跳转登录页。没有使用用户账号，未验证登录后的真实搜索/下载。
- `https://soushu2025.com/` 在当前网络出现证书信任失败；HTTP 导航跳到 `tianyuan999.com:6677` 的 404 页面，无法取得可确认的 HTTPS 论坛最新地址。应用不会忽略 TLS 错误，允许用户提供正常地址。
- 两站参考实现均走 Discuz `search.php?mod=forum`，先 GET 获取 `formhash` 再 POST `srchtxt`，附件走 `forum.php?mod=attachment` / `attachment.php`；未找到可直接使用的公开官方 API。
- 搜书吧历史页面使用 GBK，编码由响应头/meta 判断，搜索表单按同一字符集编码。

## 参考与实现边界

- [Aur5411/SXSY](https://github.com/Aur5411/SXSY)：Android Discuz 客户端。
- [Aur5411/soushu](https://github.com/Aur5411/soushu)：搜书吧 WebView 客户端。
- [Foolllll-J/astrbot_plugin_soushuba](https://github.com/Foolllll-J/astrbot_plugin_soushuba)：参考 `core/search_service.py`、`url_resolver.py`、`download_service.py` 的请求协议和选择器；本项目独立实现 Dart 适配器，没有复制其业务代码。

不继承参考项目关闭 TLS 校验、自动支付或执行混淆页面脚本的做法。搜索请求使用当前确认的 origin，重定向到其他 origin 时不携带或转发凭证，报错后交由用户确认最新地址。付费/回复附件不自动操作。

自动测试覆盖导航链接筛选、结果/附件去重、GBK 表单、Cookie origin 绑定、登录页报错、附件字节与伪 HTML 响应、320px 页面布局。以上属于受控模拟响应测试，不代表现场登录态下载成功。
