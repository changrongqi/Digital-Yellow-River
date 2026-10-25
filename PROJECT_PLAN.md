# 黄河记忆 · 黄河文化分布式数字档案 —— 开发计划书

> 本计划书是项目开发的总纲与工作基线，随开发推进**动态修订**（修订历史见 [REVISION_LOG.md](REVISION_LOG.md)）。
> 每个子任务完成并编译验证后，同步更新计划书状态。
>
> 📌 **动态演进（用户授权，2026-09-25）**：本计划书不是固定契约——开发过程中若发现需要新增子任务、
> 展开实现细节、调整任务范围或顺序（含里程碑内容本身），可直接更新计划书，在 [REVISION_LOG.md](REVISION_LOG.md) 中写明理由，
> 保持「计划 = 最新共识」；发现计划与实际不符时，「改计划」优先于「绕过计划」。
>
> ⚠️ **开工前必读（硬性要求）**：动手前先通读 [PITFALLS.md](PITFALLS.md)（原第 6 节「踩坑清单」）**全文**，并逐条对照本次任务范围；
> 清单里的坑都是真实踩过的，**不许凭记忆跳过，不许反复重踩**。
> 收尾时若有新坑，先补进 PITFALLS.md、同步 REVISION_LOG.md，再提交。

---

## 0. 文档地图与接手必读（先读本节）

> 计划书是总纲；方法论、踩坑、风险、历史等细节已拆为独立分册，**避免主文档膨胀**。接手时按下列顺序读，即可快速、精准掌握全部要求。

| 文件 | 内容 | 何时读 |
|---|---|---|
| **PROJECT_PLAN.md**（本文件） | 产品定位、技术约束、架构目录、数据模型、里程碑 M1~M6、验收标准、开发工作流 | 每次开工前通读 |
| [PITFALLS.md](PITFALLS.md) | 37 条踩坑清单（ArkTS/ArkUI/JSON/构建/路由/分布式/Canvas/权限/同步目标/墓碑/返回拦截/API 口径/设备标识/编辑暂存/订阅注销/数据仓库/刷新单通道/无障碍与触控/色彩模式/滚动定位与大屏限宽/推荐转收藏组合写入 等硬约束） | **每次编码前必读全文**，编码中逐条自查 |
| [ISSUES_RISKS.md](ISSUES_RISKS.md) | 阶段遗留问题 R1~R4（已全部清零）+ 观察项 O1~O31（环境限制、构建告警基线 O3、同步/图谱/编辑保护/API 口径/设备标识/标签编辑/页面订阅/数据仓库/刷新单通道/无障碍设备验证/深浅色验证/滚动定位与大屏限宽验证/推荐转收藏闭环验证） | 排障、构建告警比对、评估环境限制时 |
| [OPTIMIZATION_PLAN_V1.md](OPTIMIZATION_PLAN_V1.md) | 全项目优化总表（26 项、分级、依赖、第一轮 B1/H1~H4、状态与验收） | 开始/推进优化轮次时，与 §5 M6 配合使用 |
| [CONTENT_METHODOLOGY.md](CONTENT_METHODOLOGY.md) | 联网搜证 + 内容深写方法论（来源优先级 / 核证纪律 / 事件与文旅结构 / 双份同步 R3 / 图片） | 每批遗址内容深写、事件/文旅/图集开工前 |
| [REVISION_LOG.md](REVISION_LOG.md) | 全部修订历史（当前 78 条，按时间倒序、最新在前） | 追溯决策理由、交接前补记 |

**接手速记（最高优先级硬约束，细节见对应分册）**

1. **产品定位**：沉浸式文化遗产体验产品，非精简知识库；信息量目标 = 现状 10 倍，内容必须联网搜证官方/权威来源并核证，**禁止凭记忆写精简数据**；事件须可点开子详情、文旅须含行程规划/参观指引/深度解说、考古内容需真实图片（可点开放大）。
2. **技术栈**：ArkTS + ArkUI 声明式（禁 `any`、禁解构），API 16+ Stage 模型（任务书要求 ≥ 12），**零网络依赖**（资源全部 rawfile 预置离线），本地 Preferences 为基线 + distributedKVStore 分布式同步。
3. **用户数据**：Favorite/Note/Theme 必须携带 `deviceId` + `updatedAt`；冲突按 **LWW**（updatedAt 新者胜，相等时 deviceId 字典序小者胜）。
4. **数据纪律**：rawfile 与 Mock 双份同构（R3）；JSON 正文内嵌引号用中文引号「」；mock 模板字符串内分段写 `\\n`；整表 0 条视为加载失败（抛异常，供 mock 兜底）。
5. **路由**：目标页必须注册 `resources/base/profile/main_pages.json`；详情/事件/笔记/推荐跳转统一带 `id`。
6. **动手前先查证**：复杂代码（新 kit/不熟 API/新架构/较大新逻辑）必须先查华为官方文档 + 本机 SDK d.ts 双重核对，官方推荐用法优先于自创写法。
7. **工作流**：一次只做一个子任务 → 构建 `BUILD SUCCESSFUL` → commit（`[M里程碑.子任务] 摘要`）→ 汇报；同一文件禁止并行修改，改完回读校验。
8. **计划动态演进**：新增/调整任务直接改本计划，并在 REVISION_LOG.md 记理由；「改计划」优先于「绕过计划」。
9. **构建告警基线**：以 ISSUES_RISKS.md 的 O3 为准，按「文件 + 告警类型」比对，行号漂移不算新增；超出基线一律视为新增问题，处理掉再提交。
10. **真机联调**：清单见 §5 M3.4；无真机时以「代码实现 + 编译自测」为基线；普通本地模拟器无法真实组网（O7 实证），双向同步与 LWW 冲突以真机为最终依据。

---

## 1. 项目概述

基于 OpenHarmony 的黄河文化数字档案应用「黄河记忆」，整合黄河河南段（三门峡、洛阳、郑州、开封、濮阳五市）文化遗产资源（仰韶文化、二里头遗址、殷墟、商城遗址、汴梁文化等），提供沉浸式文化探索；利用鸿蒙分布式数据能力，实现收藏与笔记多设备自动同步，打造个人文化记忆库。

