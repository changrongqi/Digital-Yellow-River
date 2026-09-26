# 黄河记忆 · 黄河文化分布式数字档案 —— 开发计划书

> 本计划书是项目开发的总纲与工作基线，随开发推进**动态修订**（见文末修订记录）。
> 每个子任务完成并编译验证后，同步更新计划书状态。
>
> 📌 **动态演进（用户授权，2026-09-25）**：本计划书不是固定契约——开发过程中若发现需要新增子任务、
> 展开实现细节、调整任务范围或顺序（含里程碑内容本身），可直接更新计划书，在修订记录中写明理由，
> 保持「计划 = 最新共识」；发现计划与实际不符时，「改计划」优先于「绕过计划」。
>
> ⚠️ **开工前必读（硬性要求）**：动手前先通读第 6 节「踩坑清单」**全文**，并逐条对照本次任务范围；
> 清单里的坑都是真实踩过的，**不许凭记忆跳过，不许反复重踩**。
> 收尾时若有新坑，先补进清单、同步修订记录，再提交。

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

### 1.1 内容深写与搜证方法论（M1.7~M1.9 实践提炼，持续更新）

> 本小节把「联网搜证 + 深写」的实操方法沉淀为规范，后续每批遗址深写都按此执行。

- **搜证来源优先级**：遗址所在地**县政府官网**（简介/开馆公告/A 级景区名录，如渑池县政府）> **省级文物局/文旅厅** > 省政府门户（市县栏目）> **国家文物局官网**（含「中国考古百年」专栏、博物馆年报系统）> 新华社/人民日报/河南日报等权威媒体 > 政协/方志等地方史料 > 实地攻略（仅参考参观动线与体验描述，数字一律以官方为准）。
- **核证纪律**：① 关键数字（年代/面积/开放时间/电话/出土数量）必须至少 1 个官方来源；② 两条官方来源数字冲突时（如第四次发掘面积 600㎡ vs 200㎡），以最新县政府口径为准，正文不写死争议数；③ 每条事件 furtherReading 注明「机构《篇名》（日期）」全称；④ 新增亮点（如玉钺=军事王权、酿酒工艺）必须能在官方报道中找到对应表述，禁止从科普自媒体转述未经官方证实的说法。
- **事件深写结构**（HeritageEvent 字段填写顺序）：year+title（时间轴主文案）→ summary（一句话概述）→ background（时代背景/前因）→ process（具体经过：日期/人物/器物细节）→ impact（意义/后续影响）→ figures/artifacts（人物与文物清单，宁缺毋滥）→ commentary（深度解说：官方研究细节/学者评价/冷知识）→ furtherReading（来源出处，2~4 个）。
- **文旅深写结构**（TourismInfo）：overview（公园/景区概览、荣誉、场馆简介）→ guide（hours/tickets/contact/address 四键值，**以最新开馆公告为准**）→ itinerary（建议时长 / 推荐动线 / 交通 / 串联联动景区，`\n` 分段）→ interpretation（「看什么、怎么看」按维度分点：地层/器物/聚落/考古史等）。
- **双份同步纪律（R3）**：rawfile 与 Mock 同构；Mock 模板字符串内 `\n` 写 `\\n`（踩坑 19）；每批写毕用 PowerShell `ConvertFrom-Json`（rawfile）+ Node 模拟「模板求值→JSON.parse」（mock）双份校验条数/字段。
- **图片资源现状（2026-09-27 实测）**：WebSearch 返回的官方页面配图链接经搜索代理缓存（`aka.doubaocdn.com` 等）**不可稳定下载**（实测 404），且无法核证版权归属 → **结构先行**：模型预留 images 数组、UI 做缩略图卡 + 点击 Lightbox 放大 + 动态布局（M1.10），真实图片待用户提供或稳定渠道获取后填入 rawfile（本地离线打包，遵守零网络依赖约束）。
- **填真实图片的操作方式（2026-09-27 明确）**：① 把官方图片文件放到 `entry/src/main/resources/rawfile/images/` 目录（文件名自定，如 `yangshao-jianzuiping.jpg`）；② 把对应条目（详情页 `detail.images` 或事件 `events[].images`）的 `path` 字段填为该文件名（如 `"path": "images/yangshao-jianzuiping.jpg"`），caption 写图注、source 写官方来源；③ 无需改任何代码——ImageGallery 组件自动按 path 动态加载 rawfile 并渲染缩略图、支持点击放大；加载失败或 path 空则显示占位卡。MockHeritages 若需同步（R3，预览器调试用），同结构补一份。

## 2. 技术约束

| 项 | 值 | 说明 |
|---|---|---|
| IDE | DevEco Studio | — |
| 系统 | OpenHarmony / HarmonyOS | — |
| API 版本 | **12**（现状沿用，≥ 12 过线） | 任务书要求 ≥ 12 |
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
│   │   └── SyncPanel.ets      # 同步状态面板
│   ├── components/            # 可复用 UI 组件（M1.10 起）
│   │   └── ImageGallery.ets   # 图集组件：缩略图网格 + 点击 Lightbox 放大（动态布局）
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
│   └── utils/                 # 工具函数（推荐算法：余弦相似度等）
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
| M1.7 | 内容 10 倍扩充 + 文旅深化（样本先行，联网搜证） | 23 条遗址 × 10 倍信息量（联网搜索官方/权威来源核证，禁止凭记忆精简）；文旅含行程规划/参观指引/深度解说；**仰韶村首批完成并经验证通过**；**虢国墓地/二里头/龙门石窟/殷墟/郑州商城/北宋东京城/戚城第二至八批完成**；**偃师商城第九批完成**（联网搜证：河南省发改委/省文物局/省文旅厅/洛阳市文物局/偃师区政府/洛阳日报/大河网等，intro 4 段/discovery 5 段/events 8 条含子详情/tourism 四卡/highlights 8/specs 12/artifacts 6/images 4 占位）；其余 14 条按遗址分批推进 | 🚧 |
| M1.8 | 事件子详情页 | 遗址详情页每个历史事件可点击，打开事件专题页（背景/经过/影响/相关人物文物/延伸阅读）；events 升级为结构化对象（含详情字段，模型只增不改）；仰韶村 events 8 条已含完整专题字段，其余随 M1.7 分批深化 | ✅ |
| M1.9 | 文旅深度化迭代（用户复验反馈） | ① tourism 由 string 升级为 TourismInfo 结构化对象（overview 概览 / guide 参观指引键值 / itinerary 行程规划 / interpretation 深度解说，加载层旧字符串自动迁移为 overview）；② Detail 文旅页签改卡片化 UI（概览正文 → 参观指引信息卡 → 行程规划段落卡 → 深度解说卡，空块隐藏）；③ HeritageEvent 新增 commentary（深度解说），事件子详情页独立段落渲染；④ 仰韶村二轮联网搜证（国家文物局/新华网/省文旅厅/河南日报/渑池县政府）补全 8 条事件 commentary+furtherReading 出处，tourism 结构化深写 | ✅ |
| M1.10 | 遗址图片框架（真实图片占位 + 点击放大） | 模型新增 HeritageImage（path/caption/source），HeritageDetail 与 HeritageEvent 各加 images 数组（缺失兜底空数组，只增不改）；新增 components/ImageGallery.ets 图集组件——**动态布局**（Flex wrap 响应式网格，缩略图 + 图注 + 来源）、**点击缩略图 → 全屏 Lightbox 放大**（bindContentCover 页面级遮罩不被 Scroll 裁剪，深色遮罩 / ✕ 关闭 / 页码 / 左右切换 / 图注来源）；图片用 resourceManager.getRawFileContent + @kit.ImageKit createImageSource/createPixelMap **动态加载 rawfile**（Image 组件吃 PixelMap，d.ts 已核证）；path 为空或加载失败显示**占位卡**（虚线框 +「图片待补充」+ 建议来源）；考古页签「遗址图集」与事件子详情页「图集」已接入，仰韶村已填 4 张遗址级 + 1921/2020/2021 事件级占位条目（path 空）。**已实测官方图片 URL 经搜索代理缓存不可下载（404）→ 结构完成、图片待用户提供/稳定渠道后填入 rawfile**（零网络依赖离线打包） | ✅ |

### M2 收藏与笔记全流程（增删改查、标签管理）+ 本地持久化（重启不丢）

| 编号 | 子任务 | 内容 | 状态 |
|---|---|---|---|
| M2.1 | FavoriteService + 本地持久化 | Preferences/RDB 存储收藏与笔记 | ✅ |
| M2.2 | 收藏页 | 按标签分组列表 + 自定义标签 | ✅ |
| M2.3 | 笔记编辑页 | 文字 + 自动时间戳（标签归收藏维度，见修订记录） | ✅ |
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
| M4.1 | 推荐算法 | 条目特征向量（年代/类型/城市 one-hot）→ 余弦相似度 → Top-N（utils 层纯函数） | ⬜ |
| M4.2 | 详情页推荐区块 | 「介绍」页签下方「相关遗址推荐」横向卡片，点击带 id 跳详情（O2）；基于收藏微调 | ⬜ |

### M5 创新扩展（P2，视进度）
- C1 知识图谱可视化 / C2 备份与还原 / C3 多端协同编辑

## 6. 踩坑清单（必须遵守，遇坑及时补充）

