// Product documentation of Nocchi, built with VitePress and published to GitHub Pages by
// .github/workflows/pages.yml. English at the root, Simplified Chinese under /zh/.
// Screenshots in public/screenshots are rendered from the app by .github/workflows/screenshots.yml.

import { defineConfig } from 'vitepress'

const repo = 'https://github.com/Chaosnap/Nocchi'
const base = '/Nocchi/'

const englishGuide = [
  {
    text: 'Getting started',
    items: [
      { text: 'Install', link: '/guide/getting-started' },
      { text: 'Gallery', link: '/guide/gallery' },
    ],
  },
  {
    text: 'Using it',
    items: [
      { text: 'Taking pictures', link: '/guide/shooting' },
      { text: 'The photo booth', link: '/guide/booth' },
      { text: 'Developing, film and paper', link: '/guide/developing' },
      { text: 'The decorating desk', link: '/guide/decorating' },
      { text: 'Prints, the shelf and the album', link: '/guide/album' },
      { text: 'Shortcuts', link: '/guide/shortcuts' },
    ],
  },
  {
    text: 'Reference',
    items: [
      { text: 'Settings', link: '/guide/settings' },
      { text: 'Privacy and security', link: '/guide/privacy' },
      { text: 'Questions', link: '/guide/faq' },
      { text: 'Built in the cloud', link: '/guide/building' },
      { text: 'Changelog', link: '/guide/changelog' },
    ],
  },
]

const chineseGuide = [
  {
    text: '入门',
    items: [
      { text: '安装', link: '/zh/guide/getting-started' },
      { text: '截图', link: '/zh/guide/gallery' },
    ],
  },
  {
    text: '使用',
    items: [
      { text: '拍照', link: '/zh/guide/shooting' },
      { text: '大头贴机', link: '/zh/guide/booth' },
      { text: '显影、胶卷与相纸', link: '/zh/guide/developing' },
      { text: '装饰台', link: '/zh/guide/decorating' },
      { text: '相片、暂存架与相册', link: '/zh/guide/album' },
      { text: '快捷键', link: '/zh/guide/shortcuts' },
    ],
  },
  {
    text: '参考',
    items: [
      { text: '设置', link: '/zh/guide/settings' },
      { text: '隐私与安全', link: '/zh/guide/privacy' },
      { text: '常见问题', link: '/zh/guide/faq' },
      { text: '云端构建', link: '/zh/guide/building' },
      { text: '更新日志', link: '/zh/guide/changelog' },
    ],
  },
]

export default defineConfig({
  title: 'Nocchi',
  description: 'The notch is a darkroom: a retro instant camera that prints out of your MacBook’s notch.',
  base,
  cleanUrls: true,
  lastUpdated: true,

  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: `${base}images/icon.svg` }],
    ['meta', { name: 'theme-color', content: '#2a1c14' }],
    ['meta', { property: 'og:image', content: `https://chaosnap.github.io${base}screenshots/desk.jpg` }],
    ['link', { rel: 'preconnect', href: 'https://fonts.googleapis.com' }],
    ['link', { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' }],
    [
      'link',
      {
        rel: 'stylesheet',
        href: 'https://fonts.googleapis.com/css2?family=Courier+Prime&family=EB+Garamond:ital,wght@0,400;0,600;1,400&family=Playfair+Display:ital,wght@0,500;0,600;1,500&display=swap',
      },
    ],
  ],

  themeConfig: {
    logo: '/images/icon.svg',
    search: { provider: 'local' },
    socialLinks: [{ icon: 'github', link: repo }],
    footer: {
      message: 'Released under the GNU AGPL-3.0. Screenshots are rendered from the app on GitHub Actions.',
      copyright: '© 2026 Chaosnap',
    },
  },

  locales: {
    root: {
      label: 'English',
      lang: 'en-US',
      themeConfig: {
        nav: [
          { text: 'Guide', link: '/guide/getting-started' },
          { text: 'Gallery', link: '/guide/gallery' },
          { text: 'Changelog', link: '/guide/changelog' },
          { text: 'Download', link: `${repo}/releases/latest` },
        ],
        sidebar: { '/guide/': englishGuide },
        editLink: { pattern: `${repo}/edit/main/website/:path`, text: 'Edit this page on GitHub' },
      },
    },
    zh: {
      label: '简体中文',
      lang: 'zh-CN',
      link: '/zh/',
      title: 'Nocchi · 刘海冲印店',
      description: '把 MacBook 的刘海变成一台复古相机的出片口：照片从刘海里吐出来，像真相纸一样慢慢显影。',
      themeConfig: {
        nav: [
          { text: '指南', link: '/zh/guide/getting-started' },
          { text: '截图', link: '/zh/guide/gallery' },
          { text: '更新日志', link: '/zh/guide/changelog' },
          { text: '下载', link: `${repo}/releases/latest` },
        ],
        sidebar: { '/zh/guide/': chineseGuide },
        outline: { label: '本页目录' },
        lastUpdated: { text: '最后更新于' },
        editLink: { pattern: `${repo}/edit/main/website/:path`, text: '在 GitHub 上编辑此页' },
        docFooter: { prev: '上一页', next: '下一页' },
        returnToTopLabel: '回到顶部',
        sidebarMenuLabel: '目录',
        darkModeSwitchLabel: '外观',
        lightModeSwitchTitle: '切换到浅色模式',
        darkModeSwitchTitle: '切换到深色模式',
        langMenuLabel: '切换语言',
        footer: {
          message: '以 GNU AGPL-3.0 许可证发布。截图由 GitHub Actions 从 App 渲染。',
          copyright: '© 2026 Chaosnap',
        },
      },
    },
  },
})