> **产品定位（2026-09-27 用户明确，最高优先级）**：本应用是**沉浸式文化遗产体验**产品，不是精简数据知识库。
> 三大硬性要求：
> 1. **信息量目标 = 现状的 10 倍**：内容必须联网搜索真实官方/权威来源（官网、博物馆、文旅厅、文物局、学术报道）编辑抄录并核证，**禁止凭记忆写精简数据**；凡我基于知识草拟的内容，一律视为「待官方核证草稿」，交付前必须经搜索比对。
> 2. **事件可点开**：遗址详情页的每个历史事件都可作为入口，点击打开**事件子详情页**做专题讲解（背景/经过/影响/相关人物文物/延伸阅读/深度解说）。
> 3. **文旅深度化**：文旅信息须含**行程规划**（推荐路线/时长/交通/串联景点）、参观指引（开放时间/票务）、深度解说（看什么、怎么看、背后的故事），让用户能据此规划一次真实的文化旅行。
> 4. **考古内容配真实图片**（2026-09-27 增补）：遗址考古内容（文物照片/遗址/发掘现场）需要**真实图片**，页面内显示缩略图、**点击打开放大**（Lightbox）、**动态布局**（响应式自适应）；图片须可点开查看大图，实现细节见 M1.10。
> 数据规模策略：23 条遗址 × 10 倍内容，按遗址分批联网搜证扩充（每批完成后经用户抽查校验），子任务进度见 M1.7。

### 1.1 内容深写与搜证方法论（已拆分至 CONTENT_METHODOLOGY.md）

> 本节完整内容已拆分为独立分册 **[CONTENT_METHODOLOGY.md](CONTENT_METHODOLOGY.md)**（搜证来源优先级 / 核证纪律 / 事件深写结构 / 文旅深写结构 / 双份同步纪律 R3 / 图片资源现状 / 填入真实图片的操作方式），内容原样迁移、无删改。
> **每批遗址深写、事件子详情、文旅深度化、图集内容开工前必读该分册全文**，按方法论执行。

## 2. 技术约束

| 项 | 值 | 说明 |
|---|---|---|
| IDE | DevEco Studio | — |
| 系统 | OpenHarmony / HarmonyOS | — |
| API 版本 | **最低 16**（`compatibleSdkVersion: 5.0.4(16)`） | 任务书要求 ≥ 12；当前编译 SDK 26，最低运行 API 16 |
| 语言/框架 | **ArkTS + ArkUI 声明式范式** | 全程必须遵守，禁 any、禁 JS 魔法 |
| 模型 | Stage 模型 | 工程已就绪（apiType: stageMode） |
| 硬件 | 手机/平板/模拟器 | 不依赖额外采购 |
| 网络 | **零网络依赖** | 文化资源全部预置本地，离线可完整浏览 |
| 存储 | 本地离线为基线 + 分布式 KV 同步 | distributedKVStore |

## 3. 架构与目录约定

```text
entry/src/main/
├── ets/
│   ├── entryability/          # 入口 Ability（保持）
│   ├── entrybackupability/    # 系统备份扩展（保持）
│   ├── pages/                 # 页面层（UI）
│   │   ├── Index.ets          # 主页：Tabs（发现/收藏/同步面板）
│   │   ├── Discovery.ets      # 发现页：检索 + 三维度筛选 + 列表
│   │   ├── Detail.ets         # 详情页：五层级内容 + 收藏 + 笔记 + 推荐
│   │   ├── NoteEdit.ets       # 笔记编辑页
│   │   ├── Favorites.ets      # 收藏页（按标签分组）
│   │   ├── SyncPanel.ets      # 同步状态面板
│   │   └── KnowledgeGraph.ets # 知识图谱页：主题状态 + 归类 + 图层开关 + 弹层编排
│   ├── components/            # 可复用 UI 组件（M1.10 起）
│   │   ├── ImageGallery.ets   # 图集组件：缩略图网格 + 点击 Lightbox 放大（动态布局）
│   │   └── graph/             # 知识图谱组件集（C1.2 拆分，C1.4 分层，C1.6 渲染/信息卡拆分）
│   │       ├── GraphCanvas.ets    # 交互与视图控制：数据刷新 + 视口 + 手势 + 控件
│   │       ├── GraphRenderer.ets  # 纯绘制层：边/节点/标签/空态（不持有 ArkUI 状态）
│   │       ├── GraphLayout.ets    # 图模型构建 + 确定性力导向布局 + 视口适配（无 UI 依赖）
│   │       ├── GraphNode.ets      # 图谱节点/边/图模型定义（含节点种类与边语义）
│   │       ├── NodeInfoPanel.ets   # 节点信息卡（主题/已归类/拓展推荐三态展示）
│   │       ├── HeritageCard.ets   # 遗址卡片（已归类/拓展推荐共用）
│   │       ├── ThemeEditorSheet.ets  # 主题编辑器弹层（新建/编辑）
│   │       ├── ManageSheet.ets    # 归类管理弹层（已归类/未归类）
│   │       └── ConfirmDeleteSheet.ets # 删除主题确认弹层
│   ├── model/                 # 数据模型层（类型定义，无逻辑）
│   │   ├── Types.ets          # 三个枚举（年代/类型/城市）
│   │   ├── Heritage.ets       # 文化条目 + 详情（五层级）
│   │   ├── Favorite.ets       # 收藏
│   │   ├── Note.ets           # 笔记
│   │   └── SyncStatus.ets     # 同步状态
│   ├── data/                  # 预置数据层：rawfile JSON 解析
│   ├── service/               # 业务服务层
│   │   ├── FavoriteService.ets   # 收藏/笔记/标签 CRUD + 本地持久化
│   │   └── SyncService.ets       # distributedKVStore / autoSync / LWW 冲突
│   └── utils/                 # 工具函数（推荐算法/主题推荐聚合/年代配色/时间格式）
└── resources/rawfile/         # 预置数据集：heritage JSON + 封面图片（离线基线）
```

分层原则：`pages` 只做 UI 与状态；数据读写一律走 `service`；`model` 只有类型。避免跨层直接引用 rawfile。

## 4. 数据模型约定（一次成型，后续只增不改）

