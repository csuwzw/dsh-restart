<div align="center">
  <img src="icon.svg" alt="dsh-restart — DeepSeek Harness 一键重启插件" width="120">

# dsh-restart

**简体中文** | [English](README_EN.md)

  <img alt="许可证" src="https://img.shields.io/badge/license-MIT-263146?style=flat-square">
  <img alt="零依赖" src="https://img.shields.io/badge/dependencies-zero-4b6fff?style=flat-square">
  <img alt="无构建步骤" src="https://img.shields.io/badge/build%20step-none-7da1de?style=flat-square">
  <img alt="适配内核" src="https://img.shields.io/badge/dsh-0.2.0--rc.2-2f6f4f?style=flat-square">
  <img alt="平台" src="https://img.shields.io/badge/platform-Windows-0078d4?style=flat-square">
  <img alt="状态" src="https://img.shields.io/badge/status-stable-2f6f4f?style=flat-square">

</div>

<div align="center">

> 装完插件总要重启 DeepSeek Harness 才生效，而界面上没有任何重启入口。
> 这个插件在标题栏的「应用 / 编辑」右侧补上一个「重启」按钮，点两下，九秒后回来。
>
> *Installing a plugin always means restarting DeepSeek Harness, yet the UI has no
> restart entry point. This plugin puts a Restart button next to the Application /
> Edit menus in the title bar. Click twice, and you are back in nine seconds.*

</div>

---

## 亮点

- **补上内核缺失的一环。** 桌面版没有任何能被插件触发的重启通路（详见「为什么不能简单地 quit + 重新启动」），这个插件自己开一条，而不是让用户手动去托盘退出再双击图标。
- **外观自动一致。** 按钮插进的是 preload 造菜单条时留下的 open shadow root，样式由那份 shadow 样式表里的裸 `button` 规则提供，因此高度、内边距、hover 背景与「应用 / 编辑」天然相同；界面语言也跟随 `<html lang>` 切换。
- **不弹控制台窗口。** 重启脚本整条命令包在 `conhost.exe --headless` 里，不给脚本分配任何窗口。否则默认终端为 Windows Terminal 时，脚本会跑在可见窗口里，新实例继承该控制台后窗口永不消失，手动关掉还会连带杀掉新实例。
- **失败可查。** 每一步写进 `$DSH_HOME/logs/dsh-restart-plugin.log`，最后一步以「新实例的 Host 子进程开始监听」作为重启成功的判据，不比对端口号——桌面版固定以 `--port 0` 启动，每次的端口都不一样。Host 与 `dsh-subprocess-local` 的 runner 同名，靠命令行里的 `dsh-desktop-host/lib/index.js` 区分。
- **零依赖、无构建步骤、纯插件挂载。** 宿主端只 import `node:` 内置模块；浏览器端是手写的 `__ModuleLoader__` bundle，不经打包器。不改内核，不留补丁，卸载只需移除 bundle 条目。

## 你会看到什么

![标题栏按钮的位置与两种状态](docs/images/titlebar-button.svg)

Windows 标题栏，紧挨着「应用」「编辑」的右侧。点击行为：

1. **第一次点击** → 按钮变成「确认重启？」（4 秒内不点会自动撤销）
2. **第二次点击** → 按钮显示「正在重启…」并禁用，旧实例被结束，新实例自动拉起

重启会终止正在运行的任务，而这个按钮位置又太顺手，所以做成两次点击。

整条链路长这样——重点是重启脚本必须由 WMI 创建，否则会被旧实例一起带走：

![重启链路](docs/images/restart-flow.svg)

## 安装

**前置**：DeepSeek Harness 桌面版（Windows），内核 0.2.0-rc.2 上验证通过。

### 方式一：桌面版内置 CLI（推荐）

桌面版自带一个能管理 `desktop` profile 的 CLI——`@deepseek-ai/dsh-desktop-host/lib/cli.js` 以 `manageDesktopProfile: true` 启动内核启动器，从而绕过了「desktop profile 由 Electron 独占管理」这道闸门。用法：

