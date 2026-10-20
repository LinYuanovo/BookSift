import { readAppVersion, renderVersioned } from '../../tools/render_docs.js'
import { defineConfig } from 'vitepress'

const appVersion = readAppVersion()

// 仓库地址（owner/repo）：与 app/lib/core/update/update_controller.dart 的
// kUpdateGithubOwner/kUpdateGithubRepo 保持一致，改一处必须同步改另一处。
const owner = 'LinYuanovo'
const repo = 'BookSift'
const repoUrl = `https://github.com/${owner}/${repo}`

// https://vitepress.dev/reference/site-config
export default defineConfig({
  // GitHub Pages 部署在仓库子路径下，必须与仓库名一致
  base: '/BookSift/',
  lang: 'zh-CN',
  title: '扫书汇',
  description: '贴吧「扫书帖」离线书单浏览器 —— 使用文档与图文教程',
  cleanUrls: true,
  lastUpdated: true,

  // 文档正文仍保持普通 Markdown 语法；仅在构建时从 pubspec.yaml 注入版本号。
  markdown: {
    preConfig(md) {
      const render = md.render.bind(md)
      md.render = (source, env) =>
        render(renderVersioned(source, appVersion), env)
    },
  },

  head: [
    ['link', { rel: 'icon', type: 'image/png', href: '/BookSift/logo.png' }],
    ['meta', { name: 'theme-color', content: '#D97757' }],
  ],

  themeConfig: {
    logo: '/logo.png',
    siteTitle: '扫书汇',

    nav: [
      { text: '首页', link: '/' },
      { text: '使用指南', link: '/guide/getting-started', activeMatch: '/guide/' },
      { text: '常见问题', link: '/faq' },
      { text: '参与开发', link: '/development/build', activeMatch: '/development/' },
      {
        text: `v${appVersion}`,
        items: [
          { text: '下载最新版', link: `${repoUrl}/releases` },
          { text: '问题反馈', link: `${repoUrl}/issues` },
        ],
      },
    ],

    sidebar: {
      '/guide/': [
        {
          text: '快速上手',
          items: [
            { text: '下载与安装', link: '/guide/getting-started' },
            { text: '首页、榜单与随机书荒', link: '/guide/browse' },
            { text: '搜索与五维筛选', link: '/guide/search' },
            { text: '书聚合页与帖子阅读', link: '/guide/read' },
          ],
        },
        {
          text: '进阶',
          items: [
            { text: '采集中心', link: '/guide/collect' },
            { text: '分享与导出', link: '/guide/share' },
            { text: '主题、字体与宽屏', link: '/guide/personalize' },
            { text: 'App 更新与数据包', link: '/guide/update' },
          ],
        },
        {
          text: '说明',
          items: [{ text: '数据来源与合规', link: '/guide/data' }],
        },
      ],
      '/development/': [
        {
          text: '参与开发',
          items: [
            { text: '从源码构建', link: '/development/build' },
            { text: 'Headless CLI 与 API', link: '/development/headless' },
          ],
        },
      ],
    },

    socialLinks: [{ icon: 'github', link: repoUrl }],

    search: {
      provider: 'local',
    },

    editLink: {
      pattern: `${repoUrl}/edit/main/website/:path`,
      text: '在 GitHub 上编辑此页',
    },

    footer: {
      message: '仅供个人学习研究使用，请勿用于商业用途',
      copyright: '书目内容版权归原发帖人与百度所有',
    },

    // 中文界面文案
    outline: { label: '本页目录' },
    docFooter: { prev: '上一页', next: '下一页' },
    lastUpdatedText: '最后更新',
    returnToTopLabel: '回到顶部',
    sidebarMenuLabel: '菜单',
    darkModeSwitchLabel: '外观',
    lightModeSwitchTitle: '切换到浅色模式',
    darkModeSwitchTitle: '切换到深色模式',
    notFound: {
      title: '页面不存在',
      quote: '你要找的页面可能已被移动或删除。',
      linkLabel: '返回首页',
      linkText: '返回首页',
    },
  },
})