### 4.1 枚举（Types.ets）
- `HeritageEra`：仰韶 / 龙山 / 夏商 / 周 / 汉唐 / 宋（年代轴线）
- `HeritageType`：都城遗址 / 墓葬群 / 窑址 / 古建筑
- `HeritageCity`：三门峡 / 洛阳 / 郑州 / 开封 / 濮阳 / 安阳（M1.2 增补，殷墟所在地）

### 4.2 Heritage（只读预置数据）
| 字段 | 类型 | 说明 |
|---|---|---|
| id | string | 唯一标识（城市-年代-序号） |
| name | string | 遗址名称 |
| era | HeritageEra | 年代（枚举值） |
| type | HeritageType | 类型 |
| city | HeritageCity | 城市 |
| coverImage | string | rawfile 封面图相对路径 |
| summary | string | 一句话简介（列表页用） |
| detail | HeritageDetail | 五层级详情 |

HeritageDetail：`intro`（图文介绍）/ `discovery`（考古发现）/ `events: string[]`（历史事件）/ `poems: Poem[]`（相关诗词，title+author+content）/ `tourism`（现代文旅）。

### 4.3 用户数据（Favorite / Note）
**必须携带 `deviceId` + `updatedAt`（冲突判定 LWW 的前提），即使 M2 单机阶段也用不到，M3 直接复用，避免返工。**

- `Favorite`：id、itemId、tags[]、createdAt、**updatedAt、deviceId**
- `Note`：id、itemId、content、createdAt、**updatedAt、deviceId**

### 4.4 SyncStatus
`progress`（0~100）/ `lastSyncTime`（0=从未同步）/ `conflictCount` / `conflictLog: ConflictLogItem[]`（itemId+time+reason）。

## 5. 里程碑计划

> 状态图例：⬜ 未开始 / 🚧 进行中 / ✅ 完成

### M1 工程骨架 + 预置数据集 + 发现/筛选/检索/详情页（模拟器可运行）

| 编号 | 子任务 | 内容 | 状态 |
|---|---|---|---|
| M1.1 | 工程骨架 + 数据模型 | model 目录 5 个文件（enum + 4 结构） | ✅ |
| M1.2 | 预置数据集 | rawfile heritage_data.json（8 条真实遗址，字段一次成型）+ data/HeritageDataLoader 解析 | ✅ |
| M1.3 | 主页 Tabs + 发现页列表 | Index 改 Tabs；发现页渲染 rawfile 数据列表 | ✅ |
| M1.4 | 三维度筛选 + 关键词检索 | 年代/类型/城市组合筛选 + 检索框 | ✅ |
| M1.5 | 详情页 | 五层级内容 + 跳转（Navigation/router） | ✅ |
| M1.6 | 数据集扩充 + 加载缓存（M2 前置） | 补齐每市 3~5 条、填补龙山年代段；HeritageDataLoader 进程内缓存；mock 与真机共用同一解析路径 | ✅ |
| M1.7 | 内容 10 倍扩充 + 文旅深化（样本先行，联网搜证） | 23 条遗址 × 10 倍信息量（联网搜索官方/权威来源核证，禁止凭记忆精简）；文旅含行程规划/参观指引/深度解说；**仰韶村首批完成并经验证通过**；**虢国墓地/二里头/龙门石窟/殷墟/郑州商城/北宋东京城/戚城/偃师商城/汉魏洛阳故城第二至十批完成**；**王城岗第十一批完成**（联网搜证：郑州市文物局/河南省文物局/省文旅厅/省发改委/登封市政府/河南日报/郑州日报/光明网等，intro 4 段/discovery 5 段/events 8 条含子详情/tourism 四卡/highlights 8/specs 12/artifacts 6/images 4 占位）；其余 12 条按遗址分批推进（**第十二至二十三批全部完成，2026-09-27**：少林寺常住院/邙山陵墓群/巩义黄冶三彩窑址/开封铁塔/繁塔/庙底沟/函谷关/西水坡/回銮碑/修定寺塔/安阳文峰塔/灵泉寺石窟，均按 §1.1 方法论联网搜证官方/权威来源核证，结构同前：intro 4 段/discovery 5 段/events 8 条含子详情/tourism 四卡/highlights 8/specs 12/artifacts 6/images 4 占位） | ✅ |
| M1.8 | 事件子详情页 | 遗址详情页每个历史事件可点击，打开事件专题页（背景/经过/影响/相关人物文物/延伸阅读）；events 升级为结构化对象（含详情字段，模型只增不改）；仰韶村 events 8 条已含完整专题字段，其余随 M1.7 分批深化 | ✅ |
| M1.9 | 文旅深度化迭代（用户复验反馈） | ① tourism 由 string 升级为 TourismInfo 结构化对象（overview 概览 / guide 参观指引键值 / itinerary 行程规划 / interpretation 深度解说，加载层旧字符串自动迁移为 overview）；② Detail 文旅页签改卡片化 UI（概览正文 → 参观指引信息卡 → 行程规划段落卡 → 深度解说卡，空块隐藏）；③ HeritageEvent 新增 commentary（深度解说），事件子详情页独立段落渲染；④ 仰韶村二轮联网搜证（国家文物局/新华网/省文旅厅/河南日报/渑池县政府）补全 8 条事件 commentary+furtherReading 出处，tourism 结构化深写 | ✅ |
| M1.10 | 遗址图片框架（真实图片占位 + 点击放大） | 模型新增 HeritageImage（path/caption/source），HeritageDetail 与 HeritageEvent 各加 images 数组（缺失兜底空数组，只增不改）；新增 components/ImageGallery.ets 图集组件——**动态布局**（Flex wrap 响应式网格，缩略图 + 图注 + 来源）、**点击缩略图 → 全屏 Lightbox 放大**（bindContentCover 页面级遮罩不被 Scroll 裁剪，深色遮罩 / ✕ 关闭 / 页码 / 左右切换 / 图注来源）；图片用 resourceManager.getRawFileContent + @kit.ImageKit createImageSource/createPixelMap **动态加载 rawfile**（Image 组件吃 PixelMap，d.ts 已核证）；path 为空或加载失败显示**占位卡**（虚线框 +「图片待补充」+ 建议来源）；考古页签「遗址图集」与事件子详情页「图集」已接入，仰韶村已填 4 张遗址级 + 1921/2020/2021 事件级占位条目（path 空）。**已实测官方图片 URL 经搜索代理缓存不可下载（404）→ 结构完成、图片待用户提供/稳定渠道后填入 rawfile**（零网络依赖离线打包） | ✅ |