```
set ELECTRON_RUN_AS_NODE=1
"C:\D\software\DeepSeek Harness\DeepSeek Harness.exe" --expose-internals ^
  "C:\D\software\DeepSeek Harness\resources\app.asar\dsh\node_modules\@deepseek-ai\dsh-desktop-host\lib\cli.js" ^
  plugin --profile desktop add https://codeload.github.com/csuwzw/dsh-restart/tar.gz/refs/tags/v1.0.1
```

把路径换成你自己的安装目录。**注意 `github:csuwzw/dsh-restart` 这种写法需要 git**：pnpm 会先跑
`git ls-remote https://github.com/csuwzw/dsh-restart.git HEAD` 去解析 ref，机器上没有 git 就直接失败
（`'git' 不是内部或外部命令`）。上面的 codeload tarball URL 不需要 git，它就是一个普通压缩包地址。

三种写法在**没有 git** 的 Windows 上实测（用桌面版 CLI，空 profile）：

| 写法 | 结果 |
| --- | --- |
| `github:csuwzw/dsh-restart` | 失败，`git ls-remote` 找不到 git |
| `github:csuwzw/dsh-restart#main` / `#v1.0.0` | 失败，同上（任何 ref 名都会触发 `ls-remote`） |
| `github:csuwzw/dsh-restart#<40 位 commit sha>` | 成功 |
| `https://codeload.github.com/csuwzw/dsh-restart/tar.gz/refs/tags/v1.0.0` | 成功 |
| `https://codeload.github.com/csuwzw/dsh-restart/tar.gz/refs/heads/main` | 成功 |

想固定版本就用 tag 形式的 codeload URL，想跟最新就用 `refs/heads/main`（代价是版本不再可复现）。

装完重启一次（或直接用刚装上的按钮）。

### 方式二：桌面版插件管理器

打开 **设置 → 插件**，在安装框里填入本仓库地址或本地目录路径。这是应用自己管理的安装通道，更新时机由它掌握。

### 方式三：手工放置

把 `package.json`、`index.js`、`client.js`、`restart.ps1`、`cordis.patch.yml` 复制到 `<DSH_HOME>/profiles/desktop/node_modules/dsh-restart/`，然后：

1. 在 profile 的 `package.json` 里，`dependencies` 加入 `"dsh-restart": "1.0.1"`（不要写 `link:`——桌面端会拒绝含符号链接的 profile 树）
2. 在 `dsh.profile.bundles` 数组末尾追加 `"dsh-restart"`
3. 重启应用一次

**不要再往 `cordis.patch.yml` 添加条目**：被 `dsh.profile.bundles` 引用的包，其自带的 patch 层会自动生效；两处同时注册会报 `duplicate loader entry id`。

### 安装后验证

日志文件应当出现：

```
2026-10-17 02:27:59.155  armed: oldPid=39848 port=19387 exe=C:\D\software\DeepSeek Harness\DeepSeek Harness.exe
2026-10-17 02:27:59.470  taskkill /PID 39848 /T /F -> exit=0
2026-10-17 02:28:00.332  launched: C:\D\software\DeepSeek Harness\DeepSeek Harness.exe (old alive=False)
2026-10-17 02:28:09.738  verify: main=40120 host=40488 listening=[58157] after 9s
```

四行齐全且最后一行 `listening=[...]` 非空，即完整链路可用。方括号里是新实例的端口，与旧实例的 `port=` 不同属正常。**首次安装必须手动重启一次**，按钮之后才存在。

## 实现结构

```
index.js           宿主端：注册 POST /api/dsh-restart/restart（仅回环可达），
                   收到请求后用脱离 DSH job object 的 WMI 进程安排重启
client.js          浏览器端：标题栏菜单条里的按钮（手写 __ModuleLoader__ bundle）
restart.ps1        真正干活的重启脚本，由宿主经 WMI 启动
cordis.patch.yml   作为 profile bundle 挂载宿主端
client.test.cjs    假 DOM 离线自测：挂载时机、两次点击、语言跟随、清理
icon.svg           本文件与 README 顶部的图标
```

## 为什么不能简单地 quit + 重新启动

设计过程中逐个排除了五条更短的路，每条都留下了可复现的取证：

