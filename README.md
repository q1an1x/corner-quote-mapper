# Corner Quote Mapper

A lightweight Windows tray utility that maps the Microsoft Pinyin double-quote key to Chinese corner quotes: `「` and `」`.

一个轻量的 Windows 托盘工具：在微软拼音中文模式下，将双引号键映射为直角引号 `「` 和 `」`。

## Features / 功能

- Press `Shift+'` in Chinese input mode to insert `「` and `」` alternately.
- Leave the key unchanged when the IME is in English/alphanumeric mode.
- Use the tray menu to enable or disable mapping, reset the next quote to `「`, or exit.
- Start at sign-in by placing a shortcut to `Start-CornerQuoteMapper.cmd` in the current user's Startup folder.
- No network access, telemetry, or third-party runtime dependencies.

- 中文输入模式下按 `Shift+'`，依次输入 `「`、`」`。
- 输入法处于英文/字母模式时，按键保持原样。
- 可从托盘菜单启用或停用映射、重置为左引号 `「`，或退出工具。
- 如需登录后自动启动，可将 `Start-CornerQuoteMapper.cmd` 的快捷方式放入当前用户的“启动”文件夹。
- 不联网、不收集遥测，也不依赖第三方运行库。

## Requirements / 运行要求

- Windows with Windows PowerShell 5.1 and Windows Forms.
- Microsoft Pinyin or another IME that exposes its native Chinese input mode to Windows.
- A standard U.S. keyboard layout for the default `Shift+'` key mapping.

- Windows、Windows PowerShell 5.1 和 Windows Forms。
- 微软拼音，或能向 Windows 报告中文输入状态的输入法。
- 默认按键映射适用于标准美式键盘布局中的 `Shift+'`。

## Run / 启动

Double-click `Start-CornerQuoteMapper.cmd`. The launcher starts the tray process without a console window. Right-click its tray icon to manage the mapper.

双击 `Start-CornerQuoteMapper.cmd` 启动。程序会在后台运行，不显示控制台窗口；右键托盘图标可管理映射。

To run at sign-in, open the current user's Startup folder and add a shortcut to the launcher. Remove that shortcut to disable automatic startup.

如需登录后自动启动，打开当前用户的“启动”文件夹并添加启动器快捷方式；删除该快捷方式即可取消。

## Behavior and limitations / 行为与限制

- The first mapped quote is `「`; subsequent presses alternate between `」` and `「`. Reset the state from the tray menu if quotes become unbalanced.
- The mapper checks the IME's native-mode state through Windows IME APIs, including the default IME window used by newer text-input applications.
- It uses a system-wide low-level keyboard hook, but only handles the quote key and does not store or transmit typed text.
- The default key is the U.S.-layout `VK_OEM_7` key. Other keyboard layouts may require changing that key mapping in the source.
- Some elevated or custom text-entry applications may block Unicode input injection or may not expose IME state.

- 第一次映射为 `「`，之后在 `」` 与 `「` 之间交替；若引号不成对，可从托盘菜单重置状态。
- 程序通过 Windows 输入法接口读取中文模式，也兼容较新文本应用使用的默认输入法窗口。
- 程序使用系统级低级键盘钩子，但只处理引号键，不保存或传输输入文字。
- 默认按键是美式键盘布局的 `VK_OEM_7`；其他键盘布局可能需要修改源码中的映射。
- 部分以管理员身份运行或使用自定义文本输入的应用可能会阻止 Unicode 注入，或不提供输入法状态。

## License

MIT. See [LICENSE](LICENSE).