### M2 收藏与笔记全流程（增删改查、标签管理）+ 本地持久化（重启不丢）

| 编号 | 子任务 | 内容 | 状态 |
|---|---|---|---|
| M2.1 | FavoriteService + 本地持久化 | Preferences/RDB 存储收藏与笔记 | ✅ |
| M2.2 | 收藏页 | 按标签分组列表 + 自定义标签 | ✅ |
| M2.3 | 笔记编辑页 | 文字 + 自动时间戳（标签归收藏维度，见 REVISION_LOG.md） | ✅ |
| M2.4 | 详情页接入收藏/笔记 | 收藏按钮、笔记入口、列表联动 | ✅ |
| M2.5 | 我的笔记入口（体验补强） | 按遗址聚合笔记列表页，未收藏遗址的笔记也能快速找回 | ✅ |

### M3 分布式数据同步（赛题核心，2026-09-26 拆解为子任务表）

> **验证策略（依据当前环境裁定）**：无鸿蒙真机（仅模拟器），按「代码实现 + 编译自测」为基线推进；
> 模拟器可验证单机降级路径（KV 初始化失败/无组网不影响本地功能、降级 UI 文案）；
> 真实双向同步需两台真机（同华为账号 + 同 WLAN + 开蓝牙）联调，留待设备到位后进行（见 O7）。
> API 用法对齐华为官方文档（@kit.ArkData distributedKVStore / @kit.DistributedServiceKit），接口名以官方 API 文档为准，不自行发明。

| 编号 | 子任务 | 内容 | 状态 |
|---|---|---|---|
| M3.1 | 权限声明 + SyncService 骨架 | DISTRIBUTED_DATASYNC 权限；distributedKVStore 单版本 KV 初始化 + 降级（失败仅记日志不崩溃）；LWW 冲突判定 + conflictLog 维护；on('dataChange') 订阅骨架 | ✅ |
| M3.2 | FavoriteService 双写改造 | 收藏/笔记变更时本地 Preferences + 分布式 KV 双写；收到远端变更回调后 LWW 合并进内存缓存并刷 UI；单机自动降级 | ✅ |
| M3.3 | 同步面板 | Index 第 3 个 Tab：进度 / 最后同步时间 / 冲突记录数 / 在线设备数；单机降级「等待设备上线」；手动 sync 入口 | ✅ |
| M3.4 | 编译自测基线 + 真机联调待办 | 构建 BUILD SUCCESSFUL + 告警基线比对；整理真机联调操作清单（签名配置、组网、验证步骤）写入计划书 | ✅ |

- 接入 `distributedKVStore` + `distributedDeviceManager`
- put 后 autoSync + 手动 sync() 入口 + on('dataChange') 刷新 UI
- LWW 冲突处理（比较 updatedAt + deviceId 兜底），冲突写入 conflictLog
- 真机双端验证（同华为账号）；无真机则代码实现 + 编译自测作为基线

**M3.4 真机联调操作清单（设备到位后按序执行，2026-09-26 整理）**

> 前置：两台 HarmonyOS 真机（如华为手机/平板）。用户已有华为开发者账号并已登录 DevEco。

1. **签名配置（一次性）**：DevEco Studio → File → Project Structure → Signing Configs，
   勾选「Automatically generate signature」，确认自动证书生成成功（登录态下点几下即可，无需手工制作证书）。
   之后 Run 直接装真机，不再跳过签名。
2. **组网前提（三件套，缺一不可）**：两台设备登录**同一华为账号**；连接**同一 WLAN**；**开启蓝牙**；
   另在「设置 → 更多连接」确认多设备协同/超级终端开关已打开。组网后同步面板「在线设备」应出现对端。
3. **安装**：两台真机各安装同一签名包（同一 bundleName `com.example.first`，签名必须一致才能互通分布式数据）。
4. **基础同步验证**：A 端收藏某遗址 + 写笔记 → 观察 B 端收藏页/详情页是否自动出现（autoSync）；
   B 端反向操作验证双向。
5. **手动同步验证**：同步面板「立即同步」→ 返回 true 提示 + 最后同步时间更新（syncComplete 回调）。
6. **LWW 冲突验证**：两端同时（离线各自修改后组网）修改同一条笔记正文 → 组网同步后两端应一致收敛到
   updatedAt 较新版本；同步面板「冲突记录」出现 1 条说明保留结果。
7. **删除同步验证**：A 端取消收藏/删笔记 → B 端对应消失。
8. **重启持久化**：两端各自杀进程重开 → 收藏/笔记仍在（Preferences 本地基线不受同步影响）。
9. **降级路径回归**：单机（不组网）重复 M2 全部验收项 → 行为与 M2 阶段完全一致。

### M4 智能关联推荐（2026-09-27 拆解为子任务表，M4.0 为前置改版）

| 编号 | 子任务 | 内容 | 状态 |
|---|---|---|---|
| M4.0 | 详情页信息架构与视觉改版（前置） | 年代主题色英雄横幅 + 五层级/笔记 Tabs 页签化 + 历史事件时间轴 + 诗词古风卡（推荐区块将接入新结构） | ✅ |
| M4.1 | 推荐算法 | 条目特征向量（年代/类型/城市 one-hot）→ 余弦相似度 → Top-N（utils 层纯函数） | ✅ |
| M4.2 | 详情页推荐区块 | 「介绍」页签下方「相关遗址推荐」横向卡片，点击带 id 跳详情（O2）；基于收藏微调 | ✅ |

### M5 创新扩展（2026-09-27 起推进 C1，C2/C3 待 M3 真机联调后评估）

> 状态图例沿用；C1 为「文化主题聚合与个人知识库构建」——用户自定义文化主题标签 → 收藏归类 →
> 知识节点网络可视化（Canvas）→ 基于知识结构的拓展推荐，主题与关联数据经分布式 KV 实时同步（C1.3）。