- **没有可用的优雅退出入口。** 桌面版把重启能力锁在 Electron 主进程里，插件够不着；唯一那处 `app.relaunch()` 位于 `development` 分支内（`resources/app.asar` 的 `main.js`），生产版不生成该菜单项。托盘菜单只有打开/退出，渲染进程的 `dshDesktop` API 全表里也没有 quit/restart。
- **宿主进程被关在 job object 里。** 从插件里普通 spawn 出来的进程与 Host 同属一个 job，旧实例一退出就会被一并带走，拉不起新实例。所以本插件用 WMI（`Win32_Process.Create`）创建重启脚本：它的父链是 `WmiPrvSE.exe → svchost.exe → services.exe`，已脱离该 job，且仍在 explorer 的交互会话里（`sessionId=1`、`UserInteractive=true`），因此能启动带界面的新实例。
- **窗口关闭只是隐藏。** 主窗口的 `close` 事件被 `preventDefault()` 拦下改为隐藏到托盘，所以必须真正结束进程（`taskkill /T /F`），而不是发关闭消息。
- **单实例锁要求旧进程先走。** 新实例拿不到锁就只会聚焦旧窗口，所以脚本先等旧 pid 消失，再清理残留端口占用，最后才拉起新实例。
- **重启脚本必须跑在无窗口环境里。** 默认终端若是 Windows Terminal，它会忽略 PowerShell 的 `-WindowStyle Hidden`。实测对照：

  | 启动方式 | 存活期内观察到的控制台窗口 |
  | --- | --- |
  | `powershell.exe -File restart.ps1` | **2 个**（`CASCADIA_HOSTING_WINDOW_CLASS` + `PseudoConsoleWindow`），全程都在 |
  | `conhost.exe --headless powershell.exe -File restart.ps1` | **0 个** |

  新实例继承那个控制台后，窗口被日志一直占着不会消失；手动关掉窗口还会连带杀掉新实例（Windows 关闭控制台窗口会终止附着其上的所有进程）。`conhost --headless` 不给脚本分配窗口，这条继承链就此断开。

Host 无需特殊处理：它与 Electron 之间是 IPC 连接，Electron 一退出，Host 收到 `disconnect` 就自行走 shutdown 流程，端口随之释放。

## 路由

```
POST /api/dsh-restart/restart
Headers: content-type: application/json
         x-dsh-restart-action: restart
```

响应 `{ ok: true, oldPid, exe, port }` 后 300ms 才真正动手，让响应先落到浏览器。

**安全围栏**：以对端 socket 地址判定回环（Host 头是调用方可控的，只作附加检查），并要求自定义动作头——这会把请求变成非简单请求，外部页面无法在不触发 CORS 预检的情况下构造它，从而挡住 CSRF。非 POST 回 405，非回环或缺少动作头回 403。

脚本的端口参数取自请求连接的**本端端口**（`req.socket.localPort`），不是硬编码：webServer 的端口可以配成 0 由系统分配，写死会在那种部署下清错对象。

## 验收情况

逐项取证见 [验收记录](docs/verification/2026-10-17-v1.0.0.md)，含每次对照实验的原始观察值。

| 项目 | 结果 |
| --- | --- |
| 端到端重启 | 四步日志齐全，端口重新监听，**9 秒恢复** |
| 控制台窗口 | `conhost --headless` 下全程 **0 个**（原实现 2 个，全程都在） |
| job object 隔离 | WMI 子进程 `IsProcessInJob` 返回 **FREE**，sessionId 与 explorer 相同 |
| 客户端离线自测 | **25 项全部通过**（假 DOM，不需要浏览器） |
| 路由信任围栏 | GET→405、无动作头→403、错 content-type→403、正确→200 |
| 干净环境安装 | 空 profile 装 tgz 成功，逐文件 sameHash |
| 卸载残留 | profile patch 层、注册表、服务、计划任务均无残留 |

发版记录见 [docs/releases/](docs/releases/)：当前 [v1.0.1](docs/releases/v1.0.1.md)（修 1.0.0 的安装文档错误）。

## 已知边界