> **使用纪律**：① 每个子任务开工前通读本清单全文；② 编码过程中逐条自查（尤其第 1~5、13、15、16 条属 ArkUI/ArkTS 声明式约束，最容易反复踩）；
> ③ 提交前再对照一次；④ 踩到新坑立即补条目并同步修订记录，禁止只改代码不改清单。
>
> 历史教训：第 14 条曾因文档编辑竞态被覆盖丢失，导致「代码已注册路由、清单却没有记录」，记录与实现不一致 —— 所以清单必须随手维护。

1. **rawfile JSON 必须配 parse 逻辑**：ArkTS 无反射，JSON.parse 的结果需要显式逐字段转换为 model 类型；字段缺失或类型不符在运行时静默出错，UI 层要能兜底（空列表/占位）。
2. **JSON 字段要显式声明类型**：不用 `any`（ArkTS 禁 any）；接口/类字段逐一声明；枚举用字符串值并在 parse 时做合法值校验。
3. **用户数据模型（Favorite/Note）从一开始就带 `deviceId` + `updatedAt`**，否则 M3 冲突判定返工。
4. ArkTS 是严格 TS 子集：禁 `any`、禁解构赋值/Destructuring、禁对象字面量隐式 any、类字段必须初始化或重点显式声明类型。
5. `@State` 数组/对象修改必须整体赋值（`this.list = [...]` 或 `this.obj = {...}`），只用 push/obj.x= 不触发刷新，需配合 @Observed/@ObjectLink 或重新赋值。
6. 枚举成员名必须是合法标识符（用英文名），值可用中文字符串。
7. 预置数据集一次成型，标注准确，M1 后结构不再变更。
8. rawfile 路径用 `$rawfile()` 或 `getContext().resourceManager` 获取，避免硬编码绝对路径。
9. 分布式相关代码在单机调试阶段不要阻塞 M1/M2；M3 先本地读写 + 降级 UI。
10. **命令行构建三件套**：DEVECO_SDK_HOME / NODE_HOME 之外，**必须把 `E:\DevEco Studio\jbr\bin` 加进 PATH**。仅设 `JAVA_HOME` 不生效，会报 `spawn java ENOENT`（ArkTS 已编译通过但 PackageHap 失败）。
11. PowerShell 里命令分隔用 `;`，`&&` 不是合法语句分隔符。
12. 编辑计划书状态表（emoji 列）后务必 Read 回读校验，防止状态被误改。
13. **build() 根节点前不允许写任何语句**：连 `const x = this.xxx()` 这类局部变量声明也会被编译器当作额外根节点，报「only one root node」+ Rollup Unexpected token。派生数据改为在 build 的 UI 描述里直接调用方法（如 `this.filterList()`），或放进 @Builder 参数。
14. **router 跳转的目标页必须注册进 `resources/base/profile/main_pages.json`**，否则运行时报路由找不到；传参用 `router.pushUrl({ url, params })`，目标页用 `router.getParams()` 取（返回 Object，需显式 as 转换，禁 any）。
15. **@Builder 默认「按值传递」，不能用来渲染需要跟随状态刷新的局部 UI**：多参数 @Builder 的参数在首次渲染时被拷贝，状态变量之后改变**不会**触发其内部 UI 刷新。症状是「列表已按新条件筛选，chips 高亮却停在初始值」，看起来像两套独立逻辑（因为列表在 build 里直连状态，@Builder 里的没有）。凡需随状态刷新的局部 UI 一律拆成独立 `@Component` 子组件，用 `@Prop`/`@Link` 绑定父组件状态；ForEach 项内部还依赖外部状态时，把该状态纳入键值生成函数以确保节点重建。
16. **`TabContent.tabBar()` 只接受 `string | Resource | CustomBuilder | TabBarOptions`**（SDK `tab_content.d.ts` 实测），**不能直接放入自定义组件**用 `@Prop` 绑定。所以底部标签的选中态只有两条路：① 维持 @Builder 并在其内部**直读**状态（`this.currentIndex === index`，禁止把选中态做成参数）；② 换 `SubTabBarStyle`/`BottomTabBarStyle` 等平台托管样式。别为了「优雅」把标签改成参数化子组件，那会直接复现第 15 条的高亮失灵。
17. **整表解析「返回空数组」≠「加载成功」**：解析入口为健壮性 catch 住 JSON.parse 错误返回 `[]` 是对的，但**加载入口必须把「整表 0 条」转为抛异常**，否则「加载失败」被静默成「空数据」——上游 catch 不到，预览器的 mock 注入永不触发，页面只显示「预置数据为空」（M1.6 重构时抽出的 `parseHeritageList` 吞掉了 M1.5 原本会传播的 parse 异常，导致预览器列表全空）。规则：逐条容错（单条非法跳过）在解析层，整表失败判定（0 条即抛）在加载层，且空结果**不入缓存**。
18. **凭记忆/凭旧文档写 SDK API 会直接编译失败（M3.1 实测）**：网上旧版 OpenHarmony 文档（API 9/10 时代）与当前 HarmonyOS NEXT SDK 已有漂移。distributedKVStore 实测：`SecurityLevel` 枚举**无 S0**（最低 S1）、`SingleKVStore` **无 putSync/deleteSync/getSync**（仅 Promise 形式 put/delete/get）。规则：用不熟悉的 kit 前，先查本机 SDK d.ts 确认真实签名与枚举成员（`E:\DevEco Studio\sdk\default\openharmony\ets\api\@ohos.*.d.ts`，Grep 方法名即可），编译错误信息也会直接给出正确线索。
19. **ArkTS 模板字符串内嵌 JSON 时，字符串值内的 `\n` 会在求值后变成真实换行，导致 JSON.parse 抛「Bad control character」（M1.7 实测）**：MockHeritages 用反引号模板字符串存 JSON 文本（走唯一解析入口保证 R3 双份一致），写入多段正文时在 JSON 字符串值内用 `\n` 分段——但模板字符串求值时 `\n` 被解释为真实换行符，JSON 规范不允许字符串内裸换行，`JSON.parse` 直接抛错 → `MOCK_HERITAGES` 为空数组 → 预览器显示「暂无数据 + 预置数据解析失败」（rawfile 是纯 .json 文件、`\n` 为字面转义合法，故真机/模拟器正常，只有走 mock 的预览器全空）。规则：**模板字符串内嵌的 JSON 文本，字符串值内分段必须写 `\\n`（双反斜杠），不要写 `\n`**；排查「预览器空但真机正常」时优先怀疑 mock 数据的解析失败，可用 Node 模拟「模板求值（把 \\n 还原成 \n）后再 JSON.parse」来复现。
20. **`layoutWeight` 在无高度约束的容器里会把子组件无限撑高（M1.7 事件页签实测）**：Column 未限定高度时，其内 `Line().layoutWeight(1)` 的竖线被分配到「无限剩余空间」而无限拉伸，连带外层 Row 一起被拉高——时间轴每个条目因此被撑到 280pt+，条目间出现大段空白（截图实测单屏仅 1.5 条）。规则：**`layoutWeight` 只应用于主轴方向有明确约束（父容器固定/占满）的场景**；需要「连接线」时不要用无约束容器里的 layoutWeight，改用内容驱动的分隔（Divider/固定小高度），或给容器显式高度。
21. **rawfile JSON 正文内嵌引号误用 ASCII 双引号 `"` 会提前闭合字符串，导致 JSON.parse 失败（M1.7 偃师商城深写实测）**：编写 rawfile/heritage_data.json 的事件正文时，把「面朝后市、择中立宫、对称布局」误写成 `"面朝后市..."`（ASCII 引号），字符串在引号处提前闭合，`ConvertFrom-Json`/`JSON.parse` 直接抛 SyntaxError，且 PowerShell 校验报错定位在「column 104」这类误导性位置。规则：**rawfile 与 mock 的 JSON 文本中，正文内嵌引号一律用中文引号「」**（本项目惯例），禁止在字符串值内使用 ASCII 双引号；每批写完先用 PowerShell `ConvertFrom-Json` 校验 rawfile、用 Node 模拟模板求值校验 mock，把 JSON 语法错误拦截在双份同步脚本之前（本次即被 mock 生成脚本的 JSON.parse 首先发现）。

### 6.1 当前阶段遗留问题 / 风险（M2 开工前必须逐一清零）

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
- O3 `hilog` DOMAIN 统一用 0x0000（测试域）。**构建告警基线已固化（2026-09-27 实测更新，仅允许以下 11 条 + 1 条签名提示）**：
  `data/HeritageDataLoader.ets:39 Function may throw exceptions`（getRawFileContent）、
  `pages/Discovery.ets:307 'pushUrl' has been deprecated`、
  `pages/Favorites.ets:525 'pushUrl' has been deprecated`（M2.2 新增，与发现页 pushUrl 同类型的既有技术债，无新增告警类型）、
  `pages/Detail.ets:46 'getParams' has been deprecated`、
  `pages/Detail.ets:109 'back' has been deprecated`、
  `pages/Detail.ets:264 'pushUrl' has been deprecated`（M2.4 新增，router deprecate 同类型；pushUrl 已收敛为唯一调用点 openNoteEditor 且包 try/catch）、
  `pages/NoteEdit.ets:55 'getParams' has been deprecated`（M2.3 新增，router deprecate 同类型）、
  `pages/NoteEdit.ets:140 'back' has been deprecated`（M2.3 新增，back 已收敛为唯一调用点 goBack()）、
  `pages/Favorites.ets:226 'pushUrl' has been deprecated`（M2.5 新增，openMyNotes 入口，router deprecate 同类型）、
  `pages/MyNotes.ets:125 'pushUrl' has been deprecated`（M2.5 新增，openDetail 收敛唯一调用点）、
  `pages/MyNotes.ets:133 'back' has been deprecated`（M2.5 新增，goBack 收敛唯一调用点），外加 `SignHap: skip sign 'hos_hap'（未配置 signingConfigs，命令行验证可忽略）`。
  行号随代码增删会漂移，比对以「文件 + 告警类型」为准。
  超出基线的告警一律视为新增问题，处理掉再提交。
