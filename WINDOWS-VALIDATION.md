# 西美压缩 Windows 候选版验收

## 最终构建

- 安装包版本：11.3.0.1，基于 PeaZip 11.3.0
- 验收提交：`08457633680c459bcd2e91263dd627f557010fbd`
- [Windows 完整构建与验收](https://github.com/lingyunzi1981-ux/peazip/actions/runs/36997092787)：成功
- 执行环境：Microsoft Windows Server 2025 Datacenter，PowerShell 7.6.6
- 79 项安装/运行/归档/卸载断言全部通过；另有 16 项命令安全回归用例通过
- 安装器：`WestBeautyCompression-Setup-x64.exe`
- 大小：13,556,129 bytes
- SHA256：`6c2351f2640b856b7d55603138211fd2f50f35ceaad133134ff4f019646ca25e`
- 签名状态：`NotSigned`

这是经过自动验收的候选构建，不代表所有 Windows 10/11 用户桌面场景均已验收。未合并默认分支，未创建正式 Release。

## 已实测

1. 安装至带中文和空格的 Program Files 目录；静默安装退出码成功
2. 主程序、PEA、7z 和 DLL/语言资源齐全；移除 portable 标记，配置写入用户 AppData
3. 中文产品元信息、卸载项、桌面快捷方式；使用 Windows Unicode IShellLinkW 验证实际目标
4. 中文右键菜单文本和带引号的程序/输入路径；文件与文件夹压缩入口、解压入口注册正确
5. 真实 GUI 正常启动、响应、品牌标题、简体中文界面和正常关闭；已保存并目视核验真实截图
6. ZIP、7Z、TAR 后端压缩、测试及解压；中文、空格、`&` 路径、嵌套目录、空文件、二进制文件逐文件 SHA256 一致
7. 加密 7Z 的正确密码测试成功；错误密码和损坏归档正确返回失败
8. 与资源管理器相同的前端 ZIP/7Z 命令完成压缩，正常退出，产物可测试、解压且内容哈希一致
9. 前端解压到当前目录，中文文件内容一致、进程正常退出、空临时目录被清理
10. 重装同一候选版保留用户配置；卸载成功，程序、桌面快捷方式、卸载项和检查的右键注册项清除，用户配置保留

右键命令注册和执行已测；资源管理器真实鼠标菜单交互、多选与 Windows 11 新式菜单仍属于后续桌面验收。

## 修复要点

- 全流程使用 PowerShell 7 和明确的 UTF-8 BOM 安装脚本；中文向导使用官方维护的完整翻译
- GUI、语言/帮助资源和官方便携运行时统一为 11.3.0；下载后核对固定 SHA256
- 安装版使用独立 `WestBeautyCompression` 用户配置目录，保留 `peazip.exe` 内部调用别名
- 使用原生 Windows API 正确更新 Lazarus 的命名图标组 `MAINICON`；验证六尺寸位图及实际嵌入资源，解决启动时 `Wrong bitmap bit count: 0` 错误
- 在直接启动 7z 的路径中正确处理引号内的合法特殊字符；命令链、管道、重定向、控制字符、shell 包装和伪装程序名的防护保留并增加回归测试
- 解压结束的空暂存目录直接通过 `RemoveDirectoryW` 清理；该 API 不递归删除目录内容，非空目录保留原有受保护路径
- 为重建 PEA 嵌入准确哈希；保留二进制/DLL 完整性检查，不关闭 Windows 安全保护
- Open With 注册不覆盖 Windows UserChoice 默认文件关联

## 仍需验收的边界

- Windows 10/11 的真实标准用户桌面、中文用户配置目录
- 交互安装/取消/UAC、旧版本升级迁移；本次重装测试仅针对当前候选版
- 资源管理器真实多选、Windows 11 新式右键菜单、拖放
- 100%/150%/200% DPI、小屏幕布局、RAR 样本、大文件、低磁盘空间和中断恢复
- 独立安全审查、杀毒检测、商业代码签名与 SmartScreen 信誉

本构建未代码签名，可能出现“未知发布者”或 SmartScreen 提示。没有购买签名服务、生成凭据或关闭安全保护；不能保证无安全提示。

## 证据和来源

- [验证过的源码](https://github.com/lingyunzi1981-ux/peazip/tree/08457633680c459bcd2e91263dd627f557010fbd)
- [安装包构建 artifact](https://github.com/lingyunzi1981-ux/peazip/actions/runs/36997092787/artifacts/11222870216)
- [Windows 日志、79 项断言和截图](https://github.com/lingyunzi1981-ux/peazip/actions/runs/36997092787/artifacts/11221864844)
- [Inno Setup Unicode 说明](https://jrsoftware.org/ishelp/topic_unicode.htm)
- [Inno Setup 中文翻译来源](https://github.com/jrsoftware/issrc/blob/main/Files/Languages/ChineseSimplified.isl)
- [Microsoft IShellLinkW](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nn-shobjidl_core-ishelllinkw)
- [Microsoft RemoveDirectoryW](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-removedirectoryw)

## 恢复基线

原项目 `lingyunzi1981-ux/peazip`，原默认分支 `sources`，恢复基线 `57b811e3cc535944e1e61a2cea449802f9e638ca`。历史 Run 36142066004 的成功仅代表弱冒烟检查：安装返回码、文件存在和进程存活，不能替代本次真实功能验收。
