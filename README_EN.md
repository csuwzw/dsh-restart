<div align="center">
  <img src="icon.svg" alt="dsh-restart — one-click restart for DeepSeek Harness" width="120">

# dsh-restart

[简体中文](README.md) | **English**

  <img alt="License" src="https://img.shields.io/badge/license-MIT-263146?style=flat-square">
  <img alt="Dependencies" src="https://img.shields.io/badge/dependencies-zero-4b6fff?style=flat-square">
  <img alt="Build step" src="https://img.shields.io/badge/build%20step-none-7da1de?style=flat-square">
  <img alt="DSH" src="https://img.shields.io/badge/dsh-0.2.0--rc.2-2f6f4f?style=flat-square">
  <img alt="Platform" src="https://img.shields.io/badge/platform-Windows-0078d4?style=flat-square">
  <img alt="Status" src="https://img.shields.io/badge/status-stable-2f6f4f?style=flat-square">

</div>

<div align="center">

> Installing a plugin always means restarting DeepSeek Harness, yet the UI has no
> restart entry point. This plugin puts a Restart button next to the Application /
> Edit menus in the title bar. Click twice, and you are back in nine seconds.
>
> *装完插件总要重启 DeepSeek Harness 才生效，而界面上没有任何重启入口。
> 这个插件在标题栏的「应用 / 编辑」右侧补上一个「重启」按钮，点两下，九秒后回来。*

</div>

---

## Highlights

- **Fills a gap the kernel leaves open.** The desktop app exposes no restart path a plugin can reach (see "Why not simply quit and relaunch"), so this plugin opens its own instead of asking the user to quit from the tray and double-click the icon again.
- **Looks native for free.** The button is inserted into the open shadow root that preload leaves behind when it builds the menu bar, so its height, padding and hover background come from that shadow stylesheet's bare `button` rules — identical to Application / Edit. It follows the UI language via `<html lang>`.
- **No console window.** The whole restart command is wrapped in `conhost.exe --headless`, so the script gets no window at all. Otherwise, with Windows Terminal as the default terminal, the script runs in a visible window, the new instance inherits that console, and the window never goes away — and closing it manually kills the new instance too.
- **Failures are inspectable.** Every step is appended to `$DSH_HOME/logs/dsh-restart-plugin.log`, and the final step judges success by whether the new instance's Host child is listening — not by comparing port numbers, because the desktop app always starts with `--port 0` and gets a different port each run. The Host shares its image name with `dsh-subprocess-local`'s runner; the command line's `dsh-desktop-host/lib/index.js` tells them apart.
- **Zero dependencies, no build step, pure plugin mount.** The host half imports only `node:` builtins; the browser half is a hand-written `__ModuleLoader__` bundle that never sees a bundler. Nothing patches the kernel; uninstalling means removing one bundle entry.

## What you get

![Title bar button, both states](docs/images/titlebar-button.svg)

In the Windows title bar, immediately to the right of Application / Edit. Click behaviour:

1. **First click** → the button becomes "Confirm restart?" (auto-reverts after 4 seconds)
2. **Second click** → the button shows "Restarting…" and disables; the old instance is terminated and a new one is launched

A restart kills running tasks, and this button sits somewhere far too convenient, so it takes two clicks.

Here is the whole chain — the point being that the restart script must be created by WMI, or the old
instance takes it down along with everything else:

![Restart flow](docs/images/restart-flow.svg)

## Installation

**Requires**: DeepSeek Harness desktop app (Windows). Verified on kernel 0.2.0-rc.2.

### Option 1: the desktop app's own CLI (recommended)

The desktop app ships a CLI that may manage the `desktop` profile — `@deepseek-ai/dsh-desktop-host/lib/cli.js` starts the kernel launcher with `manageDesktopProfile: true`, which bypasses the "the desktop profile is managed exclusively by the Electron application" gate. Run:

```
set ELECTRON_RUN_AS_NODE=1
"C:\D\software\DeepSeek Harness\DeepSeek Harness.exe" --expose-internals ^
  "C:\D\software\DeepSeek Harness\resources\app.asar\dsh\node_modules\@deepseek-ai\dsh-desktop-host\lib\cli.js" ^
  plugin --profile desktop add https://codeload.github.com/csuwzw/dsh-restart/tar.gz/refs/tags/v1.0.1
```

Adjust the paths to your installation. **Note that `github:csuwzw/dsh-restart` requires git**: pnpm first runs
`git ls-remote https://github.com/csuwzw/dsh-restart.git HEAD` to resolve the ref, and fails outright when git
is not on the machine (`'git' is not recognized as an internal or external command`). The codeload tarball URL
above needs no git — it is an ordinary archive address.

Measured on Windows **without git**, through the desktop CLI into an empty profile:

| Spec | Result |
| --- | --- |
| `github:csuwzw/dsh-restart` | fails, `git ls-remote` cannot find git |
| `github:csuwzw/dsh-restart#main` / `#v1.0.0` | fails, same (any ref name triggers `ls-remote`) |
| `github:csuwzw/dsh-restart#<40-char commit sha>` | succeeds |
| `https://codeload.github.com/csuwzw/dsh-restart/tar.gz/refs/tags/v1.0.0` | succeeds |
| `https://codeload.github.com/csuwzw/dsh-restart/tar.gz/refs/heads/main` | succeeds |