- O4 Tabs 切走再切回发现页时筛选条件是否复位，待真机验证一次。
- O5 **预览器/模拟器的中文输入限制（环境问题，非代码问题）**：预览器软键盘是 DevEco 模拟的英文键盘，不支持中文输入法；模拟器物理键盘不支持中文（华为官方 FAQ），中文只能用鼠标点软键盘输入，且需在模拟器「设置 → 系统和更新 → 语言和输入法」把默认输入法设为小艺输入法。真机不受影响。已核对代码：Search/TextInput 未设置 type/inputFilter，无强制英文约束。检索功能的中文验证一律以模拟器（设好输入法）或真机为准。
  环境备注（2026-09-25）：模拟器 SDK（`C:\Users\Lenovo\AppData\Local\Huawei`，约 20 GB）因 C 盘空间不足，已用 robocopy 整体迁移至 `E:\Huawei`，原 C 盘路径为 NTFS Junction 联接（对 DevEco 透明，后续镜像下载/更新经联接直接落 E 盘）。排查环境问题时须知此联接存在；勿手动删除 E:\Huawei。
- O6 **模拟器偶现青绿色背景伪影（环境问题，非代码问题，2026-09-25）**：弹窗（如收藏页「管理标签」）等场景偶发大块青绿色背景（GPU 合成占位色），特征为「一帧出现、任意下一步操作后消失、不操作则一直停留」、色块边界为斜线且部分遮挡正常内容。已全库 Grep 确认代码调色板无任何青色（全程米白 `#FAF6F0` + 棕色系，弹窗遮罩为半透明深棕 `rgba(62,39,35,0.45)`），判定为 DevEco 模拟器渲染合成层未合帧/缓冲残留，真机不受影响；复现时重启模拟器即可，无需改代码。另备注：发现页顶部「N 处遗产」为**当前筛选结果数**（非遗产总数），与筛选 chips/列表同源联动，切换筛选即变化（用户曾误以为静态总数）。
- O7 **分布式同步验证环境限制（2026-09-26 确认，09-27 修正，09-27 实测闭环）**：用户无鸿蒙真机，仅有平板模拟器；有华为开发者账号并已登录 DevEco，但无签名知识（模拟器跑 debug 包不需签名，现阶段不涉及；真机联调时再配置自动签名）。**重要修正**：模拟器**可以登录华为账号**（实测：设置 → 华为账号可登录自有账号、云空间开关可打开），推翻了「模拟器无华为账号体系」的旧判断。**实测闭环（09-27）**：用 hdc 命令行绕过 IDE 运行会话限制，将 HAP 同时安装并启动到两台模拟器（Pura 90 Pro 手机 5555 / MatePad Pro 13 平板 5557，同账号 + 同 VirtWifi）——同步面板「在线设备」仍为 0 台，组网失败。根因：模拟器**无虚拟蓝牙硬件**（系统蓝牙开关置灰不可点，宿主机有 MediaTek 蓝牙但不透传），组网三件套缺蓝牙 → 设备发现失败。结论：**普通本地模拟器无法完成真实分布式组网**（此前为推测，现已实证），双向同步与 LWW 冲突联调以真机为最终依据（M3.4 清单 9 条）。附：DevEco 的多设备运行 = Device Manager 启动多个实例 → Run 配置「选择多个设备」勾选全部一次部署；「不允许并行运行 entry」是 IDE 运行会话限制（同一模块同一时刻 1 个会话），非设备限制；「选择多个设备」对话框不启动新设备；hdc 手动部署命令：`hdc -t <device> install <hap>`（绕过 IDE 会话限制的可靠方式）。

## 7. 验收标准（M1 阶段）

1. 工程编译零报错，模拟器可运行。
2. 数据模型类型完整、字段与任务书对齐（含 deviceId/updatedAt）。
3. 预置数据可被解析并在发现页列表展示。
4. 三维度筛选 + 关键词检索结果准确。
5. 详情页五层级内容完整，返回/跳转正常。

## 8. 开发工作流与 Git 规范

- **一次只做一个子任务**（如 M1.1 → 验证 → commit → 汇报 → 下一个）。
- **开工前先读第 6 节踩坑清单并逐条对照**：清单是硬约束，不是参考资料；反复踩同一个坑视为流程失误。
- **复杂代码先查官方文档（用户要求，2026-09-26 起硬性）**：凡涉及稍微复杂的代码与结构搭建——新 kit / 不熟悉的 API / 新架构接线 / 超过约 30 行的新逻辑——动手前**必须先查真实的官方文档、示例与教学**（华为开发者文档 + 本机 SDK d.ts 双重核对），确认 API 签名、枚举成员与官方推荐用法后再写。网上旧版 OpenHarmony 文档（API 9/10 时代）与当前 HarmonyOS NEXT SDK 存在漂移（踩坑 18 实测），**以本机 SDK d.ts 为最终依据**；官方示例的推荐模式（如 autoSync 与手动 sync 的搭配、dataChange 订阅时机）优先于自创写法。
- **同一文件禁止并行修改**：并发写同一文件会互相覆盖（曾导致踩坑第 14 条丢失），对同一文件的多次改动必须顺序执行，改完回读校验。
- 每完成一个子任务即 commit 一次，commit message 用 `[M里程碑.子任务] 摘要` 格式，如 `[M1.1] 新增数据模型(枚举+Heritage/Favorite/Note/SyncStatus)`。
- 同步更新本计划书的「里程碑状态」与「修订记录」。
- **计划书动态演进（用户授权）**：开发中发现需要新增子任务、展开实现细节、调整任务范围或顺序时，直接更新计划书并在修订记录写明理由，不必先请示；「改计划」优先于「绕过计划」。
- 编译验证优先：命令行 hvigor 或 DevEco Studio 构建；构建产物（.preview/.hvigor/build 等）不入库。
- **命令行构建命令**（M1.1 验证可用，PowerShell，于项目根目录执行）：

