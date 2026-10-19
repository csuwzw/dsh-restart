# 发版流程

本仓库没有构建步骤，发版 = 改版本号 + 写发布说明 + 打 tgz + 推送 + 打 tag。整个流程约五分钟。

## 0. 前置

| 需要的东西 | 本机现状 |
| --- | --- |
| Node ≥ 20 | 用桌面版 bundled 运行时：`%USERPROFILE%\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe` |
| pnpm | 同上目录下的 `dependencies\pnpm\bin\pnpm.mjs` |
| git | **不需要**。推送走 `tools/push-to-github.mjs`（GitHub REST API） |
| npm CLI | **不需要**，也不发布到 npm（包名已被占用，见 [PACKAGING.md](../PACKAGING.md)） |

## 1. 改版本号

`package.json` 的 `version`。本插件目前只有一条产品线，不区分预发布通道。

同时检查这几处是否要跟着改：

- `catalog/dsh-plugin.json` 的 `version`
- `README.md` / `README_EN.md` 顶部徽章里的「适配内核」版本
- `docs/releases/v<版本>.md`（下一步创建）

## 2. 写发布说明

新建 `docs/releases/v<版本>.md`，固定六节，缺一节不算发版完成：

```markdown
# dsh-restart <版本>

## 本次更新      ← 改了什么、为什么改。每条都要说清动机，不只是「修复了 X」
## 安装          ← 完整可复制命令，路径用占位符并说明怎么替换
## 升级与重启    ← 从上一版升上来要做什么；是否需要手动重启一次
## 回退          ← 怎么退回上一版，以及哪些文件不会被回退碰到
## 验收          ← 表格：项目 / 结果。链接到 docs/verification/ 的详细记录
## 已知边界      ← 本版没做到的部分。诚实列出，不写「暂不支持」了事
```

「已知边界」是硬要求。这个插件的每一版都必须明确写出未验证的部署形态（非 Windows、非默认
profile 名、端口配成 0 等），否则用户会以为它到处都能跑。

## 3. 跑自测

```powershell
node client.test.cjs client.js
```

25 项检查，假 DOM，不需要浏览器，不出网。改动 `client.js` 后必须全绿。

同时人工核对两件容易忘的事：

```powershell
# restart.ps1 首三字节必须是 EF BB BF（PowerShell 5.1 否则按 ANSI 代码页解码）
Format-Hex restart.ps1 | Select-Object -First 1
```

```powershell
# 宿主端语法
node --check index.js
node --check client.js
```

## 4. 打 tgz 并验证

见 [PACKAGING.md 第二节](../PACKAGING.md)。要点：在**空 profile** 里装一次，确认逐文件
sameHash，且 `dsh.bundle.patch` / `dsh.client.platform` / `exports['./client']` 三项声明完整。

## 5. 推送到 GitHub

```powershell
node <工具目录>\push-to-github.mjs --token <PAT> --repo csuwzw/dsh-restart --dir <源码目录>
```

工具会逐文件比对内容，相同的跳过、不同的带 sha 更新，所以重复执行是安全的。首次推送会自动生成
MIT LICENSE（作者行取 token 的登录名）。

token 需要 fine-grained PAT，仓库权限 **Contents: Read and write**。用完可以 Revoke——插件本身
不需要任何 token。

## 6. 打 tag

**不需要 git**：用 `tools/gh-release.mjs` 直接建 tag + Release（同一个 API 调用就能建 tag）：

```powershell
node <工具目录>\gh-release.mjs <token 文件> csuwzw/dsh-restart v<版本> `
  "dsh-restart <版本> — <一句话标题>" docs/releases/v<版本>.md
```

`tag_name` 用 `v<版本>`，与 `package.json` 的 `version` 对应但带 `v` 前缀。Release 正文粘贴
`docs/releases/v<版本>.md`。

**发之前先体检**（不发任何请求，只查正文会不会坏）：

```powershell
node <工具目录>\gh-release.mjs <token 文件> csuwzw/dsh-restart v<版本> --check docs/releases/v<版本>.md
```

会拦住四种坏正文：编码非法的 UTF-8、含 U+FFFD、GBK 误读的乱码字、以及「把对象当正文」（正文里
带 `"PSPath" => ...` 这类 FileInfo 特征）。1.0.0 / 1.0.1 的 Release 正文就是被后两种弄坏的。

**正文里的链接要写成绝对地址。** Release 页面不在仓库目录下，`../../README.md` 这种相对链接在
页面上会 404。用 `https://github.com/csuwzw/dsh-restart/blob/main/<路径>`。

正文写完发现要改，不用重建 tag——同一个工具能只更新正文（会回读校验）：

```powershell
node <工具目录>\gh-release.mjs <token 文件> csuwzw/dsh-restart v<版本> --update <新正文文件>
```

若已装 git，也可以走命令行：

```powershell
git tag -a v1.0.1 -m "dsh-restart 1.0.1"
git push origin v1.0.1
```

**注意 tag 必须指向已经推送好的 main 顶端**：`gh-release.mjs` 传的是 `target_commitish: main`，所以
先推送、后打 tag。推完再改文件会让 tag 落后于 main。

打完后确认：

```powershell
# 应该 200，且 gzip=true
node <工具目录>\gh-tarball.mjs csuwzw/dsh-restart v<版本>
```

再在空 profile 里用这个 tag 装一次（第 4 节的做法，地址换成 `refs/tags/v<版本>`），确认装出来的
`package.json` 版本号与声明正确。用户可以用
`https://codeload.github.com/csuwzw/dsh-restart/tar.gz/refs/tags/v<版本>` 装指定版本——注意不要用
`github:csuwzw/dsh-restart#v<版本>`，那需要机器上装了 git。

## 7. 回滚一次发布

插件是纯源码分发，回滚 = 推回旧文件 + 告诉用户重装：

1. 用旧版源码目录重跑 `push-to-github.mjs`
2. 在 GitHub 上把旧 tag 重新设为 latest
3. 已安装的用户重新执行
   `add https://codeload.github.com/csuwzw/dsh-restart/tar.gz/refs/tags/<旧 tag>`，然后重启 DSH

不要在旧 tag 上原地改文件——按 tag 解析的安装是按 tag 内容抓取的，改了 tag 会让已经装好的
用户拿到不同内容。

## 版本号怎么定

| 改动 | 版本 |
| --- | --- |
| 修文案、修样式、内部重构 | patch |
| 新增用户可见能力（新的按钮状态、新的安装方式） | minor |
| 改路由路径、改日志格式、改 `dsh` 声明字段 | major |

`1.0.0` 是本插件第一次对外发布，所以之前的迭代都并入了它；`1.0.1` 只修文档（README 里「安装不需要
git」的说法不成立），插件代码逐字节未改，属于 patch。
