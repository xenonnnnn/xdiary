# xdiary

xdiary 是一款完全原生的 macOS 日记应用。它使用 Swift 6 和 SwiftUI 构建，不包含网页、WebView、本地服务器或 Node.js 运行环境；日记只保存在这台 Mac 上。

## 直接使用

双击 [dist/xdiary.app](dist/xdiary.app) 即可运行。也可以把它拖到 macOS 的“应用程序”文件夹中长期使用。

当前交付版本要求 macOS 14 或更高版本，构建产物为 Apple Silicon（arm64）。

当前产物使用本机 ad-hoc 签名，没有 Apple Developer ID 公证。复制到另一台 Mac 后，如果系统拦截首次启动，可在 Finder 中右键应用并选择“打开”。

## 已实现

- 左侧按年、月浏览日记，月份默认折叠；右侧按日填写，并可用前后一天、周视图或日期选择器快速切换。
- 内置“每日复盘”模板，内容对应需求截图；同时提供“自由书写”模板。
- 输入后自动保存；连续输入会合并为一次磁盘写入，关闭窗口时会立即刷新。每个日期只保存一篇日记。
- 自定义模板支持一级、二级、三级标题，以及短文本、长文本、数字和评分输入。
- 模板内容可增删、调整顺序、复制、设为默认，并在编辑时实时预览。
- 未保存的模板修改会单独保留为恢复草稿，关闭窗口后仍可继续编辑。
- 每篇日记保存创建时的模板快照。之后修改或删除模板，不会改变历史日记的结构。
- 可按本周、上周、本月、全部或自定义日期范围导出 Markdown，内容按日期排列，保留问题、回答和评分单位，适合交给 AI 分析。
- 可导出完整 JSON 备份，并在另一台 Mac 的 xdiary 中导入；导入前会显示新增和冲突数量，并允许选择保留本机内容或使用备份内容。
- 如果主数据文件损坏或版本不兼容，启动页可直接重试、定位原文件，或从完整 JSON 备份恢复。
- 应用文字统一为 14 px 视觉尺寸，常用按钮统一为 28 px 高度。

## 数据与备份

本机数据文件位于：

```text
~/Library/Application Support/xdiary/xdiary-data.json
```

日常迁移请使用应用内的“导入与导出”：

1. 点击“下载完整备份”，保存 JSON 文件。
2. 在另一台 Mac 上打开 xdiary，进入“导入与导出”并选择“导入备份”。
3. 预览新增和冲突数量，选择冲突处理方式后确认导入。

每周交给 AI 分析时，选择“本周”或“上周”，再导出 Markdown。Markdown 便于阅读和分析；完整 JSON 用于无损恢复。

## 开发与构建

需要 Xcode Command Line Tools 和 Swift 6：

```sh
swift test --disable-sandbox
./scripts/build-native-app.sh
```

构建脚本会生成并签名 `dist/xdiary.app`。应用无第三方运行依赖，也不需要联网。

## 项目结构

- `Sources/xdiary/`：原生 SwiftUI 界面与应用状态。
- `Sources/XDiaryCore/`：数据模型、校验、日期、存储、导入和导出。
- `Tests/`：核心数据层和应用状态测试。
- `Resources/`：应用信息与原生图标资源。
- `scripts/build-native-app.sh`：生成可双击运行的 `.app`。
- `dist/xdiary.app`：最终原生应用。
