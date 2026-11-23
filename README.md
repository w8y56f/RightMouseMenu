# RightMouseMenu

[English](README.en.md)

RightMouseMenu 是一款适用于 macOS 15 及以上版本的 Finder 右键菜单工具。你可以通过菜单栏打开设置，管理新建文件、开发工具和实用功能等菜单项。

在项目目录中运行：

```sh
bash Scripts/run.sh
```

如需在 Xcode 中调试，请打开 `RightMouseMenu.xcodeproj`，然后运行 `RightMouseMenu` scheme。运行脚本会注册 Finder 扩展并启动应用。在 RightMouseMenu 的「权限」中打开「登录项与扩展」，启用 Finder 扩展。从旧版更新时，请启用新版扩展。如果 Finder 仍显示旧菜单，请重新启动 Finder。

在「权限」中请求 Finder 自动化权限，以使用「文件信息」。新建 Terminal 窗口和运行 iTerm2 命令时，首次使用会请求自动化权限。新建 Terminal 标签页使用系统自带的「在文件夹位置新建终端标签页」服务。Tabby 窗口和标签页通过其命令行启动器打开。

Xcode 项目文件由 `Scripts/generate_project.py` 生成。修改构建目标或资源时，请更新该脚本。