| 编号 | 子任务 | 内容 | 状态 |
|---|---|---|---|
| C1.1 | 主题数据模型 + 主题服务 | 新增 model/Theme.ets（id/name/colorIndex/createdAt/updatedAt/deviceId，LWW 兼容）；Favorite 增 themeIds[]（只增字段，旧数据缺省空数组）；service/ThemeService.ets：主题 CRUD（增/改名/删，删除主题仅清关联引用不删收藏）+ 收藏归类 setFavoriteThemes（走 FavoriteService 双写）+ Preferences 持久化（同一 store，theme_json 键）+ 订阅 SyncService.onRemoteChange 做主题远端 LWW 合并 | ✅ |
| C1.2 | 知识图谱页 + 首页入口 | pages/KnowledgeGraph.ets（Index 第 4 个 Tab「图谱」）：主题 chips 选择/新建/重命名/删除 → Canvas 知识节点网络（中心=主题、环绕节点=已归类遗址，点击带 id 跳详情，O2）+ 归类操作（已归类列表移除 / 弹层从未归类收藏中选取加入）+ 拓展推荐（该主题已收藏遗址的相似推荐，排除已收藏，复用 utils/Recommendation）+ 空态兜底（无主题引导新建 / 有主题无收藏引导归类） | ✅ |
| C1.3 | 分布式同步扩展 | SyncService 增 theme_ 前缀通道：syncTheme/removeThemeSync、RemoteChanges 增 upsertThemes/deletedThemeIds、远端解析 parseThemeFromWire；FavoriteService 增 updateFavoriteThemes（双写 syncFavorite，themeIds 随收藏走 LWW）；主题同步经 autoSync + 面板「立即同步」一并覆盖；真机联调并入 O7 清单 | ✅ |
| C1.4 | 知识图谱交互与呈现重构（2026-10-22，用户要求参考 relation-graph / Trilium Notes / Obsidian） | ① 分层：新增 GraphLayout.ets（图模型 + 确定性力导向布局 + 视口适配，纯函数），GraphNode.ets 扩展节点/边/图模型，GraphCanvas.ets 只做渲染与手势；② 视觉：中心主题 + 环形种子力导向布局，节点大小按连接度编码，同类关联（同年代/同城市）二次曲线 + top-3 防毛球，拓展推荐空心节点挂在最相似遗址旁（虚线关系），标签屏幕坐标固定字号 + 缩小时淡出；③ 交互：Tap 选中并出信息卡、Pan 平移/拖拽节点、Pinch 缩放、右上角 ＋/－/⟲，邻接高亮其余淡出，点击空白取消；④ 逻辑：推荐改为多锚点聚合、排除全部已收藏；选中信息卡可直达详情/移出主题/归类管理；空主题补重命名/删除入口（修 O10）；@Watch + 数据签名修复 Canvas 不随数据重绘（修 O9），内容未变时保留用户视口 | ✅ |
| C1.5 | 图谱可读性与语义打磨（2026-10-22，C1.4 后续） | ① 标签渲染重构：主题名/计数改屏幕坐标固定字号，遗址标签由「scale<0.72 全部隐藏」改为「优先级（选中 > 邻接 > 连接度）+ 碰撞避让」，低缩放下按空间逐条放置而不是整体消失；② 推荐语义：信息卡显示「推荐依据」（与哪条已归类遗址同年代/同城市/同类型），纯函数与布局锚点同源，保证虚线边与解释一致；③ 信息卡增强：节点类型徽标、遗址核心看点、主题覆盖（年代/城市）统计、空主题画布内引导；④ 一致性：关闭推荐图层时清除已选推荐节点，拖动节点后重算包围盒并收敛视口；⑤ 适配：画布高度按屏幕宽度自适应（360~520vp），平板不再固定 360vp；⑥ 主题外观：重命名时可改主题色（ThemeService 扩展 colorIndex，走既有 LWW 同步） | ✅ |
| C1.6 | 图谱结构规范化（2026-10-22，C1.5 后续） | 审计结论：三层分层成立，无推倒重来必要；针对「上帝组件 + 页面混编 + 重复计算」做不改接口的拆分：① 从 GraphCanvas 抽出 GraphRenderer 纯绘制层（边/节点/标签/空态），GraphCanvas 只保留数据刷新、视口、手势与控件；② 从 KnowledgeGraph 抽出 NodeInfoPanel 子组件（主题/已归类/拓展推荐三态信息卡），页面只传展示值与回调；③ 把主题推荐聚合抽为 ThemeRecommendation 纯函数（多锚点聚合/去重/排除已收藏，行为与 C1.4 完全一致）；④ 绘制层内去重节点透明度与屏幕坐标计算；⑤ 修正主题节点 degree 预置语义与「纯函数」失准注释；外部 props/回调、页面路由、服务层与业务规则保持不变 | ✅ |
| C1.7 | 图谱交互与主题编辑打磨（2026-10-22，C1.6 后续） | ① 标签点击命中：GraphRenderer 记录本次已绘制标签的屏幕矩形，GraphCanvas 点按在节点圆未命中时回退到标签命中；平移起点仍只认节点圆，避免从标签拖动节点造成行为变化；② 主题重名反馈：ThemeEditorSheet.onSave 返回 boolean，重名/空名时弹层不关闭并显示行内错误，成功才关闭（原实现静默关闭，用户输入丢失）；③ 可读性：主题色板橙色由 #EF6C00 调整为对比度达标的 #BF360C（白字 13vp 由约 3.1:1 提升到约 5.6:1），画布空态副文案与页面操作提示提高对比度；④ 非主题选中不计算主题覆盖统计 | ✅ |