Pin a version with the tag URL; track the newest commit with `refs/heads/main` (at the cost of a
non-reproducible version).

Restart once afterwards (or just use the button you just installed).

### Option 2: the in-app plugin manager

Open **Settings → Plugins** and enter this repository's URL or a local directory path. That is the app's own install channel, and it controls update timing.

### Option 3: manual placement

Copy `package.json`, `index.js`, `client.js`, `restart.ps1` and `cordis.patch.yml` into `<DSH_HOME>/profiles/desktop/node_modules/dsh-restart/`, then:

1. Add `"dsh-restart": "1.0.1"` to `dependencies` in the profile's `package.json` (do not use `link:` — the desktop app rejects profile trees containing symlinks)
2. Append `"dsh-restart"` to the end of the `dsh.profile.bundles` array
3. Restart the app once

**Do not add anything to `cordis.patch.yml`**: a package referenced by `dsh.profile.bundles` already gets its own patch layer automatically, and registering it twice fails with `duplicate loader entry id`.

### Verifying the install

The log file should show:

```
2026-10-17 02:27:59.155  armed: oldPid=39848 port=19387 exe=C:\D\software\DeepSeek Harness\DeepSeek Harness.exe
2026-10-17 02:27:59.470  taskkill /PID 39848 /T /F -> exit=0
2026-10-17 02:28:00.332  launched: C:\D\software\DeepSeek Harness\DeepSeek Harness.exe (old alive=False)
2026-10-17 02:28:09.738  verify: main=40120 host=40488 listening=[58157] after 9s
```

All four lines with a non-empty `listening=[...]` means the full chain works. The ports in brackets belong to the new instance and normally differ from the old `port=`. **The first install still needs one manual restart** before the button exists.

## Layout

```
index.js           Host half: registers POST /api/dsh-restart/restart (loopback only)
                   and schedules the restart through a WMI process that escapes
                   the DSH job object
client.js          Browser half: the title-bar menu button (hand-written bundle)
restart.ps1        The script that does the work, launched by the host via WMI
cordis.patch.yml   Mounts the host half as a profile bundle
client.test.cjs    Offline self-test with a fake DOM: mount timing, two clicks,
                   language following, teardown
icon.svg           The icon used here and at the top of the README
```

## Why not simply quit and relaunch

Five shorter paths were ruled out one by one, each leaving reproducible evidence:

- **There is no usable graceful-exit entry point.** The desktop app keeps restart capability inside the Electron main process, out of a plugin's reach; the only `app.relaunch()` lives inside a `development` branch (`main.js` in `resources/app.asar`) and is not generated in production. The tray menu only has open/quit, and the renderer's `dshDesktop` API surface has no quit or restart member at all.
- **The host process is confined to a job object.** A process spawned normally from a plugin joins the same job as the Host, so it dies along with the old instance and cannot launch a new one. This plugin therefore creates the restart script through WMI (`Win32_Process.Create`): its parent chain is `WmiPrvSE.exe → svchost.exe → services.exe`, outside that job, and still inside explorer's interactive session (`sessionId=1`, `UserInteractive=true`), so it can start a new instance with a UI.
- **Closing the window only hides it.** The main window's `close` event is `preventDefault()`-ed into a hide-to-tray, so the process must actually be terminated (`taskkill /T /F`) rather than sent a close message.
- **The single-instance lock requires the old process to leave first.** A new instance that cannot take the lock merely focuses the old window, so the script waits for the old pid to disappear, clears any leftover port holder, and only then launches.
- **The restart script must run windowless.** With Windows Terminal as the default terminal it ignores PowerShell's `-WindowStyle Hidden`. Measured:

  | Launch form | Console windows observed while alive |
  | --- | --- |
  | `powershell.exe -File restart.ps1` | **2** (`CASCADIA_HOSTING_WINDOW_CLASS` + `PseudoConsoleWindow`), present the whole time |
  | `conhost.exe --headless powershell.exe -File restart.ps1` | **0** |

  The new instance inherits that console, the window stays occupied by logs and never disappears, and closing it manually kills the new instance (Windows terminates every process attached to a console when the console window closes). `conhost --headless` allocates no window for the script, breaking that inheritance chain.

The Host needs no special handling: it talks to Electron over IPC, and when Electron exits the Host receives `disconnect` and runs its own shutdown, releasing the port.

## Route

```
POST /api/dsh-restart/restart
Headers: content-type: application/json
         x-dsh-restart-action: restart
```

It answers `{ ok: true, oldPid, exe, port }` and only acts 300 ms later, so the response reaches the browser first.

**Trust fence**: loopback is decided by the peer socket address (the Host header is caller-controlled and only used as an extra check), and a custom action header is required — that makes the request non-simple, so an external page cannot construct it without triggering a CORS preflight, which blocks CSRF. Non-POST gets 405; non-loopback or a missing action header gets 403.