```powershell
$env:DEVECO_SDK_HOME='E:\DevEco Studio\sdk'
$env:NODE_HOME='E:\DevEco Studio\tools\node'
$env:Path='E:\DevEco Studio\jbr\bin;'+$env:Path
& 'E:\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

> 编译零报错判据：日志出现 `BUILD SUCCESSFUL`；`CompileArkTS` 无 ERROR。

## 9. 修订记录

| 日期 | 修订内容 |
|---|---|
| 2026-09-23 | 初始建立：计划书总纲 + M1 细分（M1.1~M1.5）+ 踩坑清单 + Git 规范 |
| 2026-09-23 | M1.1 完成（model 5 文件编译通过）；新增命令行构建命令实录 |
| 2026-09-23 | M1.2 完成：heritage_data.json（8 条真实遗址）+ HeritageDataLoader 解析；城市枚举增补「安阳」（殷墟所在地）；数据集规模策略：M1.2 抽样 8 条跑通管道，M1.4/1.5 后扩充至每市 3~5 条并补齐龙山年代段 |
| 2026-09-23 | 踩坑清单补充第 10~12 条（jbr 需入 PATH、PowerShell 分号、状态表回读校验） |
| 2026-09-23 | M1.3 完成：Index 改 Tabs（发现/收藏/同步，后两者占位）+ 新增 pages/Discovery.ets 列表页（加载中/失败/空三态兜底）；修复 Types.ets 遗漏的 HeritageCity.ANYANG 枚举成员（M1.2 数据先行导致编译阻塞）；getContext 已废弃，组件内改用 getUIContext().getHostContext() |
| 2026-09-23 | M1.3 增补：预览器无法读 rawfile，发现页加载失败时注入 mock 示例数据（顶部标注「示例数据」），真机不受影响 |
| 2026-09-23 | M1.4 完成：发现页加检索框（名称/简介子串匹配）+ 年代/类型/城市三维 chips 组合筛选（默认「全部」）+ 无结果兜底态；新增踩坑第 13 条（build 根节点前禁写语句） |
| 2026-09-23 | M1.5 完成：新增 pages/Detail.ets 五层级详情页（intro/discovery/events/poems/tourism 分区卡片，空层占位兜底），发现页卡片 router.pushUrl 传 id 跳转，详情页按 id 从 HeritageDataLoader 重新取数；mock 兜底数据抽至 data/MockHeritages.ets 并补齐五层级内容（发现页/详情页共用，预览器可调试详情）；新增踩坑第 14 条（router 目标页须注册 main_pages.json）。M1 里程碑全部完成 |
| 2026-09-23 | 修复发现页筛选失联：切换维度时列表已按条件筛选、chips 高亮却停在初始值（根因：@Builder 按值传递不随状态刷新）；筛选行改为独立 @Component 子组件 + @Prop 绑定父组件状态，三维度统一用 ALL_FILTER 空串哨兵表示「全部」，chips 高亮/结果计数/列表内容同源派生；新增踩坑第 15 条 |
| 2026-09-25 | 文档补充防重踩机制：文首加「开工前必读（硬性要求）」，第 6 节加「使用纪律 + 历史教训」，第 8 节工作流增列「开工前逐条对照踩坑清单」「同一文件禁止并行修改」两条硬约束 |
| 2026-09-25 | 新增 6.1「当前阶段遗留问题 / 风险」小节：R1~R4 为 M2 开工前必须清零项（缺龙山年代与数据集规模、加载无缓存、mock 双份数据漂移、@Builder 同族隐患），O1~O4 为观察项；M1 表增列 M1.6（数据集扩充 + 加载缓存） |
| 2026-09-25 | M1.6 完成（构建 BUILD SUCCESSFUL）：① heritage_data.json 由 8 条扩至 23 条真实遗址，年代/类型/城市全覆盖且每市 3~5 条，ConvertFrom-Json 校验无重复 id、无缺字段；② HeritageDataLoader 增进程内缓存 `cachedList`，并抽出唯一解析入口 `parseHeritageList(text, source)`；③ MockHeritages 改为 JSON 文本走同一解析入口，消除双份数据漂移；④ Index 的 TabLabel 加硬约束注释并新增踩坑第 16 条（tabBar 只接受 CustomBuilder）；⑤ 6.1 表 R1~R4 全部标 ✅ 并写明解决方式，O3 固化构建告警基线 |
| 2026-09-25 | 6.1「M2 前置清单」清零完毕，M2 可开工（M1 全部子任务 ✅） |
| 2026-09-25 | M2.1 完成（构建 BUILD SUCCESSFUL，告警维持 O3 基线零新增）：新增 service/FavoriteService.ets —— ① Preferences 持久化（getPreferencesSync/putSync/flushSync 全同步 API，实测 API 12 SDK 均存在），收藏/笔记各占一个整表 JSON 键 + device_id 键；② 内存缓存为唯一数据源，查询返回拷贝（收藏按时间倒序、笔记按更新时间倒序），变更同步落盘；③ 收藏 CRUD（toggle/add/remove/updateTags，取消收藏不级联删笔记——笔记为独立用户数据）；④ 笔记 CRUD（add/update/delete/getNotesByItem，空正文拒绝）；⑤ 标签管理（内置三标签常量 + getAllTags 内置∪使用中自定义 + removeTag 只清使用处）；⑥ deviceId 首次生成 UUID 持久化（踩坑 3：createdAt/updatedAt/deviceId 全自动维护，M3 直接复用）；⑦ 读回 JSON 逐字段显式转换 + 逐条 try/catch 跳过非法数据（踩坑 1/2/4）；⑧ Preferences 初始化失败降级纯内存不崩溃。页面接入留待 M2.2~M2.4 |
| 2026-09-25 | 修复 M1.6 引入的回归：预览器发现页/详情页列表全空（「预置数据为空」、mock 不注入）。根因：M1.6 抽出的 `parseHeritageList` 把 JSON.parse 异常 catch 成返回空数组，失败语义从「抛异常」变「返回空」，页面 catch 不到。修复：`loadHeritageList` 整表解析 0 条即抛异常且空结果不入缓存，恢复 M1.5 的失败传播语义；新增踩坑第 17 条（逐条容错在解析层、整表失败判定在加载层） |
| 2026-09-25 | 排查「搜索框只能英文输入」：核对代码（Search 未设 type/inputFilter）与 SDK（默认 SearchType.NORMAL），确认非代码问题，为预览器/模拟器环境限制（预览器软键盘仅英文、模拟器物理键盘不支持中文、软键盘需设默认输入法为小艺输入法）；记入观察项 O5，无代码变更 |
| 2026-09-25 | M2.2 完成（构建 BUILD SUCCESSFUL，告警维持 O3 基线仅 +1 条同类型 pushUrl deprecate）：新增 pages/Favorites.ets 并接入 Index 第 2 个 Tab —— ① 按标签分组列表（内置标签在前、自定义按首次出现顺序，「未分组」殿后，空分组不显示），卡片显示城市/年代徽标、名称、摘要、标签 chips（最多 3 个 +「+N」）、收藏时间、笔记数，点击统一带 id 跳详情（O2）；② ⋯ 菜单 → 管理标签（内置 + 使用中自定义 + 新增自定义标签，勾选保存走 updateFavoriteTags）/ 取消收藏（二次确认，文案注明笔记保留）；③ 弹层用页内 Stack + 条件渲染实现（状态集中于单组件规避踩坑 15），遮罩空 onClick 消费点击防穿透、一律显式按钮关闭，卡片主区域与 ⋯ 按钮为兄弟节点规避点击冒泡；④ 所有变更走 FavoriteService 后整体赋值刷新 groups（踩坑 5），FavoriteService.init 于 aboutToAppear 调用（幂等）；⑤ rawfile 加载失败时注入 MOCK_HERITAGES 建映射表（只读预览调试，与发现页行为一致）。验收说明：当前无收藏入口（M2.4 详情页收藏按钮未实现），本阶段可验证空态与编译，数据流联调留待 M2.4 完成后进行；届时需补 Index.onPageShow → 收藏页刷新机制（详情页收藏后返回收藏 Tab 不自动刷新） |
| 2026-09-25 | M2.4 收藏部分提前实现（应用户要求先做用户端验证；构建 BUILD SUCCESSFUL 零新增告警，仅 3 条基线告警行号漂移，O3 补充「行号漂移按文件+类型比对」规则）：① Detail.ets 顶部导航栏新增收藏按钮（未收藏白底棕字棕边 / 已收藏棕底白字，主次高亮清晰区分；@Builder 内部直读 isFav 规避踩坑 15），点击走 FavoriteService.toggleFavorite 同步切换；② aboutToAppear 幂等调 FavoriteService.init 并按 targetId 恢复 isFav 初值；③ 列表联动补齐（M2.2 遗留点）：Index.onPageShow → favoriteRefreshTick+1 → Favorites @Prop @Watch 触发 refreshGroups，从详情页收藏/取消收藏返回后收藏页自动刷新；④ 笔记入口仍待 M2.3 完成后接入，M2.4 保持 🚧 |
| 2026-09-25 | 计划书动态演进机制确立（用户授权）：文首与 §8 工作流新增条款——开发中发现需要新增子任务、展开细节、调整范围或顺序时，直接更新计划书并在修订记录写明理由，「改计划」优先于「绕过计划」 |
| 2026-09-25 | M2.3 完成（构建 BUILD SUCCESSFUL，O3 基线 +2 条 router deprecate 同类型告警，back 已收敛为唯一调用点）：新增 pages/NoteEdit.ets 并注册 main_pages.json（踩坑 14）—— ① 路由入参 { id, noteId? }，noteId 缺省新建、携带则编辑（按 noteId 从服务层重新取数回填，数据单一来源）；② 时间戳全自动维护：新建 addNote / 编辑 updateNote，页面不手写任何时间（踩坑 3），编辑模式展示「创建于/最后编辑」；③ 空正文 UI 层先行拦截（行内红色提示，输入即清除）+ 服务层双重保险；④ 删除走 deleteNote + 二次确认弹层（与收藏页同款 Stack 模式）；⑤ 预览器无参直接预览 = 新建模式仅可预览 UI，完整数据流验证需 M2.4 笔记入口接入。**M2.3 范围修订（动态演进首例）**：原「文字 + 自动时间戳 + 标签」中的标签职责归收藏维度（M2.2 已实现收藏标签管理），Note 模型不带 tags（M3 分布式同步保持轻量），本页聚焦纯文字编辑 |
| 2026-09-25 | M2.4 完成（构建 BUILD SUCCESSFUL，O3 基线 +1 条 Detail pushUrl deprecate；期间修复 1 次编译错误：对象字面量不能初始化 Record 类型变量，改内联进 pushUrl 调用；pushUrl 直接调用曾伴生 may throw 告警，包 try/catch 消除）：Detail.ets 新增「我的笔记」区块—— ① 五层级之后展示该条目笔记列表（正文 3 行截断 + 最后编辑时间，点击进 NoteEdit 编辑），区块头「+ 写笔记」入口（pushUrl 收敛为唯一调用点 openNoteEditor）；② onPageShow 刷新笔记列表与 isFav（从 NoteEdit 返回的同页实例即时联动，aboutToAppear 亦初始化）；③ 新建 utils/TimeFormat.ets（formatDate/formatDateTime 纯函数），Favorites/NoteEdit/Detail 三页共用，删除各自私有重复实现（§3 utils 层首个模块）。**M2 里程碑全部完成**，下一步 M3 分布式同步 |
| 2026-09-25 | 新增观察项 O6（环境问题）：模拟器偶现青绿色背景伪影——弹窗场景偶发 GPU 合成占位色块（一帧出现、交互后消失、不操作则停留、斜线边界）；全库 Grep 确认调色板无青色，判定为 DevEco 模拟器渲染合成未合帧，真机不受影响。同时澄清发现页「N 处遗产」为筛选结果计数（非总数），与筛选同源联动无需改动 |
| 2026-09-26 | M3 拆解为 M3.1~M3.4 子任务表（动态演进）并确定验证策略：用户无鸿蒙真机（仅平板模拟器，见新增 O7），按「代码实现 + 编译自测」为基线推进；模拟器仅可验证单机降级路径，真实双向同步需两台真机（同华为账号 + 同 WLAN + 蓝牙）联调留待设备到位。同时明确代码来源约定：API 用法对齐华为官方文档（distributedKVStore/distributedDeviceManager 接口名以官方为准），架构与业务逻辑为本项目自主设计（用户问询后确认） |
| 2026-09-26 | M3.1 完成（构建 BUILD SUCCESSFUL，告警与 O3 基线完全一致零新增）：① module.json5 声明 `ohos.permission.DISTRIBUTED_DATASYNC`（reason 走 $string 资源）；② 新增 service/SyncService.ets 骨架——单版本 KV（键 fav_{itemId}/note_{noteId}，值记录 JSON）+ autoSync + SUBSCRIBE_TYPE_REMOTE 订阅（本机 put 不自触发）、初始化失败降级纯本地（不崩溃不影响 M2 功能）、LWW 判定纯函数（updatedAt 胜，相等 deviceId 字典序小者胜保证两端收敛）、conflictLog 台账（上限 50 丢最旧）+ getStatus 快照、远端变更解析为 RemoteChanges 事件（监听者注册接口留给 M3.2 接线）、线格式逐字段显式转换（踩坑 1/2/4）；③ FavoriteService.init 幂等激活 SyncService.init（行为不变，双写留 M3.2）。期间实测 2 个 SDK 漂移（SecurityLevel 无 S0、无 putSync）致一次编译失败，已查 d.ts 修正并新增踩坑第 18 条 |
| 2026-09-26 | 新增工作流硬性规则（用户要求）：凡稍微复杂的代码/结构搭建（新 kit、不熟悉 API、架构接线、较大新逻辑）动手前必须先查真实官方文档、示例与教学，并与本机 SDK d.ts 双重核对，官方推荐模式优先于自创写法（与踩坑 18 配套） |
| 2026-09-26 | M3.2 完成（构建 BUILD SUCCESSFUL，告警与 O3 基线一致零新增，仅 Detail 3 条行号漂移）：FavoriteService 双写改造—— ① 7 个变更方法（收藏增/删/改标签/删标签 + 笔记增/改/删）在内存缓存 + Preferences 之后上抛 SyncService（降级时空操作，本地不受影响）；② mergeRemoteChanges LWW 合并（远端新增直接采纳；双端版本不同走 lwwRemoteWins，远端胜替换+记台账，本机胜保留并回写 KV 让对端收敛；远端删除按「删除生效」简化——删除通知无时间戳可比，注释说明取舍）；③ init 注册合并处理器（重入只注册一次）+ onDataChanged/offDataChanged 页面通知 API；④ UI 联动：Index.aboutToAppear 提前 init（防 TabContent 懒加载导致合并处理器注册过晚）并订阅刷新信号，Detail 订阅/注销（aboutToDisappear 防泄漏）刷新收藏状态与笔记列表。开工前已按新规则核对官方「跨设备同步 KV Store」指南：单版本 KV 官方语义即「同键多端修改以最新为准」（与应用层 LWW 一致）、put/delete 成功即触发 autoSync（双写无需逐次手动 sync）、手动 sync(deviceIds, PUSH_PULL) 留作 M3.3 面板入口 |
| 2026-09-26 | M3.3 完成（构建 BUILD SUCCESSFUL，告警与 O3 基线完全一致零新增）：① SyncService 扩展——getOnlineDevices（DeviceManager 懒创建 + 失败熔断 + getAvailableDeviceListSync，d.ts 实测仅需已声明的 DISTRIBUTED_DATASYNC 权限，无新增权限）、manualSync（在线设备 PUSH_PULL，无设备/降级返回 false）、onStatusChanged/offStatusChanged 状态通知（远端变更/同步完成/设备上下线触发）、subscribeSyncComplete（KV ready 后订阅，同步完成刷新 lastSyncTime）、subscribeDeviceStateChange（设备上下线刷新面板）；② 新增 pages/SyncPanel.ets 并接入 Index 第 3 个 Tab（PlaceholderTab 占位删除）：同步状态卡（服务状态/进度条/最后同步/在线设备/冲突数四行 + Progress 组件）、在线设备卡（列表或「等待设备上线」组网提示）、手动同步卡（立即同步按钮 + 降级文案：单机模式本地仍保存）、冲突记录卡（明细列表含 LWW 保留结果说明）；aboutToAppear 订阅刷新 + aboutToDisappear 注销防泄漏。distributedDeviceManager 事件回调采用零参函数（结构兼容官方匿名对象签名，避免 ArkTS 类型坑）。模拟器预期表现：服务状态「单机模式」、0 台设备、从未同步（O7） |
| 2026-09-26 | M3.4 完成，**M3 里程碑全部完成**（收口构建 BUILD SUCCESSFUL，告警与 O3 基线完全一致）：① 真机联调操作清单 9 条写入计划书 M3 小节（签名自动生成配置/组网三件套/同签名同 bundleName 安装/双向同步/手动同步/LWW 冲突/删除同步/重启持久化/降级回归）；② conflictLog 持久化评估结论：**保持内存态不持久化不同步**——冲突日志是本端诊断信息非用户数据，同步它自身会引入复杂度与循环风险，重启清零可接受；③ M3 全阶段复检：SyncService 全文重读（初始化→订阅→双写→合并→面板 API 链路无断点）、FavoriteService 16 处接线逐一核对（7 变更方法双写 + 合并注册 + LWW 两段 + 冲突台账）、BUNDLE_NAME/STORE_ID/键前缀与 app.json5 及各调用点一致、头注释过期描述修正 |
| 2026-09-27 | O7 实测闭环：hdc 绕过 IDE 会话限制将 HAP 同时装到两台模拟器（同账号同 WLAN），同步面板「在线设备」仍 0 台——根因模拟器无虚拟蓝牙硬件（宿主机 MediaTek 蓝牙不透传），组网三件套缺蓝牙；结论：普通本地模拟器无法真实分布式组网（由推测转实证），双向同步以真机为准。附记 hdc 手动部署命令为绕过 IDE 会话限制的可靠方式 |
| 2026-09-27 | M2.5 完成（体验补强，动态演进新增子任务，构建 BUILD SUCCESSFUL，O3 基线 +3 条 router deprecate 同类型至 11 条）：新增 pages/MyNotes.ets 并注册 main_pages.json（踩坑 14）——按遗址聚合全部笔记（遗址名 + 笔记数 + 最后编辑时间，按最后编辑倒序），点击直达详情页（统一带 id，O2），onPageShow 刷新；收藏页顶部新增「📝 我的笔记 N 条」入口卡（openMyNotes try/catch 收敛），noteCount 随 refreshGroups 更新。解决「未收藏遗址写了笔记后难以找回」的体验缺口（用户反馈） |
| 2026-09-27 | M4.0 完成（详情页信息架构与视觉改版，动态演进：用户反馈详情页简陋，方案经确认 A 布局重构版 + 年代主题色；构建 BUILD SUCCESSFUL，告警回到 O3 基线 11 条零新增——期间实测 Circle.fill/stroke 需 SDK 26 超出兼容版本 16 产生 2 条新告警，改用「等宽高+半宽圆角+白描边 Column」通用写法消除）：① 新增 utils/EraTheme.ets——六年代主题色系统（仰韶彩陶红/龙山黑陶灰/夏商青铜绿/周玄青/汉唐鎏金赭/宋青瓷，deep/mid/soft 三档 + 默认棕兜底，克制低饱和，取色自各年代代表器物形成文化隐喻）；② Detail.ets 重构——英雄横幅（年代渐变 deep→mid 135° + 大号名称 + 半透明白底徽标 + 简介白字）、五层级+笔记改 Tabs 顶部页签（SubTabBarStyle.of 两字页签 × 6：介绍/考古/事件/诗词/文旅/笔记，横幅常驻页签内容各自滚动，官方推荐信息分类方式）、历史事件时间轴（正则解析「XXXX年：」前缀年份主题色高亮 + 竖线节点 + 末项无竖线）、诗词古风卡（soft 浅底 + 标题作者居中 + 分隔线 + 引文行距 30）；M2.4 收藏按钮/笔记列表/onPageShow/onDataChanged 监听等业务逻辑原样保留。B/C 档（数据字段增强/图片资源）经用户确认暂不做 |
| 2026-09-27 | **M4.0 后用户复验反馈「UI 可以但信息严重缺失」**（截图实测：介绍 4 行/考古 85 字/事件 2 条/诗词全空/文旅 3 行，各页签 60-75% 空白）——根因是 M1.2/M1.6 数据集为精简占位级内容，非官方资料全部；据此启动 M1.7 数据集深度扩充（用户确认：样本先行 + 深内容新字段）：**动态演进解除「M1 后数据结构冻结」约定**（字段只增不改，存量语义不变，解析缺失兜底空数组向后兼容）——① 模型加 highlights（核心看点）/specs（遗址档案键值 SpecItem）/artifacts（代表性出土文物 Artifact）三字段；② Loader 增 getSpecArray/getArtifactArray 逐字段显式转换（无名称项跳过）；③ 仰韶村样本条目全深度重写：intro 224→446 字（三段）、discovery 173→372 字（四次发掘）、events 3→7 条、tourism 扩充、highlights 5 条、specs 8 项、artifacts 4 件；④ MockHeritages 仰韶村条目同步（R3）；⑤ Detail.ets：介绍页签 = 看点 chips + 正文 + 遗址档案卡，考古页签 = 正文 + 代表性出土文物卡，诗词空态文案区分。**内容来源约定**：扩充内容由 AI 基于公开资料整理，具体数字建议正式使用前用官方资料抽查校对。构建 BUILD SUCCESSFUL |
| 2026-09-27 | **M1.7 回归修复**（用户反馈「预览器什么也看不到」：发现页「暂无数据 + 预置数据解析失败」0 条）：根因为踩坑 19——MockHeritages 的 MOCK_JSON 模板字符串内，仰韶村样本多段正文用了 `\n` 分段，模板求值后变真实换行 → JSON.parse 抛错 → MOCK_HERITAGES 空数组 → 预览器注入空 mock 全空（rawfile 纯 .json 文件不受影响，真机/模拟器正常）。修复：MOCK_JSON 字符串值内 `\n` 全部改为 `\\n`（求值后得字面 \n，JSON 合法转义）；Node 模拟「求值+JSON.parse」验证通过（4 条、intro 3 段），BUILD SUCCESSFUL。新增踩坑第 19 条；顺带清理排查用临时脚本（不入库）。M1.7 样本仍 🚧 待验收 |
| 2026-09-27 | **诗词栏目移除（真实联网核证后决策）+ 时间轴空隙优化**（用户反馈：时间轴跨年留白大、诗词栏几乎全空且怀疑未联网搜索）：① 诚实承认此前诗词为精简数据自写，未联网；本次真实搜索核证——殷墟有郭沫若 1959《访安阳殷墟》（洹水安阳名不虚，三千年前是帝都）、二里头有河南诗人董林《二里头遗址短章》（河南省文旅厅/文物局官方转载），而仰韶村/虢国墓地/商城等考古遗址基本无古代传世诗词（仰韶文化早于文字）。② 据此采纳用户方案：**删除详情页「诗词」页签**（6 Tab 变 5：介绍/考古/事件/文旅/笔记），有真实诗词的遗址改为**在 intro 末尾合理引用一句 + 注明出处**——殷墟补郭沫若句、二里头补董林句（rawfile 与 Mock 同步，R3）；poems 字段保留于模型（只增不改、UI 不再渲染）并清空残留数据。③ 时间轴条目间距 16→10 压缩（缓解稀疏遗址的空旷感），事件数随 M1.7 深写增至 5~8 条后自然饱满。BUILD SUCCESSFUL 告警零新增 |
| 2026-09-27 | **事件页签空旷根因修复（用户复验仍空旷 + 质疑死数字/设备适配）**：真因非间距数值，而是**时间轴竖线用 `layoutWeight(1)` 在无高度约束的 Column 内被无限撑高**，把每个条目 Row 拉到 280pt+（截图实测单屏仅 1.5 条）。重写 TimelineTab 为**纯内容驱动**布局：删除竖线/圆点轨道，改「年份主题色徽标 + 正文换行自适应（layoutWeight 吃满宽度）」一行 + 条目间 Divider 分隔——高度完全由文字决定（内容多自然变高、少则紧凑收拢），宽度自适应平板/手机；事件 <4 条时底部显示「更多考古进程正在整理中」语义收尾，把留白变说明。ArkUI 的 vp 为设备无关单位，配合 layoutWeight 天然适配不同设备。BUILD SUCCESSFUL 告警零新增 |
| 2026-09-27 | **产品定位确立（用户明确，最高优先级）**：应用是**沉浸式文化遗产体验**产品，非精简数据知识库。三大硬性要求写入 §1：① 信息量 = 现状 10 倍，内容必须联网搜索官方/权威来源核证，**禁止凭记忆写精简数据**（凡 AI 草拟内容一律视为「待官方核证草稿」，交付前经搜索比对）；② **事件可点开**——遗址详情页每个事件点击进事件子详情页做专题讲解（背景/经过/影响/相关人物文物/延伸阅读，新增子任务 M1.8，events 升级结构化对象）；③ **文旅深度化**——含行程规划（路线/时长/交通/串联景点）、参观指引（开放时间/票务）、深度解说。23 条遗址 × 10 倍按遗址分批联网搜证扩充（每批用户抽查校验），M1.7 扩编为此目标并 🚧。同时补踩坑第 20 条（layoutWeight 无高度约束撑高） |
| 2026-09-27 | **M1.8 完成 + 仰韶村首批联网搜证深写（构建 BUILD SUCCESSFUL，告警维持 O3 基线 11 条零新增）**：① 事件子详情页全链路——model/Heritage.ets 新增 `HeritageEvent` 接口（year/title/summary/background/process/impact/figures/artifacts/furtherReading），HeritageDetail.events 由 `string[]` 升级为 `HeritageEvent[]`（模型只增不改，旧字符串数据加载层正则自动迁移）；Loader 增 `getEventArray` 逐字段显式转换（title 空跳过）；Detail.ets 时间轴改结构化渲染、条目可点击 → `openEventDetail(index)` 经 router.pushUrl 带 { heritageId, eventIndex } 跳转；新建 pages/EventDetail.ets 事件专题页（按 id 重新取数 + getEraTheme 年代渐变英雄横幅 + 背景/经过/影响三段 + 人物 chips + 文物卡 + 延伸阅读出处，越界返回 null 不崩溃）并注册 main_pages.json（踩坑 14）；② **仰韶村深写全部来自联网搜证的官方/权威来源**（渑池县政府 3 篇/河南省文物局/河南省政府门户/三门峡市政协网/北京青年报/国家文物局年报/实探攻略，每条事件 furtherReading 注明出处）：intro 4 段（~1300 字，位置命名/仰韶文化定义/考古学意义/彩陶与小口尖底瓶酿酒说）、discovery 5 段（1920 刘长山 600 余件石器 → 1921 首发掘 36 天 17 点袁复礼绘中国第一张田野考古地形图 → 1951 夏鼐驳「西来说」 → 1980—1981 第三次 → 2020 第四次多学科 → 2021 象牙镯+发酵酒丝蛋白/2022 大型房址壕沟/2024 遗传连续性先民面貌复原）、events 8 条结构化对象（各含完整 background/process/impact/figures/artifacts/furtherReading）、tourism 4 段（概览+【参观指引】博物馆 9:00-17:00 周一闭馆免费 0398-3068878+【行程规划】2.5-3.5 小时动线+观光车 10 元+【深度解说·看什么怎么看】）、highlights 8 条/specs 12 项/artifacts 6 件；③ MockHeritages 仰韶村 mock 条目与 rawfile 完全同步（R3，模板字符串值内分段 `\\n` 守踩坑 19，events 8 条单行 JSON）；④ rawfile 23 条/mock 4 条双份 JSON 校验通过。**用户验证通过后**按遗址分批联网搜证深写其余 22 条（每批用户抽查） |
| 2026-09-27 | **M1.9 完成（文旅深度化迭代，用户复验反馈「事件详情页信息仍精简 + 文旅页签 UI 太简陋」；构建 BUILD SUCCESSFUL，告警维持 O3 基线零新增）**：① 模型——tourism 由 string 升级为 TourismInfo（overview/guide{hours,tickets,contact,address}/itinerary/interpretation），Loader `getTourism` 旧字符串自动迁移为 overview、guide 子对象逐键转换（无 keys 兜底空串），UI 按结构化卡片渲染；HeritageEvent 新增 commentary（深度解说），加载层两分支兜底空串；② UI——Detail.ets 删除通用 BodyTab，文旅页签改 TourismTab 卡片化（概览正文 → 参观指引信息卡（主题色标签键值行）→ 行程规划段落卡（`\n` 分段 + 主题色竖块锚点）→ 深度解说卡（soft 浅主题底，与白卡主次区分），空块隐藏、全空占位）；EventDetail.ets 新增「深度解说」soft 底段落渲染 commentary；③ **仰韶村二轮联网搜证**（国家文物局官网陈星灿《中国考古学百年成就》/新华网百年纪念与发酵酒报道/河南省文旅厅第四次发掘成果发布/河南省文物局工作站研学基地/河南日报酿酒史/渑池县政府博物馆简介与 2024 开馆公告/国家文物局年报）：8 条事件全量补 commentary 与 furtherReading 出处（1921 补 12 月 1 日结束口径/4 月住 8 天 4 木箱/安特生旧居王二保窑洞/陈星灿评价；1923 补《甘肃考古记》《河南的史前遗址》/远东古物博物馆/疑古思潮与王巍本土起源论；2021 重点补玉钺=军事王权、玉环=红山风格证中原-东北交流、玉璜玛瑙彩绘陶橡子果核首现、酿酒=斯坦福合作 8 尖底瓶残留谷芽酒+曲酒两工艺/甲骨文酒醴对照、丝绸=14 土样 2 个检出丝蛋白/刘海旺养蚕缫丝论、习总书记贺信）；④ tourism 结构化深写——参观指引含 2024-09-24 全新开馆公告/免费无须预约/三级博物馆/关肇业设计"从黄土地里长出来的博物馆"/球幕影院裸眼3D 等数字化设施，行程规划含馆藏 800 余件展出 695 件/联动仰韶酒庄/仙门山/黄河丹峡，深度解说按地层/彩陶/聚落/百年考古四看；⑤ specs 配套场馆升级"国家三级博物馆"、artifacts 小口尖底瓶 desc 补酿酒实证；⑥ rawfile 23 条/mock 4 条双份 JSON 校验通过（mock 其余遗址 tourism 走旧字符串迁移路径验证） |
| 2026-09-27 | **M1.10 完成（遗址图片框架：真实图片占位 + 点击放大，动态布局；构建 BUILD SUCCESSFUL，告警维持 O3 基线零新增）**：① 实测官方图片 URL 经搜索代理缓存（aka.doubaocdn.com）返回 404 **不可下载**、无法核证版权 → 按用户退路指令「结构先行、图片待填」；② 模型新增 HeritageImage（path/caption/source），HeritageDetail/HeritageEvent 各加 images 数组（缺失兜底空数组，字段只增不改），Loader `getImageArray` 逐字段显式转换（path 与 caption 全空项跳过）；③ 新增 components/ImageGallery.ets（目录约定新增 components/ 层）——**动态布局**：Flex wrap 每行 3 列缩略图（宽度 32% 百分比自适应 + aspectRatio 等比 + 图注/来源小字）；**点击缩略图 → Lightbox 全屏放大**：bindContentCover 页面级遮罩（不被 Scroll 裁剪，d.ts 核证 ContentCoverOptions）、深色遮罩、大图 objectFit Contain 动态适配、✕ 关闭、多图左右切换 + 页码、底部图注/来源；图片用 resourceManager.getRawFileContent → image.createImageSource(buf).createPixelMap() 动态加载 rawfile → Image(PixelMap)（@kit.ImageKit，d.ts 核证 createImageSource(buf: ArrayBuffer)/createPixelMap 均存在）；path 空或加载失败 → 虚线占位卡（+「图片待补充」+ 建议来源）；④ 接入：Detail 考古页签「遗址图集」卡 + EventDetail「图集」段；仰韶村填 4 张遗址级占位 + 1921（地形图/安特生旧居）、2020（混凝土地坪）、2021（象牙镯/玉钺）事件级占位；⑤ 实测修正：ClickEvent 无 stopPropagation（d.ts 核证）→ Lightbox 弃用「点遮罩关闭」改为仅 ✕ 显式关闭，避免箭头/大图被冒泡误关；⑥ rawfile 23 条/mock 4 条双份 JSON 校验通过（detail.images 4、events with images 1921/2020/2021）；⑦ §1 产品定位追加硬性要求 4「考古内容配真实图片」，新增 §1.1「内容深写与搜证方法论」（搜证来源优先级/核证纪律/事件与文旅深写结构/双份同步纪律/图片资源现状）——后续每批遗址深写按此执行；真实图片待用户提供/稳定渠道获取后填入 rawfile（填入 path 即自动显示） |
| 2026-09-27 | **M1.7 第二批虢国墓地深写完成（构建 BUILD SUCCESSFUL，告警维持 O3 基线零新增；仰韶村首批已由用户验证通过）**：按 §1.1 方法论联网搜证（河南省人民政府门户/省文化和旅游厅/省文物局/国家文物局官网/省文物考古研究院/河南博物院/央视新闻/虢国博物馆官网/三门峡市政府/中国文物报等，关键数字多来源核证一致）——intro 4 段（位置与 32.45 万㎡/虢国史东西二虢与假虞灭虢/两次发掘与荣誉/「中华第一剑」等看点）、discovery 5 段（1955 黄河水库工作队与 1956-57 第一次发掘 234 墓/1956 车马坑 5 车 10 马原地保护与领导人视察/1990-99 第二次发掘虢季虢仲墓/虢季墓 M2001 随葬 5293 件颗与玉柄铁剑/虢仲墓 M2009 玉器之最与上阳城都墓互证）、events 8 条结构化（1956/1956—1957/1990/1991/1996/2000/2001/2021—2023，各含背景经过影响人物文物延伸阅读与深度解说，3 条带图占位）、tourism 四卡（虢国博物馆 周二至周日 9:00—17:30 周一闭馆/全票 40 元/0398-2282118/六峰北路 + 动线 2—3 小时 + 五看解说）、highlights 8/specs 12/artifacts 6/images 4 占位；Mock 新增 mock-guoguo-01 与 rawfile **字段级完全同构**（R3，用临时 Node 脚本从 rawfile 生成插入，免手工转写转义错误，脚本用毕删除不入库）；rawfile 23 条/mock 5 条双份校验通过（PowerShell ConvertFrom-Json + Node 模拟模板求值 + 逐字段同构比对） |
| 2026-09-27 | **M1.7 第三批二里头遗址深写完成（构建 BUILD SUCCESSFUL，告警维持 O3 基线零新增；用户已验证虢国墓地「效果非常好」）**：按 §1.1 方法论联网搜证（人民日报/国家文物局官网「考古中国」发布会与十大考古新发现页/河南省文物局/省文化和旅游厅/洛阳市文物局/洛阳日报/映象网/央视网/二里头夏都遗址博物馆官网/文化和旅游部官网等）——intro 4 段（位置与 300 万㎡/「最早的中国」与广域王权国家/发现发掘与「中国之最」/今天与董林诗句）、discovery 5 段（徐旭生 1959「夏墟」调查/三代考古人接力与夏鼐 1977 命名「二里头文化」/宫殿区与中国最早宫城 10 万余㎡/「井」字形大道与多网格式布局/手工业作坊与绿松石龙形器 64.5 厘米）、events 8 条结构化（1959/1959—1970 年代/2001—2004/2002/2011/2019/2021/2022—2023，各含背景经过影响人物文物延伸阅读与深度解说）、tourism 四卡（二里头夏都遗址博物馆 周二至周日 9:00—17:00 周一闭馆/免费持身份证/0379-65091800/斟鄩大道 1 号 + 动线 2.5—3.5 小时 + 五看解说）、highlights 8/specs 12/artifacts 6/images 4 占位；**核证纪律实例**：旧数据「龙形器约 70 厘米」与官方口径 64.5 厘米冲突，按最新官方口径（河南省文物局/新华社/央视）修正为 64.5 厘米；绝对年代采用国家文物局 2022 发布会口径（公元前 1750—前 1530 年）；Mock 的 mock-erlitou-01 由精简旧版替换为深写版并与 rawfile **字段级完全同构**（R3，临时 Node 脚本生成替换，脚本用毕删除）；rawfile 23 条/mock 5 条双份校验通过（PowerShell ConvertFrom-Json + Node 模拟模板求值 + 逐字段同构比对） |
| 2026-09-27 | **M1.7 第四批龙门石窟深写完成（构建 BUILD SUCCESSFUL，告警维持 O3 基线零新增）**：按 §1.1 方法论联网搜证（龙门石窟研究院官网/河南省人民政府门户（省文旅厅）/洛阳市文化广电和旅游局/洛阳日报/央广网/央视新闻/新京报/河南日报/中国文化报等）——intro 4 段（位置与伊阙地貌/北魏至宋 400 余年开凿与「中原模式」/规模 2345 窟龛 10 万余尊 2860 余品碑刻与世界遗产评价/今天与白居易香山文脉及数字化保护）、discovery 5 段（北魏始凿与宾阳中洞/唐代高潮奉先寺卢舍那大佛/书法碑刻龙门二十品与伊阙佛龛碑/佛教宗派与香山白园文脉/保护与数字化）、events 8 条结构化（493 年始凿/500—523 宾阳中洞/672—675 奉先寺武则天脂粉钱/唐代白居易修香山寺/1961 国保/1971—1974 首次大修/2000 世遗/2021—2022 奉先寺 50 年最大保护工程）、tourism 四卡（全价 90 元半价 45 元一票制/夏令时 8:00-18:00 冬令时 8:00-17:00 夜游龙门约 3 月底起/公众号实名预约/龙门大道 + 动线 3—4 小时 + 五看解说）、highlights 8/specs 12/artifacts 6/images 4 占位；**数据纪律实例**：碑刻题记采用省政府门户 2026 口径 2860 余品（龙门官网 2800 余块，冲突按最新官方口径）；残留的未经核证白居易诗（poems）按 M1.7-调整决策清空，白居易史实（修香山寺/九老会/香山居士/白园）改经核证后写入正文；Mock 新增 mock-longmen-01 与 rawfile **字段级完全同构**（R3，临时 Node 脚本生成插入，脚本用毕删除）；rawfile 23 条/mock 6 条双份校验通过（PowerShell ConvertFrom-Json + Node 模拟模板求值 + 逐字段同构比对） |
| 2026-09-27 | **M1.7 第五批殷墟深写完成（构建 BUILD SUCCESSFUL，告警维持 O3 基线零新增）**：按 §1.1 方法论联网搜证（安阳市文物局/安阳市人民政府门户/河南省文物局/省文化和旅游厅/国家文物局/中国国家博物馆/光明日报/央广网/郑州晚报/河南日报/故宫博物院等）——intro 4 段（位置与「大邑商」及《史记》两见殷墟/甲骨文与信史及郭沫若诗/近百年考古与青铜文明/今天世遗记忆名录与博物馆新馆）、discovery 5 段（王懿荣发现甲骨文/科学发掘三阶段与后冈三叠层/宫殿宗庙 53→100 余座基址/王陵 13 座大墓与洹北商城/甲骨窖穴与重器）、events 8 条结构化（1899 甲骨文发现/1928 第一次科学发掘/1936 YH127 出土 17096 片/1939 后母戊鼎/1961 国保/1976 妇好墓/2006 世遗/2024 博物馆新馆）、tourism 四卡（殷墟博物馆新馆 8:30—17:30 全年无休/门票 80 元实名预约/0372-5993308/纱厂路西段 + 动线 3—4 小时 + 五看解说）、highlights 8/specs 12/artifacts 6/images 4 占位；**数据纪律实例**：后母戊鼎重量省文物局口径 875 公斤（约数）vs 中国国家博物馆精确口径 832.84 千克，取国博权威精确口径并保留说明；甲骨单字 4500 余个、甲骨约 16 万片、妇好墓随葬品 1928 件（青铜 468 玉 755）等多来源一致；Mock 的 mock-yinxu-01 由精简旧版替换为深写版并与 rawfile **字段级完全同构**（R3，临时 Node 脚本生成替换，脚本用毕删除）；rawfile 23 条/mock 6 条双份校验通过（PowerShell ConvertFrom-Json + Node 模拟模板求值 + 逐字段同构比对） |
| 2026-09-27 | **M1.7 第六批郑州商城深写完成（构建 BUILD SUCCESSFUL，告警维持 O3 基线零新增）**：按 §1.1 方法论联网搜证（河南省文化和旅游厅/省文物局/省发改委/郑州市文物局/郑州市人民政府门户/河南博物院/人民日报海外版/中国文化报/大河网/郑州日报等）——intro 4 段（位置与「亳都」三重城垣/「内城外郭」布局与城址不移/韩维周安金槐发现史与郑亳说定论/荣誉与新发现金覆面）、discovery 5 段（1950 韩维周发现二里岗/1955 安金槐确认城墙定名/三重城垣与宫殿区/手工业作坊与三处青铜窖藏/亳都确认与新发现书院街墓地）、events 8 条结构化（1950 韩维周发现/1955 城墙定名/1961 国保与隞都说/1974 杜岭方鼎/1978 邹衡郑亳说/2021 百年百大/2022 书院街金覆面/2022—2023 博物院开馆与遗址公园挂牌）、tourism 四卡（博物院每日 9:00—17:00 周一闭馆/免费需预约/0371-65106868/东大街 366 号 + 动线 2—3 小时 + 五看解说）、highlights 8/specs 12/artifacts 6/images 4 占位；**数据纪律实例**：旧数据「1952—1953 测勘中发现」「2004 年国保」均为错误表述，按官方口径修正为「1950 年韩维周发现、1955 年确认城墙」「1961 年第一批国保」；杜岭方鼎重量取郑州市文物局口径 86.4 公斤（省文物局文 86 公斤为约数）；Mock 新增 mock-shangcheng-01 与 rawfile **字段级完全同构**（R3，临时 Node 脚本生成插入，脚本用毕删除）；rawfile 23 条/mock 7 条双份校验通过（PowerShell ConvertFrom-Json + Node 模拟模板求值 + 逐字段同构比对） |
| 2026-09-27 | **M1.7 第七批北宋东京城深写完成（构建 BUILD SUCCESSFUL，告警维持 O3 基线零新增）**：按 §1.1 方法论联网搜证（河南省文物局/省文化和旅游厅/开封市人民政府门户/开封日报/央视新闻/新华社/人民日报海外版/河南省发改委等）——intro 4 段（位置与「东京梦华」世界大都会/三重城与「四水贯都」/「城摞城」与州桥地标/考古发现与荣誉）、discovery 5 段（城摞城与地下六座城/东京城考古三重城格局/州桥及汴河遗址发掘 4400㎡ 与 6 万余件文物/州桥石壁浮雕/荣誉与未来）、events 8 条结构化（960 陈桥兵变建宋/10—11 世纪三重城与四水贯都/1127 靖康之变/1642 黄河洪水灌城淤埋州桥/1981—1988 宋城考古起步与国保/2018 州桥及汴河遗址考古启动/2021—2022 海马瑞兽石壁浮雕重见天日/2023 入选 2022 年度全国十大考古新发现）、tourism 四卡（开封市博物馆周二至周日 9:00—17:00 周一闭馆/免费需预约/0371-23299192/郑开大道与六大街交叉口 + 州桥遗址现场 + 动线半天至一天 + 五看解说）、highlights 8/specs 12/artifacts 6/images 4 占位；**数据纪律实例**：州桥石壁浮雕尺寸（通高 3.3 米/南岸 23.2 米北岸 21.2 米/推测总长约 30 米）以开封市政府门户口径为准；残留的未经核证周邦彦词（poems）按 M1.7-调整决策清空，改引核证过的王安石/范成大/梅尧臣州桥诗句入正文；Mock 的 mock-tokyo-01 由精简旧版替换为深写版并与 rawfile **字段级完全同构**（R3，临时 Node 脚本生成替换，脚本用毕删除）；rawfile 23 条/mock 7 条双份校验通过（PowerShell ConvertFrom-Json + Node 模拟模板求值 + 逐字段同构比对） |
| 2026-09-27 | **M1.7 第八批戚城遗址深写完成（构建 BUILD SUCCESSFUL，告警维持 O3 基线零新增）**：按 §1.1 方法论联网搜证（河南省人民政府门户（省文旅厅）/河南省文物考古研究院/濮阳市文化广电体育旅游局/新华网/澎湃新闻/中国社会科学网等）——intro 4 段（位置与「孔悝城」及「戚」字象征/龙山始筑城池与八千年文脉/春秋屏障会盟与父子争国子路殉难/孔子居卫与荣誉及中华第一龙）、discovery 5 段（龙山时代城址 2014 发掘/三城叠压城摞城/春秋城邑考古与孙氏文献/相关考古西水坡与荣誉）、events 8 条结构化（龙山始筑城池/春秋孙氏采邑/前626—前531 七次会盟/前480 父子争国子路殉难/春秋末孔子居卫十载/1963—1996 省保到国保/2008 龙山城址确认/2014 龙山城门新发现入选河南五大考古新发现）、tourism 四卡（每日 8:00—18:00/免费开放建议公众号预约/0393-8119207/京开大道南段 134 号 + 动线 1.5—2 小时 + 五看解说）、highlights 8/specs 12/artifacts 6/images 4 占位；**数据纪律实例**：修正旧数据「2001 年国保」为官方口径「1996 年 11 月第四批国保」；残留的未经核证《诗经·邶风·击鼓》诗（poems）按 M1.7-调整决策清空；Mock 新增 mock-qi-01 与 rawfile **字段级完全同构**（R3，临时 Node 脚本生成插入，脚本用毕删除）；rawfile 23 条/mock 8 条双份校验通过（PowerShell ConvertFrom-Json + Node 模拟模板求值 + 逐字段同构比对） |
| 2026-09-27 | **M1.7 第九批偃师商城深写完成（构建 BUILD SUCCESSFUL，告警维持 O3 基线零新增）**：按 §1.1 方法论联网搜证（河南省发改委/省文物局/省文化和旅游厅/洛阳市文物局/偃师区人民政府/洛阳日报/大河网/中国社会科学院考古研究所等）——intro 4 段（位置与「西亳」文献记载/商代第一都三重城垣与「多重环线加网格状」布局/宫城三区与池苑水系/夏商界标与荣誉）、discovery 5 段（1983 首阳山电厂选址发现/三重城垣小城大城/宫城三大部分/池苑与城市水系 2021 证实最早最完备/遗物与遗址性质）、events 8 条结构化（约前1600 商汤灭夏建西亳/商代早期三重城垣营建/约前1400 城址废弃/1983 电厂选址发现/1983—1988 宫城小城确认/1996—2001 夏商周断代工程西亳界标确立/1997—2004 十大考古新发现与百项考古大发现/2020—2022 商代最早最完备城市水系新发现）、tourism 四卡（遗址免费开放/偃师商城博物馆免费 0379-67711935/商都南路与商都东路 52 号 + 动线 1.5—2 小时可与二里头连线 + 五看解说）、highlights 8/specs 12/artifacts 6/images 4 占位；**数据纪律实例**：遗址面积采用省发改委/省文物局 2022 口径「现存约 205 万平方米」（洛阳地名网旧口径 190 万㎡，冲突按最新官方口径）；**新增踩坑第 21 条**（rawfile JSON 正文内嵌引号误用 ASCII 双引号提前闭合字符串致 JSON.parse 失败，实测被 mock 生成脚本首先发现，修复后重跑双份校验通过）；Mock 新增 mock-yanshi-01 与 rawfile **字段级完全同构**（R3，临时 Node 脚本生成插入，脚本用毕删除）；rawfile 23 条/mock 9 条双份校验通过（PowerShell ConvertFrom-Json + Node 模拟模板求值 + 逐字段同构比对） |