> C1 设计要点：
> - 主题与 M2 收藏标签是**两个维度**：标签是收藏卡片的管理分类（待实地探访/已去过/研究资料 + 自定义），
>   主题是**文化脉络聚合**（如「彩陶文化」「青铜文明」「帝王陵寝」），一个收藏可归入多个主题，多对多；
> - 模型只增不改：Theme 全新增、Favorite 仅增字段，解析层 getStrArray 缺省空数组天然兼容旧数据（踩坑 1/2/4）；
> - 分层：ThemeService 是主题数据唯一权威（仿 FavoriteService 模式：内存缓存 + Preferences + 分布式双写 + 远端 LWW 合并）；
>   归类写 FavoriteService.updateFavoriteThemes（收藏唯一权威不变，避免两个权威改同一份数据）；
> - 知识节点网络用 ArkUI Canvas 绘制（CanvasRenderingContext2D，d.ts 双重核对，官方 ts-components-canvas）；
>   布局：中心主题节点 + 环绕遗址节点（圆周分布）+ 连线，克制简洁（用户偏好：不堆 3D、不做多余视觉）;
> - 拓展推荐复用 M4 纯函数 recommendHeritages（list=当前数据源全量、currentId=主题下某遗址、favoriteIds=已收藏集合），
>   过滤出「同主题已收藏」之外的建议条目，横向卡片展示。
> - C1.4 图谱架构（参考 relation-graph 核心/布局/渲染分离、Trilium Note Map 根节点与关系语义、
>   Obsidian 力导向参数与节点度数编码）：`GraphLayout.buildGraphModel` 只产出节点/边，`layoutGraph`
>   只产出世界坐标，`GraphCanvas` 只做视口变换与绘制；推荐节点以「最相似遗址 → 推荐」虚线挂载，
>   不直接连中心主题，避免推荐被斥力推到画布边缘；同类关联仅取「同年代/同城市」且每节点 top-3，
>   控制视觉噪声。新增图谱逻辑（构建/布局）不依赖 UI，可脱离设备做几何校验。

- C2 分布式数据备份与恢复（⬜）：设备间收藏/笔记/主题/知识图谱完整迁移 + 一键恢复；依赖真机联调（并入 O7）
- C3 多端协同编辑（⬜）：双端笔记实时同步 + 补充/修改/合并/排序成结构化文档；依赖真机联调（并入 O7）

### M6 全项目优化（2026-10-22 起，见 [OPTIMIZATION_PLAN_V1.md](OPTIMIZATION_PLAN_V1.md)）

> 依据 2026-10-22 全项目优化审计（B1 + H1~H4 + M1~M11 + L1~L10，共 26 项）。完整清单、分级、
> 依赖与轮次见 **OPTIMIZATION_PLAN_V1.md**（本里程碑只记录状态汇总与计划演进，细节以优化总表为准）。

