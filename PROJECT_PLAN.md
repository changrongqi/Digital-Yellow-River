# 黄河记忆 · 黄河文化分布式数字档案 —— 开发计划书

> 本计划书是项目开发的总纲与工作基线，随开发推进**动态修订**（见文末修订记录）。
> 每个子任务完成并编译验证后，同步更新计划书状态。

---

## 1. 项目概述

基于 OpenHarmony 的黄河文化数字档案应用「黄河记忆」，整合黄河河南段（三门峡、洛阳、郑州、开封、濮阳五市）文化遗产资源（仰韶文化、二里头遗址、殷墟、商城遗址、汴梁文化等），提供沉浸式文化探索；利用鸿蒙分布式数据能力，实现收藏与笔记多设备自动同步，打造个人文化记忆库。

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
- `HeritageCity`：三门峡 / 洛阳 / 郑州 / 开封 / 濮阳

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
| M1.3 | 主页 Tabs + 发现页列表 | Index 改 Tabs；发现页渲染 rawfile 数据列表 | 🚧 |
| M1.4 | 三维度筛选 + 关键词检索 | 年代/类型/城市组合筛选 + 检索框 | ⬜ |
| M1.5 | 详情页 | 五层级内容 + 跳转（Navigation/router） | ⬜ |

### M2 收藏与笔记全流程（增删改查、标签管理）+ 本地持久化（重启不丢）

| 编号 | 子任务 | 内容 | 状态 |
|---|---|---|---|
| M2.1 | FavoriteService + 本地持久化 | Preferences/RDB 存储收藏与笔记 | ⬜ |
| M2.2 | 收藏页 | 按标签分组列表 + 自定义标签 | ⬜ |
| M2.3 | 笔记编辑页 | 文字 + 自动时间戳 + 标签 | ⬜ |
| M2.4 | 详情页接入收藏/笔记 | 收藏按钮、笔记入口、列表联动 | ⬜ |

### M3 分布式数据同步（赛题核心）
- 接入 `distributedKVStore` + `distributedDeviceManager`
- `ohos.permission.DISTRIBUTED_DATASYNC` 权限 + 用户授权流程
- put 后 autoSync + 手动 sync() 入口 + on('dataChange') 刷新 UI
- LWW 冲突处理（比较 updatedAt + deviceId 兜底），冲突写入 conflictLog
- 同步面板：进度 / 最后同步时间 / 冲突记录数；单机降级「等待设备上线」
- 真机双端验证（同华为账号）；无真机则代码实现 + 编译自测作为基线

### M4 智能关联推荐
- 条目特征向量（年代/类型/城市 one-hot）→ 余弦相似度 → Top-N
- 详情页推荐区块；基于用户收藏与浏览行为微调

### M5 创新扩展（P2，视进度）
- C1 知识图谱可视化 / C2 备份与还原 / C3 多端协同编辑

## 6. 踩坑清单（必须遵守，遇坑及时补充）

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

## 7. 验收标准（M1 阶段）

1. 工程编译零报错，模拟器可运行。
2. 数据模型类型完整、字段与任务书对齐（含 deviceId/updatedAt）。
3. 预置数据可被解析并在发现页列表展示。
4. 三维度筛选 + 关键词检索结果准确。
5. 详情页五层级内容完整，返回/跳转正常。

## 8. 开发工作流与 Git 规范

- **一次只做一个子任务**（如 M1.1 → 验证 → commit → 汇报 → 下一个）。
- 每完成一个子任务即 commit 一次，commit message 用 `[M里程碑.子任务] 摘要` 格式，如 `[M1.1] 新增数据模型(枚举+Heritage/Favorite/Note/SyncStatus)`。
- 同步更新本计划书的「里程碑状态」与「修订记录」。
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