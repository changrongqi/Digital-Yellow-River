# 黄河记忆 · 黄河文化分布式数字档案

基于 HarmonyOS（ArkTS + ArkUI，Stage 模型）的黄河文化数字档案应用。整合黄河河南段（三门峡、洛阳、郑州、开封、濮阳、安阳）文化遗产资源——仰韶文化、二里头遗址、殷墟、商城遗址、汴梁文化等，提供沉浸式的文化探索体验；并利用鸿蒙分布式数据能力，实现收藏与笔记的多设备自动同步，打造个人文化记忆库。

> 产品定位：**沉浸式文化遗产体验产品**，而非精简数据知识库。内容均联网检索官方/权威来源（政府官网、博物馆、文旅厅、文物局、权威媒体）编辑核证后离线预置。

## 核心特性

- **发现与检索**：23 条真实遗址数据，支持关键词检索与「年代 / 类型 / 城市」三维度组合筛选。
- **详情页内容页签**：介绍 / 考古 / 事件 / 文旅 / 笔记（诗词板块已按产品决定移除，见 O12），配合年代主题色视觉呈现。
- **事件子详情页**：每条历史事件可点击进入专题讲解（背景 / 经过 / 影响 / 相关人物与文物 / 延伸阅读 / 深度解说）。
- **文旅深度信息**：行程规划（推荐路线、时长、交通、串联景点）、参观指引（开放时间 / 票务）与深度解说。
- **图集组件**：缩略图网格 + 点击 Lightbox 放大 + 动态响应式布局。
- **收藏与笔记**：收藏（标签分组）、笔记编辑、「我的笔记」聚合页，本地持久化、重启不丢。
- **分布式同步**：基于 `distributedKVStore` + `autoSync`，采用 LWW（Last-Write-Wins）冲突策略，无组网时静默降级为纯本地模式。
- **智能关联推荐**：条目特征向量（年代 / 类型 / 城市 one-hot）→ 余弦相似度 → Top-N。
- **知识图谱**：按文化主题聚合遗址，Canvas 绘制节点网络，支持主题新建 / 重命名 / 删除与归类管理。

## 技术栈

| 项 | 值 |
|---|---|
| 平台 | OpenHarmony / HarmonyOS（Stage 模型） |
| 语言 / 框架 | ArkTS + ArkUI 声明式范式 |
| API 版本 | 最低 API 16（`compatibleSdkVersion: 5.0.4(16)`；任务书要求 ≥ 12） |
| IDE | DevEco Studio |
| 设备类型 | phone / tablet |
| 包名 | `com.huanghe.memory`（与 `SyncService.BUNDLE_NAME` 一致） |
| 网络 | 零网络依赖，文化资源全部离线预置 |
| 存储 | 本地 Preferences 为基线 + 分布式 KV 同步 |
| 权限 | `ohos.permission.DISTRIBUTED_DATASYNC` |

## 目录结构

