// Firefox 用户首选项文件
// 重要：以下设置让Firefox使用默认首页（新建标签页或恢复会话）

// 1. 启动行为：3 = 恢复上次会话，1 = 打开新建标签页
user_pref("browser.startup.page", 3);

// 2. 禁用所有可能强制打开特定页面的向导和欢迎页
user_pref("startup.homepage_welcome_url", "");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("browser.shell.checkDefaultBrowser", false);

// 3. 允许从 addons.mozilla.org 安装扩展（关键）
user_pref("xpinstall.signatures.required", false);
user_pref("extensions.experiments.enabled", true);

// 4. 优化无头/远程环境性能
user_pref("gfx.webrender.all", false);