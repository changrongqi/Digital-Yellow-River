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
| M1.7 | 数据集深度扩充（M4.0 后续，样本先行） | 新增 highlights/specs/artifacts 结构化字段 + 23 条全量深写；仰韶村样本完成，其余 22 条分批 | 🚧 |

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