```text
entry/src/main/
├── ets/
│   ├── entryability/          # 入口 Ability
│   ├── entrybackupability/    # 系统备份扩展
│   ├── pages/                 # 页面层（UI）
│   │   ├── Index.ets          # 主页 Tabs（发现 / 收藏 / 同步 / 图谱）
│   │   ├── Discovery.ets      # 发现页：检索 + 三维度筛选 + 列表
│   │   ├── Detail.ets         # 详情页：内容页签 + 收藏 + 笔记 + 推荐
│   │   ├── EventDetail.ets    # 事件子详情页
│   │   ├── Favorites.ets      # 收藏页（按标签分组）
│   │   ├── MyNotes.ets        # 我的笔记聚合页
│   │   ├── NoteEdit.ets       # 笔记编辑页
│   │   ├── SyncPanel.ets      # 同步状态面板
│   │   └── KnowledgeGraph.ets # 知识图谱页
│   ├── components/            # 可复用 UI 组件
│   │   ├── ImageGallery.ets   # 图集组件：缩略图 + Lightbox 放大
│   │   └── graph/             # 知识图谱组件
│   │       ├── GraphCanvas.ets        # Canvas 渲染、视口与手势
│   │       ├── GraphRenderer.ets      # 节点/边/标签纯绘制
│   │       ├── GraphLayout.ets        # 图模型 + 确定性力导向布局（纯函数）
│   │       ├── GraphNode.ets          # 节点/边/图模型类型
│   │       ├── NodeInfoPanel.ets      # 节点信息卡（主题/已归类/拓展推荐）
│   │       ├── HeritageCard.ets       # 主题下遗址卡片
│   │       ├── ThemeEditorSheet.ets   # 主题新建/重命名弹层
│   │       ├── ManageSheet.ets        # 归类管理弹层
│   │       └── ConfirmDeleteSheet.ets # 删除确认弹层
│   ├── model/                 # 数据模型层（类型定义，无逻辑）
│   ├── data/                  # 预置数据层
│   │   ├── HeritageDataLoader.ets     # rawfile JSON 唯一解析入口
│   │   ├── HeritageRepository.ets     # 页面唯一数据入口（rawfile/mock + id 映射）
│   │   └── MockHeritages.ets          # 预览器兜底数据（id 与正式数据一致）
│   ├── service/               # 业务服务层
│   │   ├── FavoriteService.ets        # 收藏/笔记/标签 + 本地持久化 + LWW
│   │   ├── ThemeService.ets           # 文化主题 CRUD + LWW
│   │   ├── SyncService.ets            # distributedKVStore / autoSync / 追赶同步
│   │   ├── DeviceIdentity.ets         # 设备标识（ODID 优先，cache UUID 回退）
│   │   └── PermissionService.ets      # DISTRIBUTED_DATASYNC 运行时权限
│   └── utils/                 # 工具函数
│       ├── Recommendation.ets         # 相似度推荐
│       ├── ThemeRecommendation.ets    # 主题拓展推荐
│       ├── EraTheme.ets               # 年代主题色
│       ├── ThemeTokens.ets            # 设计 token（中性语义色）
│       ├── JsonField.ets              # JSON 字段类型校验
│       ├── LwwVersion.ets             # LWW 版本严格递增
│       └── TimeFormat.ets             # 时间格式化
└── resources/rawfile/         # heritage_data.json + images/（离线基线）
```

分层原则：`pages` 只做 UI 与状态；数据读写一律走 `service`；`model` 只有类型。

## 快速开始

1. 使用 **DevEco Studio** 打开本工程（需配置 HarmonyOS SDK：编译 SDK 26，最低运行 API 16，满足任务书 ≥ 12 的要求）。
2. 首次打开后等待 `oh_modules` 依赖同步完成。
3. 连接手机 / 平板 / 模拟器，选择 `entry` 模块运行。
4. 命令行构建（可选）：

   ```bash
   hvigorw assembleHap
   ```

## 数据说明

- 预置数据集位于 [heritage_data.json](file:///e:/HarmonyOS_coding/entry/src/main/resources/rawfile/heritage_data.json)，共 23 条真实遗址，覆盖 6 市、4 类型、6 个年代段。
- 为便于预览器调试，[MockHeritages.ets](file:///e:/HarmonyOS_coding/entry/src/main/ets/data/MockHeritages.ets) 提供同结构 mock 数据，与 rawfile 共用同一解析入口，避免字段漂移；mock id 与正式数据完全一致。
- 事件专题中的人物/文物/图片按可核证的官方/权威资料填充；暂无可靠来源的字段保持为空，页面自动隐藏对应区块，不虚构内容（缺口清单见 ISSUES_RISKS O35）。
- 图片已接入：123 张（23 封面 / 92 详情图集 / 8 事件图）位于 `resources/rawfile/images/`，rawfile 与 mock 双份填写路径；列表与收藏卡按 320px 长边缩略解码显示封面，缺失或加载失败回落文字徽标；图集缺失时显示占位卡。
- 内容深写与搜证方法论详见 [CONTENT_METHODOLOGY.md](file:///e:/HarmonyOS_coding/CONTENT_METHODOLOGY.md)（原 [PROJECT_PLAN.md](file:///e:/HarmonyOS_coding/PROJECT_PLAN.md) 第 1.1 节）。

## 开发进度

里程碑（详见 [PROJECT_PLAN.md](file:///e:/HarmonyOS_coding/PROJECT_PLAN.md) 第 5 节）：

- **M1 工程骨架 + 预置数据集 + 发现/筛选/检索/详情页** ✅
- **M2 收藏与笔记全流程 + 本地持久化** ✅
- **M3 分布式数据同步** ✅
- **M4 智能关联推荐 + 详情页信息架构改版** ✅
- **M5 创新扩展（知识图谱等）** ✅
- **M6 全项目优化（两轮优化 + 第三轮收尾）** 🚧

## 许可证

本项目采用 [MIT License](file:///e:/HarmonyOS_coding/LICENSE)。