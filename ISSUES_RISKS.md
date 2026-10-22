# 遗留问题、风险与观察项

> 本文件是 [PROJECT_PLAN.md](PROJECT_PLAN.md) 原 §6.1 的独立分册，内容原样迁移（无删改）。
> 用法：R* 为阶段前置项（必须逐项清零后标 ✅ 并写明解决方式）；O* 为观察项（不阻塞推进，持续跟踪）；新增问题随时追加，不允许「知道有问题但不登记」。
> O3 同时是本项目的**构建告警基线**：每次构建后按「文件 + 告警类型」比对（行号漂移不算新增），超出基线即视为新增问题，处理掉再提交。

## 6.1 当前阶段遗留问题 / 风险（M2 开工前必须逐一清零）

> 本节就是「M2 前置清单」：**开工 M2 之前必须全部清零**，清零后在状态列标 ✅ 并写明解决方式。
> 新增问题随时追加；不允许「知道有问题但不登记」。

| 编号 | 问题 | 影响 | 归属 | 状态 | 解决方式 / 结果 |
|---|---|---|---|---|---|
| R1 | 年代「龙山」0 条数据，点该 chip 必进「没有符合条件的遗产」空态；数据集仅 8 条，未达「每市 3~5 条」 | M1 验收第 4 条（筛选结果准确）与数据集丰富度 | M1.6 | ✅ | heritage_data.json 扩至 **23 条**真实遗址；年代覆盖 仰韶2/龙山2/夏商4/周3/汉唐7/宋5，类型 4 类、城市 6 市全覆盖（每市 3~5 条）；已用 PowerShell `ConvertFrom-Json` 校验：无解析错误、无重复 id、无缺字段 |
| R2 | HeritageDataLoader 无缓存：详情页每次进入都重新读 rawfile 并全量解析 | 数据扩容、M2 收藏页 / M4 推荐复用后重复 IO | M1.6 | ✅ | `loadHeritageList` 增进程内静态缓存 `cachedList`，首次读 rawfile + 解析，之后全走内存（返回同一引用，约定调用方只读） |
| R3 | MockHeritages.ets 与 heritage_data.json 是两份独立数据，字段结构可能漂移，导致预览器与真机表现分叉 | 预览调试失真、解析问题被掩盖 | M1.6 | ✅ | 抽出唯一解析入口 `HeritageDataLoader.parseHeritageList(text, source)`；MockHeritages 改为 JSON 文本（枚举用中文字面值），同样走该入口 → 两份数据共用同一套字段校验/兜底，漂移会立刻在解析结果中暴露 |
| R4 | @Builder 按值传递同族隐患：Index.ets 的 TabLabel 靠「属性里直读 this.currentIndex」才正常，一旦改为参数传入即复现「高亮不跟随」 | 潜在 UI 状态失联（踩坑 15 同类） | M1.6 | ✅ | 经查 SDK `tab_content.d.ts`：tabBar 只接受 `string/Resource/CustomBuilder/TabBarOptions`，无法直接嵌入自定义组件用 @Prop 绑定，故保留「内部直读 this.currentIndex」写法，并在 TabLabel 上加硬约束注释（禁止把选中状态改成参数传入）；踩坑第 15 条同步记录该限制 |

**观察项**（不阻塞 M2，持续跟踪）：

- O1 `coverImage` 全为空且 rawfile 中无任何图片资源，列表用文字徽标占位，详情页「图文介绍」实际只有文 —— 待确定是否引入图片资源。
- O2 详情页仅认 `id` 入参；M2 收藏页 / M4 推荐入口跳转必须统一带 id，否则落「未找到该遗产」。
- O3 `hilog` DOMAIN 统一用 0x0000（测试域）。**构建告警基线已固化（2026-09-27 C1.2 收口更新，仅允许以下 16 条 + 1 条签名提示；其中 M1.8 期间已存在但基线漏记的 3 条——Detail openEventDetail pushUrl、EventDetail getParams/back——于 M4.2 补齐登记；本次新增仅 KnowledgeGraph openDetail pushUrl 1 条同类型告警）**：
  `data/HeritageDataLoader.ets:39 Function may throw exceptions`（getRawFileContent）、
  `pages/Discovery.ets:307 'pushUrl' has been deprecated`、
  `pages/Favorites.ets:226 'pushUrl' has been deprecated`（M2.5 新增，openMyNotes 入口，router deprecate 同类型）、
  `pages/Favorites.ets:566 'pushUrl' has been deprecated`（M2.2 新增，与发现页 pushUrl 同类型的既有技术债，无新增告警类型）、
  `pages/Detail.ets:62 'getParams' has been deprecated`、
  `pages/Detail.ets:215 'back' has been deprecated`、
  `pages/Detail.ets:198 'pushUrl' has been deprecated`（M2.4 新增，router deprecate 同类型；openNoteEditor 且包 try/catch）、
  `pages/Detail.ets:163 'pushUrl' has been deprecated`（M1.8 新增，openEventDetail，M4.2 补齐登记）、
  `pages/Detail.ets:148 'pushUrl' has been deprecated`（M4.2 新增，openRecommendedDetail 推荐卡跳详情，router deprecate 同类型且包 try/catch）、
  `pages/NoteEdit.ets:55 'getParams' has been deprecated`（M2.3 新增，router deprecate 同类型）、
  `pages/NoteEdit.ets:140 'back' has been deprecated`（M2.3 新增，back 已收敛为唯一调用点 goBack()）、
  `pages/MyNotes.ets:125 'pushUrl' has been deprecated`（M2.5 新增，openDetail 收敛唯一调用点）、
  `pages/MyNotes.ets:133 'back' has been deprecated`（M2.5 新增，goBack 收敛唯一调用点）、
  `pages/EventDetail.ets:42 'getParams' has been deprecated`（M1.8 新增，M4.2 补齐登记）、
  `pages/EventDetail.ets:171 'back' has been deprecated`（M1.8 新增，M4.2 补齐登记）、
  `pages/KnowledgeGraph.ets:512 'pushUrl' has been deprecated`（C1.2 新增，openDetail 图谱节点/卡片跳详情，router deprecate 同类型且包 try/catch；行号随 C1.6 拆分由 548 漂移至 512），外加 `SignHap: skip sign 'hos_hap'（未配置 signingConfigs，命令行验证可忽略）`。
  行号随代码增删会漂移，比对以「文件 + 告警类型」为准。
  超出基线的告警一律视为新增问题，处理掉再提交。