- **仅 Windows。** 重启脚本依赖 WMI、`conhost.exe` 与 `taskkill`，这三者在其它平台都不存在。宿主端与浏览器端本身是跨平台的，但脚本不跑就没有重启能力。
- **会终止正在运行的任务，不等待收尾。** 桌面版自身也没有可用的优雅退出通路（见上），所以这里如实终止而不是假装优雅。
- **宿主端与客户端产物的改动都要重启 DSH 才生效。** 宿主端本身是启动时挂载的；客户端 bundle 由 `@deepseek-ai/dsh-client-modules` 在启动 compose 时一次性读入并缓存，只有启用 `@deepseek-ai/dsh-client-hmr` 时才有 watcher 刷新。本 profile 未启用 HMR，所以刷新页面也不会拿到新版。
- **按钮位于标题栏菜单条而非原生菜单内。** 那条原生菜单由 Electron 主进程用 `applicationItems()` 构建，且 IPC handler 强制校验 sender（`assertDesktopSender`），插件无法往里加项，所以只能做视觉一致的同级按钮。
- **没有重启失败的自动重试。** 脚本只记录结果，不做第二次尝试——旧实例已被终止的情况下盲目重试会造出重复实例。

## 开发

无安装步骤、无依赖。需要 Node ≥ 20。

```
node client.test.cjs client.js    # 离线自测，25 项检查
```

自测覆盖：菜单条已存在时的挂载、菜单条晚到时的 MutationObserver 补挂、语言跟随切换、第一次点击不发请求、确认态超时自动撤销、第二次点击才发请求、请求头正确、正在重启时禁用、清理函数摘掉按钮。

自测用极简 DOM stub，不需要浏览器，也不出网。

仓库结构：

```
index.js                 宿主端：注册 POST /api/dsh-restart/restart（仅回环可达）
client.js                浏览器端：标题栏菜单条里的按钮（手写 __ModuleLoader__ bundle）
client.test.cjs          离线自测
restart.ps1              真正干活的重启脚本，由宿主经 WMI 启动
cordis.patch.yml         作为 profile bundle 挂载宿主端
catalog/dsh-plugin.json  插件清单（manifest v0.15）
docs/RELEASING.md        发版流程
docs/releases/           各版本发布说明
docs/verification/       逐项验收取证
docs/images/             README 用的示意图（手绘 SVG）
PACKAGING.md             打包与分发指南
.github/workflows/ci.yml 语法检查、自测、BOM 守卫
```

改动 `client.js` 或 `index.js` 后，profile 里的副本需要显式同步——pnpm 的 `file:` 依赖用硬链接，
用编辑器整体替换文件会换 inode，源与副本就此脱钩。同步后重启 DSH 才生效（本 profile 未启用 HMR）。

## 安全与隐私

- 插件不收集任何数据，不联网，除重启外不写任何文件（日志除外）。
- 唯一的网络暴露是一个仅回环可达的 POST 路由，且要求自定义动作头。
- 重启脚本以当前用户身份运行，不请求提权，不做持久化（不写注册表、不装服务、不建计划任务）。
- 日志内容仅为进程 id、可执行文件路径、端口与时间戳。

卸载：从 `dsh.profile.bundles` 移除 `dsh-restart`，再从 `dependencies` 移除该条目，然后删除 `node_modules/dsh-restart/`。插件不留任何补丁，日志文件可直接删除。

## 免责声明

本插件会**结束正在运行的 DeepSeek Harness 进程**——这是它的功能，不是副作用。点下「确认重启？」之前请确认没有需要保留的、正在生成中的任务：桌面版自身没有可用的优雅退出通路，所以这里是如实终止，不等待收尾。

重启**不删除任何数据**：配置、会话记录、插件、日志都原样保留。但如果某个任务正好写到一半，那一半会丢。

## 反馈

- 安装或使用中遇到问题：[提交 Issue](https://github.com/csuwzw/dsh-restart/issues)
- 想自己改：打包与分发见 [PACKAGING.md](PACKAGING.md)，发版流程见 [docs/RELEASING.md](docs/RELEASING.md)

## 许可证

MIT，见 [LICENSE](LICENSE)。

本项目为独立插件，与 DeepSeek 无隶属、认可或赞助关系。