| 编号 | 子任务 | 内容 | 状态 |
|---|---|---|---|
| M6.0 | 优化总表 | 新建 OPTIMIZATION_PLAN_V1.md：26 项、分级、依赖、第一轮 B1/H1/H2/H3/H4、验收标准；文件名带 V1 | ✅ 已完成 |
| M6.1 | B1 分布式同步运行时权限 | 新增 PermissionService（查询/首次申请/拒绝后 requestPermissionOnSetting）；SyncService.init 权限门禁（未授权不置 initialized、KV ready 通知面板）；EntryAbility 启动申请 + 回前台重试初始化；SyncPanel 三态文案 + 授权按钮。构建 BUILD SUCCESSFUL，16 条 WARN 与 O3 一致。权限弹窗/拒绝/重试待设备验证（并入 O7） | ✅ 已完成（`de6b8c1`；代码/构建，设备验证待 O7） |
| M6.2 | H1 同步追赶与失败恢复 | 见 OPTIMIZATION_PLAN_V1.md H1；含 sync 目标 networkId 修正、初次 PULL 监听时序补强 | ✅ 已完成（`40f990f` + 复核补强；代码/构建，双端验证待 O7） |
| M6.3 | H2 删除墓碑 | 新增 Tombstone 模型；收藏/笔记/主题删除改为墓碑覆盖同一 KV 键并参与 LWW（实体 vs 墓碑 vs 墓碑）；重新收藏版本推进；themeIds 按墓碑校验；KV 未就绪待写队列 + 墓碑重放。构建 BUILD SUCCESSFUL，16 条 WARN 与 O3 一致。双端删除/复活/并发编辑待设备验证（并入 O20/O7） | ✅ 已完成（`bdb18ee`；代码/构建，设备验证待 O7） |
| M6.4 | H3 笔记未保存退出保护 | 新增原稿基准与脏标记；顶部返回与系统返回统一拦截；有未保存内容弹「放弃修改」确认，取消留下、确认才离开；保存/删除成功直接返回；复核补强：载入原稿不覆盖已输入内容。构建 BUILD SUCCESSFUL，16 条 WARN 与 O3 一致。返回确认交互待设备验证（O21） | ✅ 已完成（`27378bc` + 复核补强；代码/构建，设备验证待 O21） |
| M6.5 | H4 API 兼容口径 | 保持 `compatibleSdkVersion: 5.0.4(16)`；README/PROJECT_PLAN/START_HERE/代码注释统一为「最低 API 16（任务书要求 ≥ 12）」；未下调配置。构建 BUILD SUCCESSFUL，16 条 WARN 与 O3 一致。目标设备安装待验证（O22） | ✅ 已完成（`2a5d0bb`；文档/构建，设备安装待 O22） |
| M6.6 | 第二轮 M1 LWW 版本标识 | 新增共享 DeviceIdentity（系统 ODID 优先、cache UUID 回退，回退值不参与系统备份）；所有写入刷新 deviceId；nextUpdatedAt 保证版本严格递增；冲突台账记录胜方设备并在 SyncPanel 展示。构建 BUILD SUCCESSFUL，16 条 WARN 与 O3 一致。双端平局待设备验证（O23/O7） | ✅ 已完成（`7b9043d` + 复核补强；代码/构建，设备验证待 O23/O7） |
| M6.7 | 第二轮 M2 标签删除提交时机 | 标签编辑器新增 `editorRemovedTags` 暂存，删除自定义标签只改本地候选/勾选；保存时先全局提交删除再提交当前收藏勾选；取消不产生持久化/同步副作用；同名重新新增视为撤销删除。构建 BUILD SUCCESSFUL，16 条 WARN 与 O3 一致。取消/保存交互待设备验证（O24） | ✅ 已完成（`01bdb1e`；代码/构建，设备验证待 O24） |
| M6.8 | 第二轮 M3 MyNotes 数据订阅 | 新增稳定 `dataChangedHandler`，`aboutToAppear` 订阅 `FavoriteService.onDataChanged`，`aboutToDisappear` 用同一引用注销；页面停留时远端合并/其它页面增删笔记立即重算聚合列表；保留 onPageShow 兜底。构建 BUILD SUCCESSFUL，16 条 WARN 与 O3 一致。页面停留刷新待设备验证（O25） | ✅ 已完成（`b1786b0`；代码/构建，设备验证待 O25） |
| M6.9 | 第二轮 M4 数据仓库与 JSON 助手 | 新增 `HeritageRepository`（rawfile 优先、失败统一 mock、`{list,byId,isMock}` + 映射缓存）；7 页迁移，删除各自 try/catch/MOCK/Map；新增 `utils/JsonField` 替换 4 份字段助手；`detail` 缺失/null/非法对象降级为空 detail，不再丢整条。构建 BUILD SUCCESSFUL，16 条 WARN 与 O3 一致。7 页 UI 回归待验证（O26） | ✅ 已完成（`4c39ff1`；代码/构建，设备验证待 O26） |
| M6.10 | 第二轮 M5 状态刷新单通道 | 移除 Index 的 `favoriteRefreshTick`、`onPageShow` 与匿名数据订阅，只保留服务初始化；Favorites 新增稳定 `dataChangedHandler`（aboutToAppear 订阅 / aboutToDisappear 注销），标签保存期间合并刷新；KnowledgeGraph 删除 tick、保留 Favorite/Theme 订阅，归类操作只重建弹层候选。构建 BUILD SUCCESSFUL，16 条 WARN 与 O3 一致。单通道刷新行为待验证（O27） | ✅ 已完成（`6e79281`；代码/构建，设备验证待 O27） |
| M6.11 | 第二轮 M6 无障碍、触控目标与对比度 | 关键触控区（返回/收藏/写笔记/删除/卡片菜单/信息卡关闭/图谱控制/弹层按钮/筛选与标签 chips/主题色点/图集切换/笔记入口）≥44vp；次要文字与徽标对比度提升至 ≥4.5:1（#7A5C52/#77635C/#7D655B、年代 mid 下调、白字徽标）；glyph 控件补 accessibilityText/Level/Selected，Canvas 补说明；未用 API 18 的 accessibilityRole。构建 BUILD SUCCESSFUL，16 条 WARN 与 O3 一致。TalkBack 与字体缩放待验证（O28） | ✅ 已完成（`5732dc5` + 补强 `0c9b973` / `f354d52` / `3524d00`；代码/构建/核算，设备验证待 O28） |
| M6.12 | 第二轮 M7 深浅色模式口径 | 明确只支持浅色：`setColorMode(COLOR_MODE_LIGHT)` 移到 loadContent 成功回调（官方要求页面已加载）；系统栏设置 `#FAF6F0` 底 + `#000000` 内容色；保留 dark 启动底以兼顾启动期状态栏可读性；全套 dark 资源留待 L1 token 后另立任务。构建 BUILD SUCCESSFUL，16 条 WARN 与 O3 一致。系统深浅切换待验证（O29） | ✅ 已完成（`0f3fcc6`；代码/构建，设备验证待 O29） |
| M6.13 | 第二轮 M8 信息卡自动滚动与大屏限宽 | 知识图谱外层 Scroll 绑定 Scroller，信息卡测量容器用 `onAreaChange.position.y`（父坐标系=滚动内容坐标）记录位置；点选节点后仅在卡片不可见时 `scrollTo` 至卡片顶部上方 12vp，已可见不滚；首次渲染未测量时由 onAreaChange 补滚。详情页新增 `CONTENT_MAX_WIDTH=680`，5 个页签内容列与英雄横幅文字列 `width('100%') + constraintSize(maxWidth)`，Scroll.align(Top) 居中；手机布局不变。构建 BUILD SUCCESSFUL，16 条 WARN 与 O3 一致。手机滚动落点与平板行宽待验证（O30） | ✅ 已完成（`1326225`；代码/构建，设备验证待 O30） |
| M6.14 | 第二轮 M9 推荐节点收藏并归类 | 推荐节点信息卡新增「收藏并归类」主操作（`accessibilityText('收藏并归入当前主题')`），查看详情降为次要；`isFavorite` 判重 → `addFavorite` → `getFavorite` 追加当前 themeId → `updateFavoriteThemes`；两次通知用 `addingRecommend` 暂挂、结束后 `refreshSelected` 一次；成功后选中由 RECOMMEND 切 HERITAGE，卡片原地显示已归类。构建 BUILD SUCCESSFUL，16 条 WARN 与 O3 一致。一键闭环待验证（O31） | ✅ 已完成（`2eff641`；代码/构建，设备验证待 O31） |
| M6.x | 第二轮 M10~M11 | 见 OPTIMIZATION_PLAN_V1.md 3.3；M1~M9 已并入 M6.6~M6.14 完成 | ⬜ 未开始 |
| M6.y | 第三轮 L1~L10 | 见 OPTIMIZATION_PLAN_V1.md 3.4 | ⬜ 未开始 |

> **完成标注规则**：已完成项必须写 `✅ 已完成` + 完成范围 + commit；只做代码/构建不等于设备验证通过，未验证范围写入对应 O 项。该规则同时写入 OPTIMIZATION_PLAN_V1.md §0 第 7 条。

> M6 说明：优化项状态**以 OPTIMIZATION_PLAN_V1.md 为唯一权威**，本表不逐项堆细节，避免双份状态漂移。

## 6. 踩坑清单（全文见 PITFALLS.md，开工前必读）