- O4 Tabs 切走再切回发现页时筛选条件是否复位，待真机验证一次。
- O5 **预览器/模拟器的中文输入限制（环境问题，非代码问题）**：预览器软键盘是 DevEco 模拟的英文键盘，不支持中文输入法；模拟器物理键盘不支持中文（华为官方 FAQ），中文只能用鼠标点软键盘输入，且需在模拟器「设置 → 系统和更新 → 语言和输入法」把默认输入法设为小艺输入法。真机不受影响。已核对代码：Search/TextInput 未设置 type/inputFilter，无强制英文约束。检索功能的中文验证一律以模拟器（设好输入法）或真机为准。
  环境备注（2026-09-25）：模拟器 SDK（`C:\Users\Lenovo\AppData\Local\Huawei`，约 20 GB）因 C 盘空间不足，已用 robocopy 整体迁移至 `E:\Huawei`，原 C 盘路径为 NTFS Junction 联接（对 DevEco 透明，后续镜像下载/更新经联接直接落 E 盘）。排查环境问题时须知此联接存在；勿手动删除 E:\Huawei。
- O6 **模拟器偶现青绿色背景伪影（环境问题，非代码问题，2026-09-25）**：弹窗（如收藏页「管理标签」）等场景偶发大块青绿色背景（GPU 合成占位色），特征为「一帧出现、任意下一步操作后消失、不操作则一直停留」、色块边界为斜线且部分遮挡正常内容。已全库 Grep 确认代码调色板无任何青色（全程米白 `#FAF6F0` + 棕色系，弹窗遮罩为半透明深棕 `rgba(62,39,35,0.45)`），判定为 DevEco 模拟器渲染合成层未合帧/缓冲残留，真机不受影响；复现时重启模拟器即可，无需改代码。另备注：发现页顶部「N 处遗产」为**当前筛选结果数**（非遗产总数），与筛选 chips/列表同源联动，切换筛选即变化（用户曾误以为静态总数）。
- O7 **分布式同步验证环境限制（2026-09-26 确认，09-27 修正，09-27 实测闭环）**：用户无鸿蒙真机，仅有平板模拟器；有华为开发者账号并已登录 DevEco，但无签名知识（模拟器跑 debug 包不需签名，现阶段不涉及；真机联调时再配置自动签名）。**重要修正**：模拟器**可以登录华为账号**（实测：设置 → 华为账号可登录自有账号、云空间开关可打开），推翻了「模拟器无华为账号体系」的旧判断。**实测闭环（09-27）**：用 hdc 命令行绕过 IDE 运行会话限制，将 HAP 同时安装并启动到两台模拟器（Pura 90 Pro 手机 5555 / MatePad Pro 13 平板 5557，同账号 + 同 VirtWifi）——同步面板「在线设备」仍为 0 台，组网失败。根因：模拟器**无虚拟蓝牙硬件**（系统蓝牙开关置灰不可点，宿主机有 MediaTek 蓝牙但不透传），组网三件套缺蓝牙 → 设备发现失败。结论：**普通本地模拟器无法完成真实分布式组网**（此前为推测，现已实证），双向同步与 LWW 冲突联调以真机为最终依据（M3.4 清单 9 条）。附：DevEco 的多设备运行 = Device Manager 启动多个实例 → Run 配置「选择多个设备」勾选全部一次部署；「不允许并行运行 entry」是 IDE 运行会话限制（同一模块同一时刻 1 个会话），非设备限制；「选择多个设备」对话框不启动新设备；hdc 手动部署命令：`hdc -t <device> install <hap>`（绕过 IDE 会话限制的可靠方式）。
- O8 **【P0】MockHeritages.ets 的 `MOCK_JSON` 结构损坏（2026-10-21 实测，待修）**：自第 11 条 `mock-shaolin-01` 起出现 12 处无缩进裸 `{` 与 12 处多余 `}`（首错 position 140731，源行约 2503），`JSON.parse` 必失败 → 预览器兜底数据全空；rawfile 同内容合法。修法：删除无缩进裸行，再用 Node 模拟模板求值后 `JSON.parse`，须得到 23 条。修复后标 ✅。
- O9 **GraphCanvas 不随数据重绘（2026-10-21 发现，2026-10-22 已修）**：原 `GraphCanvas` 仅在 `onReady` / `onAreaChange` 调用 `drawGraph()`，`@Prop` 变化不触发重绘。C1.4 修复：theme/heritages/recommendations/showAffinity/showRecommend/graphVersion 全部加 `@Watch`；另加数据签名，内容未变时只重绘、不重置用户视口与手动拖拽位置（主题重命名等「同对象改字段」由 graphVersion 兜底触发重建）。
- O10 **空主题无法管理（2026-10-21 发现，2026-10-22 已修）**：C1.4 将「归类管理/重命名/删除主题」操作行移出非空分支，选中主题后始终显示；空主题空态卡仅保留说明文案。
- O11 **同步面板状态时序风险（2026-10-21 发现，待验证）**：`service/SyncService.ets` 的 `getKVStore().then` 成功后未调用 `notifyStatusListeners()`；面板若早于 KV 就绪构建，可能一直显示「单机模式」直到其他事件刷新。
- O12 **诗词板块已删除（用户决定，非缺陷）**：`poems` 数据 0 条、详情页无诗词页签均为预期；模型/解析中的空字段保留不影响业务，**勿补内容或页签**；README/计划书残留「诗词」表述仅口径问题。
- O13 **C1.4 图谱手势待实机验证（2026-10-22 发现，待验证）**：Canvas 绑定了 `GestureGroup(Exclusive(TapGesture, Parallel(PanGesture, PinchGesture)))`，静态构建已通过，但「滚动页内单指平移是否会被外层 Scroll 抢占、Tap 与 Pan 的识别阈值（5vp）在手势轻微抖动时是否误判、双指缩放中心是否跟手」需在模拟器/真机上实测；若出现外层滚动抢占，优先给 Canvas 加 `priorityGesture` 或把画布移出 Scroll 的滚动链。另：模拟器若未启动，用 `Emulator.exe -start "Pura 90 Pro" -noWindow` 启动后按 O7 的 hdc 覆盖安装流程验证。
- O14 **C1.5 图谱可读性改造待实机验证（2026-10-22 发现，待验证）**：标签碰撞避让、主题文字屏幕坐标、画布高度自适应（360~520vp）、主题改色同步均只完成静态构建验证（BUILD SUCCESSFUL，16 条 WARN 与 O3 一致），需在手机/平板模拟器确认：① 开启拓展推荐（fit≈0.58）时标签是否按「选中 > 邻接 > 连接度」保留且不压节点；② 平板 520vp 画布与 32vp 控制按钮的实际观感；③ 重命名改色后 Canvas 是否即时重绘（graphVersion + 数据签名已覆盖），远端改色合并需真机联调。无设备时以构建成功为基线。
- O15 **C1.6 图谱结构重构待实机回归（2026-10-22 发现，待验证）**：GraphCanvas/GraphRenderer 拆分、NodeInfoPanel 组件化、ThemeRecommendation 纯函数化后，命令行 BUILD SUCCESSFUL（16 条 WARN 与 O3 一致），但需在模拟器/真机确认：① 边/节点/标签/空态与 C1.5 视觉一致；② 点选节点后信息卡三态（主题/已归类/拓展推荐）与按钮回调正常，@Prop 变化能随页面状态刷新（踩坑 15 的组件化验证）；③ 主题推荐条目、顺序、排除已收藏行为与重构前一致；④ 手势、视口重置与拖拽无回归。无设备时以构建成功为基线。
- O16 **图谱剩余结构权衡（2026-10-22 审计结论，非缺陷，暂不处理）**：① GraphLayout 构建节点时写入 fill/stroke（引入 EraTheme/Theme 配色），模型与展示仍有轻耦合；若未来支持多皮肤/多渲染器，应把样式解析移到 GraphRenderer（需给主题节点加 colorIndex、归入边色改由渲染层推导），当前只有一套配色，拆分收益低于回归风险；② 视口数学（平移/缩放/夹取/世界↔屏幕）仍在 GraphCanvas，与手势强相关且规模可控，暂不单独抽 Viewport 类；③ KnowledgeGraph 仍约 924 行，主体是声明式 UI 与页面状态，继续拆分收益低，除非引入新的图谱子视图。
