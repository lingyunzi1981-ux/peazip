# 西美压缩 Windows 稳定性恢复

## 原有资产

- 原项目：`lingyunzi1981-ux/peazip`，默认分支 `sources`
- 恢复基线：`57b811e3cc535944e1e61a2cea449802f9e638ca`
- 历史 Windows Run：<https://github.com/lingyunzi1981-ux/peazip/actions/runs/36142066004>
- 历史 artifact：`10868370822`，12,440,259 bytes
- 历史 ZIP SHA256：`2150bbf81b79bd1ad1af8220cda62b12845557db51ae7d09261e028265e7888d`
- 历史安装器 SHA256：`41e237ad68dba2f13154b6ecc42a8d8f69df6353d42bb1f6606377e0aa146784`

历史流水线虽为成功，但只检查安装退出码、文件存在和进程存活。它没有验证压缩内容、中文路径、窗口是否正常或卸载是否干净，因此不能视为完整验收。

## 本次修复

1. 构建全部使用 PowerShell 7；Inno 脚本统一 UTF-8 BOM，停止把 `.iss` 写成 CP936。Inno `LanguageCodePage` 不负责转换 `.iss` 中任意中文字符串。
2. 替换不完整的手写中文向导为 Inno 官方仓库完整中文翻译，保留译者归属。
3. 运行时统一为 PeaZip 11.3.0，下载后验证官方发布资产的固定 SHA256；不再将 11.3 GUI 与 11.2 后端混装。
4. 删除 portable 标记，配置写入用户 AppData；西美使用独立的 `WestBeautyCompression` 配置目录，不覆盖 PeaZip 设置。
5. 品牌标题和默认简体中文在主程序中实现；保留 `peazip.exe` 内部调用别名。
6. 中文桌面/开始菜单、压缩 ZIP/7Z、解压当前/新目录、按格式打开入口；Open With 注册不抢占 Windows 默认文件关联。
7. 构建产物附 SHA256、源码 commit、运行时哈希和签名状态。重建的 PEA 后端哈希被准确嵌入主程序；保留原二进制/DLL 完整性保护，不关闭检查。

## 自动验收覆盖

专用分支通过现有 `windows-latest` runner 执行，未添加付费 runner。

- 中文及空格 Program Files 安装路径，静默安装与重复安装
- 可执行文件/依赖/语言资源存在
- Unicode 程序元信息、卸载项、桌面快捷方式和带引号的右键命令
- GUI 活跃、响应、品牌标题及正常关闭；尝试保存真实屏幕截图
- 用户 AppData 配置、首次简体中文、重装保留配置
- ZIP/7Z/TAR 后端压缩、测试、解压，中文/空格/& 文件名、嵌套目录、空文件、二进制内容逐文件 SHA256 比对
- 加密 7Z 正确密码、错误密码与损坏包拒绝
- 通过与资源管理器相同的前端命令执行 ZIP/7Z 压缩及解压，并检查实际输出
- 卸载返回码、程序/快捷方式/注册表清除，保留用户配置

## 验证状态与限制

本地已通过 PowerShell 语法解析、YAML 解析、UTF-8 模板生成及 43 条右键命令引号检查。它们是静态和生成器检查，不是 Windows 安装测试。

新的 Windows 安装器、运行时自动验收尚未执行，不能将源码修改当成已通过验证的发行版。

Windows runner 通常为 Windows Server。通过后仍需真实 Windows 10/11 标准用户桌面验收：交互安装/取消/UAC、资源管理器多选、Windows 11 新式菜单、100/150/200% DPI、拖放、RAR 样本、大文件/低磁盘空间、杀毒检测和 SmartScreen。

此工程未配置商业代码签名。未购买签名服务、生成凭据或关闭 Windows 安全保护；不能保证无未知发布者或 SmartScreen 提示。

## 编码依据

- <https://jrsoftware.org/ishelp/topic_unicode.htm>
- <https://jrsoftware.org/ishelp/topic_langoptionssection.htm>
- 中文译文来源：<https://github.com/jrsoftware/issrc/blob/main/Files/Languages/ChineseSimplified.isl>