> 本节已拆分为独立分册 [PITFALLS.md](PITFALLS.md)**：原 21 条踩坑（含使用纪律与历史教训）原样迁移、无删改，C1.4 新增第 22 条（Canvas 重绘/字段名冲突/滚动容器手势），C1.5 新增第 23 条（字符串枚举不得与空串比较），M6.1 新增第 24 条（user_grant 权限申请/拒绝后设置页授权/初始化门禁），M6.2 新增第 25 条（sync 目标必须用 networkId、autoSync 不等于初次拉取、初始化失败可重试），M6.3~M6.9 新增第 26~32 条（墓碑 LWW、返回保护、API 口径、设备标识、编辑暂存、订阅注销、数据仓库/detail 降级），M6.10 新增第 33 条（状态刷新单通道、父容器不中转通知、批量操作合并刷新），M6.11 新增第 34 条（无障碍 API 版本下限、44vp 触控、对比度与字体缩放），M6.12 新增第 35 条（setColorMode 必须在 loadContent 之后、浅色锁定与系统栏内容色），M6.13 新增第 36 条（滚动容器内目标位置用父坐标系测量、大屏正文 constraintSize 限宽与 Scroll 顶部居中），M6.14 新增第 37 条（推荐转收藏的组合写入、判重/暂挂订阅/切换选中种类）。
> 纪律不变：每个子任务开工前**通读全文** → 编码中逐条自查（尤其第 1~5、13、15、16 条属 ArkUI/ArkTS 声明式约束，最易反复踩）→ 提交前再对照 → 踩到新坑立即补进 PITFALLS.md、同步 REVISION_LOG.md，**禁止只改代码不改清单**。

### 6.1 当前阶段遗留问题 / 风险（已拆分至 ISSUES_RISKS.md）

> 完整表格与观察项见独立分册 **[ISSUES_RISKS.md](ISSUES_RISKS.md)**（内容原样迁移、无删改）。
> 当前状态速览：R1~R4 全部 ✅（M2 前置已清零，解决方式见分册）；观察项 O1~O31 持续跟踪——O3 为构建告警基线（比对按「文件 + 告警类型」，行号漂移不算新增），O7 为「普通本地模拟器无法真实分布式组网」的实证结论，O18/O19/O20 为 M6.1/M6.2/M6.3 已修但待真机验证的同步项，O21 为 M6.4 已修但待设备验证的笔记未保存保护，O22 为 M6.5 文档口径已统一但待目标设备安装验证，O23 为 M6.6 设备标识已共享且备份复制风险已规避但双端平局待验证，O24 为 M6.7 标签编辑暂存待设备验证，O25 为 M6.8 MyNotes 页面停留刷新待设备验证，O26 为 M6.9 数据仓库迁移后的 7 页 UI 回归待验证，O27 为 M6.10 刷新单通道的一次变化仅刷新一次待验证，O28 为 M6.11 的 TalkBack 播报、字体缩放与 44vp 触控手感待验证，O29 为 M6.12 的系统深/浅切换与状态栏可读性待验证，O30 为 M6.13 的信息卡自动滚动落点与平板/分屏正文限宽待验证，O31 为 M6.14 的推荐节点一键收藏并归类闭环待验证，双向同步与 LWW 冲突以真机联调为准。
> 新增问题随时追加到 ISSUES_RISKS.md，不允许「知道有问题但不登记」。

## 7. 验收标准（M1 阶段）

1. 工程编译零报错，模拟器可运行。
2. 数据模型类型完整、字段与任务书对齐（含 deviceId/updatedAt）。
3. 预置数据可被解析并在发现页列表展示。
4. 三维度筛选 + 关键词检索结果准确。
5. 详情页五层级内容完整，返回/跳转正常。

## 8. 开发工作流与 Git 规范

- **一次只做一个子任务**（如 M1.1 → 验证 → commit → 汇报 → 下一个）。
- **开工前先读 [PITFALLS.md](PITFALLS.md)（踩坑清单）并逐条对照**：清单是硬约束，不是参考资料；反复踩同一个坑视为流程失误。
- **复杂代码先查官方文档（用户要求，2026-09-26 起硬性）**：凡涉及稍微复杂的代码与结构搭建——新 kit / 不熟悉的 API / 新架构接线 / 超过约 30 行的新逻辑——动手前**必须先查真实的官方文档、示例与教学**（华为开发者文档 + 本机 SDK d.ts 双重核对），确认 API 签名、枚举成员与官方推荐用法后再写。网上旧版 OpenHarmony 文档（API 9/10 时代）与当前 HarmonyOS NEXT SDK 存在漂移（踩坑 18 实测），**以本机 SDK d.ts 为最终依据**；官方示例的推荐模式（如 autoSync 与手动 sync 的搭配、dataChange 订阅时机）优先于自创写法。
- **同一文件禁止并行修改**：并发写同一文件会互相覆盖（曾导致踩坑第 14 条丢失），对同一文件的多次改动必须顺序执行，改完回读校验。
- 每完成一个子任务即 commit 一次，commit message 用 `[M里程碑.子任务] 摘要` 格式，如 `[M1.1] 新增数据模型(枚举+Heritage/Favorite/Note/SyncStatus)`。
- 同步更新本计划书的「里程碑状态」，并在 [REVISION_LOG.md](REVISION_LOG.md) 顶部补记本次修订。
- **计划书动态演进（用户授权）**：开发中发现需要新增子任务、展开实现细节、调整任务范围或顺序时，直接更新计划书并在 REVISION_LOG.md 写明理由，不必先请示；「改计划」优先于「绕过计划」。
- 编译验证优先：命令行 hvigor 或 DevEco Studio 构建；构建产物（.preview/.hvigor/build 等）不入库。
- **命令行构建命令**（M1.1 验证可用，PowerShell，于项目根目录执行）：

```powershell
$env:DEVECO_SDK_HOME='E:\DevEco Studio\sdk'
$env:NODE_HOME='E:\DevEco Studio\tools\node'
$env:Path='E:\DevEco Studio\jbr\bin;'+$env:Path
& 'E:\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

> 编译零报错判据：日志出现 `BUILD SUCCESSFUL`；`CompileArkTS` 无 ERROR。

## 9. 修订记录（已拆分至 REVISION_LOG.md）

> 全部修订历史（自 2026-09-23 建立计划书起，按时间倒序、最新在前）见独立分册 **[REVISION_LOG.md](REVISION_LOG.md)**，内容原样迁移、无删改（当前 78 条，以分册为准）。
> 维护规则：新增/调整子任务、范围、顺序、数据结构或踩坑条目时，先在 REVISION_LOG.md 表格顶部插入一行（`| 日期 | 修订内容 |`）写明理由，再同步更新本计划书状态、PITFALLS.md / ISSUES_RISKS.md / CONTENT_METHODOLOGY.md 等受影响分册。
