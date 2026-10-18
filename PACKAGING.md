# dsh-restart · 打包与分发指南

本插件没有构建步骤，所谓「打包」只是把源码目录变成别人能装的东西。下面四种产物按推荐顺序排列。

## 产物一览

| 产物 | 谁用 | 是否需要网络 | 是否需要 git |
| --- | --- | --- | --- |
| GitHub 仓库（codeload tarball URL） | 常规安装 | 需要 | 不需要 |
| GitHub 仓库（`github:` 源） | 装了 git 的机器 | 需要 | **需要** |
| `dsh-restart-<版本>.tgz` | 内网、离线、固定版本 | 不需要 | 不需要 |
| 一键安装包（ZIP，含 `install.ps1`） | 不想敲命令的 Windows 用户 | 不需要 | 不需要 |
| 源码目录直接放置 | 开发调试 | 不需要 | 不需要 |

## 一、npm 包名已被占用（重要）

npm 上的 `dsh-restart` 是**别人的包**（作者 `anweat`，`https://github.com/anweat/dsh-restart`，
主题同样是 DSH 重启插件）。所以：

- **不要**发布到 npm，也**不要**让用户执行 `add dsh-restart`——那会装到别人的包上。
- 分发一律走 codeload tarball URL、tgz 文件或一键安装包。

如果将来要发 npm，先改名（`dsh-restart-plugin` 与 `dsh-one-click-restart` 在撰写时可用），
并同步改 `package.json` 的 `name` 与 `dsh` 字段。

## 二、从源码打出 tgz

本机没有 npm CLI，用桌面版自带的 bundled 运行时即可：

```powershell
$node = "$env:USERPROFILE\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe"
$pnpm = "$env:USERPROFILE\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\pnpm\bin\pnpm.mjs"

& $node $pnpm pack --pack-destination <输出目录>
```

产物是 `dsh-restart-1.0.2.tgz`，约 10 KB，含 `package.json` / `index.js` / `client.js` /
`restart.ps1` / `cordis.patch.yml` / `README.md` / `README_EN.md` / `icon.svg`。

在空 profile 里验证安装（不需要装 DSH，只要 pnpm）：

```powershell
$tmp = Join-Path $env:TEMP 'dsh-fresh-profile'
New-Item -ItemType Directory -Force $tmp | Out-Null
'{ "name": "fresh", "private": true }' | Set-Content (Join-Path $tmp 'package.json') -Encoding UTF8
'minimumReleaseAge: 0' | Set-Content (Join-Path $tmp 'pnpm-workspace.yaml') -Encoding UTF8
& $node $pnpm add <tgz 路径> --config.minimum-release-age=0 --dir $tmp
```

装出的副本应与源码目录**逐文件 sameHash**，且 `dsh.bundle.patch` / `dsh.client.platform` /
`exports['./client']` 三项声明完整保留。

## 三、一键安装包（Windows）

给不想敲命令的用户：一个 ZIP，解压后右键 `install.ps1` → 使用 PowerShell 运行。

安装脚本做四件事，每一步都先备份再动手：

1. 定位 DSH 安装目录与 `$DSH_HOME`（读注册表 / 常见路径，找不到就提示用户指定）
2. 把插件文件复制进 `<DSH_HOME>/profiles/<profile>/node_modules/dsh-restart/`
3. 在 profile 的 `package.json` 里补 `dependencies` 条目与 `dsh.profile.bundles` 数组项（幂等：
   已存在则跳过）
4. 提示用户重启 DSH 一次

脚本不联网、不需要管理员权限、不改 profile 的 `cordis.patch.yml`（被 `dsh.profile.bundles`
引用的包，其自带的 patch 层会自动生效；两处同时注册会报 `duplicate loader entry id`）。

**注意**：`restart.ps1` 首字节必须是 UTF-8 BOM。PowerShell 5.1 对无 BOM 文件按系统 ANSI 代码页
解码，脚本里的中文注释会崩坏并报出 `缺少 using 指令` 一类的词法错误。仓库里的 `.gitattributes`
已声明 `restart.ps1 text` 以免被当作二进制，但 **BOM 不由 git 管理**——重写该文件时务必确认首三字节
仍是 `EF BB BF`。

## 四、从 GitHub 安装

**用 codeload tarball URL，不要用 `github:` 简写**——后者在没有 git 的机器上直接失败：

```
set ELECTRON_RUN_AS_NODE=1
"<DSH 安装目录>\DeepSeek Harness.exe" --expose-internals ^
  "<DSH 安装目录>\resources\app.asar\dsh\node_modules\@deepseek-ai\dsh-desktop-host\lib\cli.js" ^
  plugin --profile desktop add https://codeload.github.com/csuwzw/dsh-restart/tar.gz/refs/tags/v1.0.2
```

`github:owner/repo` 会先让 pnpm 跑 `git ls-remote <url> HEAD` 解析 ref；机器上没有 git 时 pnpm 报
`Command failed with exit code 1: git ls-remote "https://github.com/csuwzw/dsh-restart.git" HEAD "HEAD^{}"`
并退出 1。加 `#main`、`#v1.0.0` 也一样——**任何 ref 名都会走 `ls-remote`**，所以「不需要 git」的说法只对
commit sha 形式和直接的 codeload URL 成立（`dshmarket/lib/accelerate.js` 会把裸 `github:` 重写成
`github:owner/repo#<sha>` 来规避这一点，但那条路径只在市场自己的安装通道里生效）。

实测矩阵（桌面版 CLI，空 profile，本机无 git）：

| 写法 | 结果 |
| --- | --- |
| `github:csuwzw/dsh-restart` | 失败 |
| `github:csuwzw/dsh-restart#main` / `#v1.0.0` | 失败 |
| `github:csuwzw/dsh-restart#87a3945764a30d07298b627a93eefdcc56aee1bb` | 成功 |
| `https://codeload.github.com/csuwzw/dsh-restart/tar.gz/refs/tags/v1.0.0` | 成功 |
| `https://codeload.github.com/csuwzw/dsh-restart/tar.gz/refs/heads/main` | 成功 |

国内网络可能连不上 `codeload.github.com`，新电脑上安装卡住通常就是这个原因——改用 tgz 或一键安装包。

## 五、发布检查清单

- [ ] `package.json` 的 `version` 已递增
- [ ] `docs/releases/v<版本>.md` 已写，含「本次更新 / 安装 / 升级与重启 / 回退 / 验收 / 已知边界」
- [ ] `node client.test.cjs client.js` 全部通过
- [ ] `restart.ps1` 首三字节仍是 `EF BB BF`
- [ ] 源码目录与 profile 里的副本逐文件 sameHash
- [ ] tgz 已重打，并在空 profile 里验证安装
- [ ] README / README_EN 的版本号与徽章已同步
- [ ] 推送到 GitHub（`tools/push-to-github.mjs`）

## 六、不做的事

- **不发布到 npm**：包名冲突（见第一节）。
- **不做自动更新**：插件不联网，也不内置版本检查。升级靠重新执行安装命令。
- **不打 macOS / Linux 包**：重启脚本依赖 WMI、`conhost.exe` 与 `taskkill`，那两个平台上没有
  等价实现，硬发一个装得上但按不动的包没有意义。