The script's port argument comes from the connection's **local port** (`req.socket.localPort`), never a constant: the web server's port may be configured as 0 to let the OS assign one, and a hard-coded value would clear the wrong listener in that deployment.

## Verification

Per-item evidence lives in the [verification record](docs/verification/2026-10-17-v1.0.0.md),
including the raw observations from every comparison run.

| Item | Result |
| --- | --- |
| End-to-end restart | All four log steps present, port listening again, **back in 9 seconds** |
| Console window | **0** throughout under `conhost --headless` (2 with the original implementation, present the whole time) |
| Job object isolation | WMI child reports `IsProcessInJob` **FREE**, same sessionId as explorer |
| Client offline self-test | **25 of 25 checks pass** (fake DOM, no browser) |
| Route trust fence | GET→405, no action header→403, wrong content-type→403, correct→200 |
| Clean-environment install | tgz installs into an empty profile, every file sameHash |
| Uninstall residue | No profile patch layer, no registry, no services, no scheduled tasks |

Release notes live in [docs/releases/](docs/releases/): currently [v1.0.1](docs/releases/v1.0.1.md) (fixes the 1.0.0 installation docs).

## Known limits

- **Windows only.** The restart script depends on WMI, `conhost.exe` and `taskkill`, none of which exist elsewhere. The host and browser halves are cross-platform, but without the script there is no restart capability.
- **It terminates running tasks without waiting for them.** The desktop app itself offers no usable graceful-exit path (see above), so this reports the truth rather than pretending to be graceful.
- **Both host and client changes need a DSH restart to take effect.** The host half is mounted at boot; the client bundle is read once and cached by `@deepseek-ai/dsh-client-modules` while composing, and only a watcher behind `@deepseek-ai/dsh-client-hmr` refreshes it. HMR is not enabled in the reference profile, so refreshing the page does not pick up a new build either.
- **The button sits in the title-bar menu strip, not inside the native menu.** That native menu is built by the Electron main process from `applicationItems()`, and its IPC handler enforces sender validation (`assertDesktopSender`), so a plugin cannot add entries to it — hence a visually identical sibling button.
- **No automatic retry on failure.** The script records the outcome and does not try again — with the old instance already terminated, a blind retry would create a duplicate instance.

## Development

No install step, no dependencies. Node ≥ 20.

```
node client.test.cjs client.js    # offline self-test, 25 checks
```

It covers: mounting when the menu bar already exists, MutationObserver re-mount when it arrives late, language following, no request on the first click, confirm state auto-reverting on timeout, the request firing only on the second click, correct headers, disabled while restarting, and teardown removing the button.

The self-test uses a minimal DOM stub — no browser, no network.

Repository layout:

```
index.js                 host half: registers POST /api/dsh-restart/restart (loopback only)
client.js                browser half: the title-bar button (hand-written __ModuleLoader__ bundle)
client.test.cjs          offline self-test
restart.ps1              the script that actually restarts, launched by the host through WMI
cordis.patch.yml         mounts the host half as a profile bundle
catalog/dsh-plugin.json  plugin manifest (manifest v0.15)
docs/RELEASING.md        release process
docs/releases/           per-version release notes
docs/verification/       per-item verification evidence
docs/images/             diagrams used by the READMEs (hand-drawn SVG)
PACKAGING.md             packaging and distribution guide
.github/workflows/ci.yml syntax check, self-test, BOM guard
```

After editing `client.js` or `index.js`, the copy inside the profile must be synced explicitly — pnpm's
`file:` dependencies are hardlinks, and replacing a file wholesale changes the inode, which detaches the
source from the profile copy. A DSH restart is then required for the change to take effect (HMR is not
enabled in this profile).

## Security and privacy

- The plugin collects nothing, makes no outbound connections, and writes no files beyond its log.
- Its only network exposure is one loopback-only POST route that requires a custom action header.
- The restart script runs as the current user, requests no elevation, and persists nothing (no registry writes, no services, no scheduled tasks).
- Log content is limited to process ids, the executable path, the port and timestamps.

Uninstalling: remove `dsh-restart` from `dsh.profile.bundles`, remove the entry from `dependencies`, then delete `node_modules/dsh-restart/`. The plugin leaves no patch behind, and the log file can simply be deleted.

## Disclaimer

This plugin **ends the running DeepSeek Harness process** — that is the feature, not a side effect. Before
clicking "Confirm restart?", make sure no in-progress task needs to be kept: the desktop app itself offers
no usable graceful-exit path, so this terminates truthfully rather than waiting for a clean shutdown.

A restart **deletes no data**: configuration, sessions, plugins and logs all survive. But a task that
happened to be mid-write will lose that partial write.

## Feedback

- Problems installing or using it: [open an issue](https://github.com/csuwzw/dsh-restart/issues)
- Want to modify it: packaging and distribution in [PACKAGING.md](PACKAGING.md), release process in
  [docs/RELEASING.md](docs/RELEASING.md)

## License

MIT, see [LICENSE](LICENSE).

This is an independent plugin with no affiliation, endorsement or sponsorship from DeepSeek.
