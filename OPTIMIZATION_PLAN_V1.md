# 黄河记忆 · 全项目优化计划（V1 · 第一轮）

> **版本：V1（第一版，2026-10-22）**。文件名 `OPTIMIZATION_PLAN_V1.md` 即版本标识；后续大版本另建 V2，不覆盖本版历史。
> 来源：2026-10-22 全项目优化审计（只读审计，未改代码）。
> 本文件是优化轮次的**唯一总表**：所有优化项、优先级、依赖、验收标准、执行顺序均以此为准；
> 完成一项即更新本文件状态，并同步 `PROJECT_PLAN.md`、`ISSUES_RISKS.md`、`REVISION_LOG.md`。
>
> 状态图例：`未开始` / `进行中` / `已完成` / `暂缓`
> 维护规则：新增/调整项必须在本文件「变更记录」写理由；不重复已完成项，不推翻 O16 图谱结构权衡。

---

## 0. 执行纪律（与 START_HERE / PITFALLS 一致）

1. 一次只做一个子任务；同一文件禁止并行修改，改完回读。
2. 动手前：读 `PITFALLS.md` 全文 + 本任务相关分册；复杂 API 先查官方文档并与本机 SDK d.ts 双重核对。
3. 每项完成：`BUILD SUCCESSFUL` → O3 告警按「文件 + 类型」比对无新增 → 更新文档 → commit `[M6.x] 摘要`。
4. 禁 `any`、禁解构；`build()` 根节点前禁任何语句；`@Builder` 参数按值传递；Canvas 必须 `@Watch` 重绘；
   自定义组件字段避开 `scale` 等内置名；Canvas 手势用 `GestureGroup`；数据双份同构。
5. 部署只用 `hdc install -r`，禁止 `hdc uninstall`；真机/模拟器验证结果如实登记，不把未验证项标为已完成。
6. 本文件可动态修订；理由写入 `REVISION_LOG.md`，状态同步到 `PROJECT_PLAN.md`。
7. **已完成项必须显式标注**：条目状态改为 `已完成`，并写清完成日期、commit、验收范围（代码/构建/设备验证）；
   同时在 `PROJECT_PLAN.md` M6 表与下方「完成汇总」同步。只改 `[x]` 不算完成，未做设备验证不得写「全部通过」。

---

## 1. 基线（2026-10-22 实测）

| 项 | 结果 |
|---|---|
| 构建 | `BUILD SUCCESSFUL`（增量 1.9s；无源码变更，O3 基线未受影响） |
| 预置数据 | 23 条遗址 / 184 条事件；无重复 id；核心字段无空 |
| 图片 | 92 张遗址图 + 8 张事件图 `path` 全为空；`coverImage` 全为空 → 已知 O1 |
| 诗词 | `poems` 0 条、详情页无诗词页签 → 已知 O12，**不是缺陷** |
| 硬约束 | 无 `any`/解构；`build()` 根节点前无语句；Canvas `@Watch`/`GestureGroup` 均已落实；`viewScale` 避开内置名 |
| 路由 | `main_pages.json` 已注册 Index/Detail/NoteEdit/MyNotes/EventDetail |

**不重复项**（已完成或已知遗留，不在本计划重新打开）：
O1 图片占位、O7 真机分布式联调、O8 Mock 修复、O11 同步面板时序、O12 诗词删除、
O13~O15/O17 图谱设备验证、O16 图谱结构权衡（刻意保留）；C1.4~C1.7 不重新拆分。

### 1.1 完成汇总（V1 内持续更新）

| 项 | 子任务 | 完成日期 | commit | 验收范围 | 状态 |
|---|---|---|---|---|---|
| B1 | M6.1 分布式同步运行时权限 | 2026-10-22 | `de6b8c1` | 代码 + 构建；权限弹窗/拒绝/重试待 O7 设备验证 | 已完成（代码/构建） |
| H1 | M6.2 同步追赶 / 初始化重试 / sync 目标 networkId | 2026-10-22 | `40f990f` + 复核补强 | 代码 + 构建；双端首次拉取与设备上线收敛待 O7 设备验证 | 已完成（代码/构建） |
| H2 | M6.3 删除墓碑与主题引用校验 | 2026-10-22 | `bdb18ee` | 代码 + 构建；双端删除/复活/并发编辑场景待 O7 设备验证 | 已完成（代码/构建） |
| H3 | M6.4 笔记未保存退出保护 | 2026-10-22 | `27378bc` + 复核补强 | 代码 + 构建；返回确认交互待设备验证 | 已完成（代码/构建） |
| H4 | M6.5 API 兼容口径统一 | 2026-10-22 | `2a5d0bb` | 文档 + 构建；目标设备安装待 O22 | 已完成（文档/构建） |
| M1 | M6.6 共享 DeviceIdentity / LWW 版本推进 / 冲突台账设备标识 | 2026-10-22 | `7b9043d` + 复核补强 | 代码 + 构建；双端平局待 O23/O7 | 已完成（代码/构建） |
| M2 | M6.7 标签删除改为保存时提交 | 2026-10-23 | `01bdb1e` | 代码 + 构建；取消/保存交互待 O24 设备验证 | 已完成（代码/构建） |
| M3 | M6.8 MyNotes 订阅数据变化 | 2026-10-23 | `b1786b0` | 代码 + 构建；页面停留刷新待 O25 设备验证 | 已完成（代码/构建） |

> 说明：状态 `已完成（代码/构建）` 不等于设备验证通过；必须在对应 O 项登记未验证范围。

---

## 2. 分级与轮次

| 级别 | 含义 | 本轮处理 |
|---|---|---|
| 阻塞 | 不修则核心验收无法进行 | 第一轮 |
| 高 | 数据丢失/同步不收敛/验收口径风险 | 第一轮 |
| 中 | 一致性、状态管理、UI/UX、工程质量 | 第二轮 |
| 低 | 维护性、微性能、文档、清理 | 第三轮 |

- **第一轮（本轮目标，P0+P1）**：B1 → H1 → H2 → H3 → H4。
- **第二轮（P2）**：M1~M11，按「数据一致性 → 状态/架构 → UI/UX → 发布工程」顺序。
- **第三轮（P3）**：L1~L10，收尾清理、文档、微性能。
- 每轮完成标准：该轮全部项 `已完成`，构建成功，O3 无新增，文档同步，commit 齐全。

---

## 3. 全量清单

### 3.1 阻塞

- [x] **B1 未申请 `DISTRIBUTED_DATASYNC` 运行时权限**（已完成：代码/构建；权限弹窗与拒绝/重试待设备验证）
  - 位置：[module.json5](entry/src/main/module.json5#L50-L61)、[SyncService.ets](entry/src/main/ets/service/SyncService.ets#L95-L134)、[FavoriteService.ets](entry/src/main/ets/service/FavoriteService.ets#L65-L93)
  - 问题：只声明权限；全库无 `requestPermissionsFromUser`。SDK `PermissionDefinitions.json` 中该权限 `grantMode=user_grant`；`getAvailableDeviceListSync` 未授权抛 201，被 catch 后返回空数组，UI 显示“暂无在线设备”。
  - 建议：新增 `PermissionService`；启动时申请一次；`SyncService.init` 以权限为门禁；拒绝时面板提供“去设置授权”；授予后重试初始化。
  - 验收：首次启动出现权限弹窗；授予后 KV 就绪、面板不再显示“未授权”；拒绝后本地功能不受影响、面板显示权限状态与重试入口；构建成功。
  - 完成记录（2026-10-22，commit `de6b8c1`）：新增 `service/PermissionService.ets`（查询/首次申请/拒绝后 requestPermissionOnSetting）；`SyncService.init` 权限门禁且未授权不置 initialized；KV ready 后 `notifyStatusListeners()`（顺带补 O11 的触发点）；EntryAbility 启动申请、回前台重试初始化；SyncPanel 三态文案 + 授权按钮。构建 `BUILD SUCCESSFUL`，16 条 WARN 与 O3 基线一致。当前无连接设备，弹窗/拒绝/重试待设备验证。
  - 依赖：无。
  - 风险：不修则真机 M3.4/C1.3/C2/C3 全部无法验收，且会被误判为 O7 组网问题。

### 3.2 高

- [x] **H1 同步只订阅不追赶，初始化失败不可恢复**（已完成：代码/构建；双端验证待 O7）
  - 位置：[SyncService.ets](entry/src/main/ets/service/SyncService.ets#L108-L190)、[SyncService.ets](entry/src/main/ets/service/SyncService.ets#L386-L476)、[SyncService.ets](entry/src/main/ets/service/SyncService.ets#L497-L532)
  - 问题：KV ready 后无 `PUSH_PULL` 追赶；`deviceStateChange` 只刷 UI；`initialized=true` 在成功前设置，失败后本进程不再重试。另外 `manualSync` 把 `DeviceBasicInfo.deviceId` 当作 sync 目标，而官方 d.ts 明确 `sync(deviceIds)` 传的是 **networkId**（deviceId 是 UDID 混淆值），真机会同步失败。
  - 建议：KV ready/设备上线/回前台时主动 PUSH_PULL（auto 节流、manual 强制）；sync 目标改用 `DeviceBasicInfo.networkId`（缺失跳过）；初始化失败保留可重试状态并给面板重试入口。
  - 验收：第二台设备首次打开能拉到已有数据；离线写入在设备上线后收敛；初始化失败后可在面板重试后恢复；sync 目标确认使用 networkId。
  - 完成记录（2026-10-22，commit `40f990f` + 复核补强）：`SyncDeviceInfo` 改为 `networkId` 并跳过缺失项；新增 `requestSync(force)` 统一 PUSH_PULL（auto 2s 节流 + 1s delay，manual 立即）；KV ready/设备上线/回前台触发追赶；`initialized` 改为成功后才置 true，新增 `initializing` 并发保护与 3s 重试节流，`retryInit` 供面板绕过节流；DeviceManager 失败不再永久熔断；SyncPanel 增加「重试初始化」入口与「同步服务未就绪 · 可重试」文案。**复核补强**：FavoriteService 先注册远端监听再 `SyncService.init`；Index 启动时同时初始化 ThemeService（避免主题初次 PULL 无人合并）；SyncService 在无业务监听时挂起 `initialSyncPending`，由 Index 在两监听注册后补发追赶。构建 BUILD SUCCESSFUL，16 条 WARN 与 O3 一致。双端首次拉取/设备上线收敛需真机验证，登记 O19/O7。
  - 依赖：B1（已完成）。
  - 风险：双端长期不收敛；验收误判同步失效；networkId 用错会让 M3 全部同步调用无效。

- [x] **H2 删除无墓碑，存在复活与删除覆盖编辑**（已完成：代码/构建；双端验证待 O7）
  - 位置：[FavoriteService.ets](entry/src/main/ets/service/FavoriteService.ets#L378-L400)、[FavoriteService.ets](entry/src/main/ets/service/FavoriteService.ets#L435-L604)、[ThemeService.ets](entry/src/main/ets/service/ThemeService.ets#L166-L190)、[SyncService.ets](entry/src/main/ets/service/SyncService.ets#L262-L295)
  - 问题：删除直接删 KV key；远端删除无条件生效；离线端旧记录可复活；远端删除可覆盖较新的本地编辑。
  - 建议：删除写 tombstone（`deletedAt + deviceId`）并参与 LWW；合并收藏时校验 `themeIds` 是否仍存在。
  - 验收：A 删除、B 离线修改后上线，不复活且编辑不静默丢失；主题删除后无悬挂引用；构建成功。
  - 完成记录（2026-10-22，commit `bdb18ee`）：① 新增 `model/Tombstone.ets`（id + deletedAt + deviceId）；收藏/笔记墓碑存 `favorite_tombstones_json` / `note_tombstones_json`，主题墓碑存 `theme_tombstones_json`。② 删除改为以墓碑覆盖同一 KV 键（`fav_/note_/theme_` 前缀不变），远端按 `deletedAt` 字段识别墓碑；收藏/笔记/主题的合并全部改为「实体 vs 实体、实体 vs 墓碑、墓碑 vs 墓碑」三路 LWW（实体 updatedAt vs 墓碑 deletedAt，相等 deviceId 兜底）。③ 语义明确：删除晚于编辑→维持删除（不复活，冲突登记）；编辑晚于删除→保留编辑（不静默丢失）；本机无记录但收到墓碑→记墓碑，防止其它设备旧记录日后复活；旧版本 `deleteEntries` 硬删除保留兼容。④ 重新收藏已删除条目时 `updatedAt = max(now, deletedAt + 1)`，保证新记录严格新于墓碑。⑤ `themeIds` 校验：ThemeService 通过 `FavoriteService.setThemeIdValidator` 注册回调（避免循环 import），采纳远端收藏时剔除「已有墓碑」的主题引用；不按「缓存中不存在」判定，避免远端主题与收藏同批到达时误删有效引用。⑥ KV 未就绪时的写入（含墓碑）进入 SyncService 待写队列（同键保留最后一次、上限 200），KV ready 后先补写再重放墓碑，避免旧墓碑残留 KV 与本地新状态冲突。⑦ 构建 `BUILD SUCCESSFUL`，16 条 WARN 与 O3 基线按「文件+类型」一致零新增；当前无连接设备，双端删除/复活/并发编辑场景登记 O20/O7，未冒充通过。
  - 依赖：H1（已完成）。
  - 风险：收藏/笔记/主题丢失或复活；C2 备份恢复会放大。

- [x] **H3 笔记编辑未保存退出直接丢失**（已完成：代码/构建；返回确认交互待设备验证）
  - 位置：[NoteEdit.ets](entry/src/main/ets/pages/NoteEdit.ets#L153-L191)、[NoteEdit.ets](entry/src/main/ets/pages/NoteEdit.ets#L357-L403)
  - 问题：正文只在 `@State`；返回/系统返回直接离开；无 `onBackPress`。
  - 建议：dirty 标记 + 二次确认/草稿；拦截系统返回。
  - 验收：有未保存内容时返回弹确认；选择取消留在页面、选择放弃才离开；无改动直接返回。
  - 完成记录（2026-10-22，commit `27378bc` + 复核补强 `77d0e5f`）：① 新增 `originalContent`（载入时的原始正文，新建为空串）与 `isDirty()`（`content !== originalContent`），编辑后改回原文也视为未修改。② 顶部返回与系统返回统一走 `handleBack()`：无修改直接 `goBack`；有未保存内容弹「放弃未保存的修改？」确认（「继续编辑」留下 / 「放弃修改」离开）；确认层打开时再次返回先关闭弹层。③ 新增 `onBackPress()` 拦截系统返回；`goBack` 前置 `leaving` 标记，保存/删除后的离开流程不再重复拦截，也避免 `router.back` 与默认返回逻辑重复出栈。④ 保存成功、删除成功仍直接返回，不额外弹确认。⑤ **复核补强**：载入原稿时若用户已开始输入（加载期间 TextArea 可编辑），不再覆盖 `content`，只把服务层原稿写入 `originalContent` 作为脏基准，避免输入被回填吞掉且误判为未修改。⑥ 构建 `BUILD SUCCESSFUL`，16 条 WARN 与 O3 基线按「文件+类型」一致零新增（NoteEdit 行号漂移：getParams 55→64、back 140→190）；当前无连接设备，返回确认交互登记 O21，未冒充通过。
  - 依赖：无。
  - 风险：长笔记丢失。

- [x] **H4 API 兼容口径与文档不一致（条件性阻塞）**（已完成：文档/构建；目标设备安装待验证）
  - 位置：[build-profile.json5](build-profile.json5#L7-L17)、[PROJECT_PLAN.md](PROJECT_PLAN.md#L63-L67)、[README.md](README.md#L19-L30)、[START_HERE.md](START_HERE.md#L1-L4)
  - 问题：`compatibleSdkVersion: 5.0.4(16)` 最低 API 16，文档/交接称 API 12；若验收用 API 12 镜像会安装失败。
  - 建议：确认验收下限；要求 API 12 则降 `compatibleSdkVersion` 并以 API 12 SDK 回归；否则统一文档口径为 API 16。
  - 完成记录（2026-10-22，commit `2a5d0bb`）：① **决策依据**——PROJECT_PLAN §2 明确任务书要求为「≥ 12」，并非必须等于 12；当前 `compatibleSdkVersion: 5.0.4(16)` 满足下限，且本机仅安装编译 SDK 26、无 API 12 SDK/镜像可用于下调后的安装回归，贸然降级会产生不可验证的交付风险。② **结论**——保持构建配置不变（`compatibleSdkVersion: 5.0.4(16)`、`targetSdkVersion: 26.0.0`），统一文档口径为「最低 API 16（任务书要求 ≥ 12）」：PROJECT_PLAN §0 速记与 §2 技术约束、README 技术栈表与快速开始、START_HERE 首行；同步修正 C1 里程碑中「API 12 CanvasRenderingContext2D」的易误解表述。③ **代码注释**——`SyncService` 标注「API 12 文档口径；本机编译 SDK 26、最低运行 API 16」，`FavoriteService` 改为「本机 SDK 实测存在」，避免把文档口径误读为运行下限。④ **构建**——`BUILD SUCCESSFUL`，16 条 WARN 与 O3 基线按「文件+类型」一致零新增。⑤ **未验证范围**——目标设备安装登记 O22；若验收方明确要求 API 12 镜像，需另立任务：安装 API 12 SDK、下调 `compatibleSdkVersion` 并做 API 12 设备/模拟器安装与功能回归，不能只改配置不验证。
  - 依赖：无（文档/配置决策）。
  - 风险：验收环境不匹配时无法安装。

### 3.3 中

- [x] **M1 LWW 版本标识不可靠**（已完成：代码/构建；双端并发/备份恢复待设备验证）
  - 位置：[DeviceIdentity.ets](entry/src/main/ets/service/DeviceIdentity.ets#L1-L140)、[LwwVersion.ets](entry/src/main/ets/utils/LwwVersion.ets#L1-L14)、[FavoriteService.ets](entry/src/main/ets/service/FavoriteService.ets#L256-L288)、[FavoriteService.ets](entry/src/main/ets/service/FavoriteService.ets#L310-L330)、[FavoriteService.ets](entry/src/main/ets/service/FavoriteService.ets#L384-L416)、[ThemeService.ets](entry/src/main/ets/service/ThemeService.ets#L146-L195)、[SyncService.ets](entry/src/main/ets/service/SyncService.ets#L315-L327)
  - 问题：更新只改 `updatedAt` 不改 `deviceId`；Favorite/Theme 各生成一份 deviceId；依赖墙钟；备份恢复复制 deviceId。
  - 建议：共享 `DeviceIdentity`；每次写刷新 deviceId；必要时逻辑时钟/恢复后重生成。
  - 验收：双端同时编辑同一条记录，平局兜底与冲突日志能指向真实最后写入设备。
  - 完成记录（2026-10-22，commit `7b9043d` + 复核补强 `35f9dcf`，执行编号 M6.6）：① **共享设备标识**——新增 `service/DeviceIdentity.ets`：优先使用系统 `deviceInfo.ODID`（API 12+，按设备生成，备份恢复到新设备后自然换成新设备 ID）；ODID 为空/读取失败时回退到 `cacheDir/lww_device_id.txt` 的随机 UUID（官方备份配置默认 `includes` 仅覆盖 files/preferences/database/distributedfiles 等，**不包含 cache**，因此备份恢复到新设备不会复制该 UUID；cache 被清理时会重新生成 ID，仅影响 LWW 平局归因，不影响数据与同步收敛）。FavoriteService / ThemeService 删除各自的 `ensureDeviceId` 与 `device_id` 存储，统一依赖 DeviceIdentity。② **每次写入刷新 deviceId**——新增收藏/笔记/主题、更新标签/主题归类/笔记正文、删标签、删除墓碑时均写入 `DeviceIdentity.get()`；deviceId 语义固定为「最后写入该记录的设备」。③ **版本严格递增**——新增 `utils/LwwVersion.ets` 的 `nextUpdatedAt(previous, now)`：`now > previous ? now : previous + 1`；所有更新路径与墓碑 `deletedAt` 使用它，避免墙钟回拨/同毫秒连续编辑时新版本输给旧版本。④ **冲突台账可定位**——`ConflictLogItem` 增加 `deviceId`，`SyncService.recordConflict` 记录胜出版本的最后写入设备；Favorite/Theme 共 18 处冲突分支传入实际胜方设备 ID，SyncPanel 冲突卡展示「最后写入设备」。⑤ **构建**——clean 构建 `BUILD SUCCESSFUL`，16 条 WARN 与 O3 基线按「文件+类型」一致零新增。⑥ **残余与验证**——回退标识已移出 Preferences，备份复制风险彻底规避；cache 清理导致 ID 变化属预期（仅影响平局归因）。双端并发的平局判定需真机验证，登记 O23/O7，未冒充通过。
  - 依赖：H2（已完成）。

- [x] **M2 标签编辑器删除标签立即全局持久化**（已完成：代码/构建；取消/保存交互待设备验证）
  - 位置：[Favorites.ets](entry/src/main/ets/pages/Favorites.ets#L93-L100)、[Favorites.ets](entry/src/main/ets/pages/Favorites.ets#L278-L340)
  - 问题：`removeEditorTag` 直接写盘+同步；“取消”无法撤销。
  - 建议：编辑期只改本地，保存时统一提交；或删除前确认+撤销。
  - 验收：编辑器中删除标签后点取消，原有关联不变。
  - 完成记录（2026-10-23，commit `01bdb1e`，执行编号 M6.7）：① 新增 `editorRemovedTags` 暂存本次编辑中待删除的自定义标签；`removeEditorTag` 只从本地候选 `editorAllTags` 与勾选集合 `editorSelected` 移除，不再调用 `FavoriteService.removeTag`。② `saveTags` 先逐条提交待删除标签（全局 `removeTag`），再提交当前收藏的勾选集合（`updateFavoriteTags`），最后统一刷新分组并关闭弹层。③ 同名标签在本轮删除后又通过输入框重新新增时，从 `editorRemovedTags` 撤销删除，避免保存时被误全局移除。④ `closeSheet` / `openTagEditor` 清空暂存；点「取消」不产生任何持久化或同步副作用。⑤ 构建 `BUILD SUCCESSFUL`，16 条 WARN 与 O3 基线按「文件+类型」一致零新增（Favorites 行号漂移：pushUrl 226→230、566→590）；当前无连接设备，取消/保存交互登记 O24，未冒充通过。
  - 依赖：无。

- [x] **M3 MyNotes 不订阅数据变化**（已完成：代码/构建；页面停留刷新待设备验证）
  - 位置：[MyNotes.ets](entry/src/main/ets/pages/MyNotes.ets#L60-L86)
  - 问题：只在 aboutToAppear/onPageShow 刷新；远端合并时页面停留不更新。
  - 建议：订阅 `FavoriteService.onDataChanged` 并注销。
  - 验收：页面停留时远端新增/删除笔记，列表自动刷新。
  - 完成记录（2026-10-23，commit `b1786b0`，执行编号 M6.8）：① 新增稳定的 `dataChangedHandler` 函数引用（箭头函数字段），在 `aboutToAppear` 中 `FavoriteService.onDataChanged(this.dataChangedHandler)` 注册，命中远端合并或其它页面增删笔记时调用 `refreshList()` 整体重算聚合列表。② `aboutToDisappear` 用同一引用 `offDataChanged` 注销，防监听泄漏与销毁后回调。③ 保留 `onPageShow` 刷新作为从 NoteEdit 返回的兜底；`loadHeritages` 完成后的首次刷新不变。④ 构建 `BUILD SUCCESSFUL`，16 条 WARN 与 O3 基线按「文件+类型」一致零新增（MyNotes 行号漂移：pushUrl 125→141、back 133→149）；当前无连接设备，页面停留时的远端增删刷新登记 O25，未冒充通过。
  - 依赖：B1/H1（真机验证）。

- [ ] **M4 数据访问层重复，JSON 解析助手 4 份**
  - 位置：7 个页面加载兜底（Discovery/Detail/EventDetail/Favorites/MyNotes/NoteEdit/KnowledgeGraph）；4 份 `getStr/getNum/getStrArray`
  - 问题：每页重复 try/catch + mock + Map；类型校验弱；`detail:null` 会丢弃整条。
  - 建议：`HeritageRepository.load(context)` 返回 `{list,isMock}` 并缓存 Map；抽 `utils/JsonField`；修 null detail。
  - 验收：7 页行为一致，新增页面不再复制兜底；异常数据不静默丢条目。
  - 依赖：H3（避免同文件冲突）。

- [ ] **M5 状态刷新双通道**
  - 位置：[Index.ets](entry/src/main/ets/pages/Index.ets#L30-L32)、[KnowledgeGraph.ets](entry/src/main/ets/pages/KnowledgeGraph.ets#L94-L115)
  - 问题：Index tick 与 KG 服务订阅同时生效，收藏变化触发两次；Favorites 只靠 tick，MyNotes 没有。
  - 建议：统一 Tab 直接订阅 service；Index 只保留生命周期信号。
  - 验收：一次收藏变化只触发一次刷新；各 Tab 刷新行为一致。
  - 依赖：M3。

- [ ] **M6 无障碍、触控目标与对比度**
  - 位置：[Detail.ets](entry/src/main/ets/pages/Detail.ets#L207-L214)、[Favorites.ets](entry/src/main/ets/pages/Favorites.ets#L571-L578)、[NodeInfoPanel.ets](entry/src/main/ets/components/graph/NodeInfoPanel.ets#L64-L70)
  - 问题：无 `accessibilityText/role`；多个触控区 <44vp；次要文字对比度 2.07~4.29:1。
  - 建议：触控区 ≥44vp；文字 ≥4.5:1；补无障碍文本；支持字体缩放。
  - 验收：关键按钮可点区域达标；对比度核算通过；TalkBack 可读出主要操作。
  - 依赖：无。

- [ ] **M7 跟随系统深色模式但 UI 全为浅色硬编码**
  - 位置：[EntryAbility.ets](entry/src/main/ets/entryability/EntryAbility.ets#L29)
  - 问题：`COLOR_MODE_NOT_SET` + 浅色硬编码；dark 资源只有启动背景。
  - 建议：明确只支持浅色则设 `COLOR_MODE_LIGHT`；或补齐 dark 资源/token。
  - 验收：系统深色/浅色切换下状态栏与页面可读性一致。
  - 依赖：L1（token）。

- [ ] **M8 节点信息卡在首屏下方，平板正文行宽过长**
  - 位置：[KnowledgeGraph.ets](entry/src/main/ets/pages/KnowledgeGraph.ets#L718-L780)、[Detail.ets](entry/src/main/ets/pages/Detail.ets#L407-L412)
  - 问题：点选节点后信息卡常在首屏下方；平板长文全宽。
  - 建议：信息卡改 Sheet/浮层或自动滚动；正文 `maxWidth` 居中。
  - 验收：手机点选节点立即可见反馈；平板行宽适中。
  - 依赖：无。

- [ ] **M9 拓展推荐节点缺少“收藏并归入主题”闭环**
  - 位置：[NodeInfoPanel.ets](entry/src/main/ets/components/graph/NodeInfoPanel.ets#L123-L142)
  - 问题：RECOMMEND 只有“查看详情”。
  - 建议：增加“收藏并归入当前主题”动作。
  - 验收：推荐节点一键收藏并归入当前主题，图谱即时刷新。
  - 依赖：H2/M1（同步一致性）。

- [ ] **M10 应用元信息仍为模板占位**
  - 位置：[app.json5](AppScope/app.json5#L3-L9)、[string.json](AppScope/resources/base/element/string.json#L1-L8)、[entry string.json](entry/src/main/resources/base/element/string.json#L1-L20)
  - 问题：`app_name=first`、`bundleName=com.example.first`、`label=label`。
  - 建议：改为“黄河记忆”、正式 bundleName、标签/描述/版本；同步 `SyncService.BUNDLE_NAME`。
  - 验收：桌面显示“黄河记忆”；包名与文档一致；真机联调前定稿。
  - 依赖：H4（API/交付口径）。

- [ ] **M11 无业务单元测试与 CI 门禁**
  - 位置：[LocalUnit.test.ets](entry/src/test/LocalUnit.test.ets#L24-L31)、[Ability.test.ets](entry/src/ohosTest/ets/test/Ability.test.ets#L25-L32)
  - 问题：仅模板断言；LWW/推荐/布局/解析无测试；无 CI。
  - 建议：补 Hypium 单测；CI 执行 build+lint+test。
  - 验收：核心纯函数有测试；CI 可阻断回归。
  - 依赖：M1/M4（被测逻辑稳定后）。

### 3.4 低

- [ ] **L1 402 处硬编码颜色，无设计 token 层**
  - 位置：[EraTheme.ets](entry/src/main/ets/utils/EraTheme.ets#L29-L64)、[Theme.ets](entry/src/main/ets/model/Theme.ets#L27)
  - 建议：抽 `ThemeTokens`/资源；先覆盖背景、正文、次要文字、边框。
  - 验收：高频颜色有单一来源；改色不再全库搜。

- [ ] **L2 少量死代码**
  - 位置：[HeritageCard.ets](entry/src/main/ets/components/graph/HeritageCard.ets#L11)、[GraphNode.ets](entry/src/main/ets/components/graph/GraphNode.ets#L32-L47)
  - 问题：`isDark` 未使用；GraphNode 的 era/city/type/summary 只写不读（coverImage/Poem 属 O1/O12，不计）。
  - 建议：删除 `isDark`；预留字段补注释或移除。

- [ ] **L3 mock id 与正式数据不一致**
  - 位置：[MockHeritages.ets](entry/src/main/ets/data/MockHeritages.ets#L22-L25)
  - 问题：`mock-*` vs `smx-*`；预览深链找不到。
  - 建议：mock 使用正式 id 或建立映射。

- [ ] **L4 文档口径漂移**
  - 位置：[README.md](README.md#L9-L13)、[README.md](README.md#L32-L56)、[PROJECT_PLAN.md](PROJECT_PLAN.md#L228)、[PROJECT_PLAN.md](PROJECT_PLAN.md#L263)
  - 问题：五层级含诗词、目录树缺 graph、C1.1 store 键名、龙山/仰韶计数与实际不符（O 索引已在 M6.2 修正）。
  - 建议：按代码现状统一 README/计划/遗留项。

- [ ] **L5 微性能**
  - 位置：[Discovery.ets](entry/src/main/ets/pages/Discovery.ets#L184)、[Favorites.ets](entry/src/main/ets/pages/Favorites.ets#L153-L191)、[Detail.ets](entry/src/main/ets/pages/Detail.ets#L79-L83)
  - 问题：filterList 每次 build ×3；Favorites O(F×N) 笔记计数；笔记变化触发详情推荐重算；Mock 615KB 进包。
  - 建议：缓存 filtered/noteCount；按数据类型拆分监听；mock 裁剪或按 debug 引入。

- [ ] **L6 路由异常处理不一致**
  - 位置：[Discovery.ets](entry/src/main/ets/pages/Discovery.ets#L307)、[Favorites.ets](entry/src/main/ets/pages/Favorites.ets#L566)
  - 建议：统一 `RouterUtil` 包 try/catch。

- [ ] **L7 内容字段填充率不均**
  - 位置：`heritage_data.json`
  - 现状：64/184 事件无 figures，73/184 无 artifacts；事件图仅 8 张；龙山仅 1 条。
  - 建议：按事件补人物/文物/图集；龙山补充或调整筛选预期。

- [ ] **L8 `TimelineTab` 仍接收状态派生参数**
  - 位置：[Detail.ets](entry/src/main/ets/pages/Detail.ets#L312)、[Detail.ets](entry/src/main/ets/pages/Detail.ets#L809-L810)
  - 建议：改无参 Builder 直读 `this.heritage`，或独立组件 + `@Prop`。

- [ ] **L9 ImageGallery 不释放 PixelMap**
  - 位置：[ImageGallery.ets](entry/src/main/ets/components/ImageGallery.ets#L48-L50)、[ImageGallery.ets](entry/src/main/ets/components/ImageGallery.ets#L62-L88)
  - 建议：卸载时 `release()`；失败/替换时释放；缩略图限制解码尺寸。

- [ ] **L10 分布式 KV 明文存储**
  - 位置：[SyncService.ets](entry/src/main/ets/service/SyncService.ets#L111-L118)、[backup_config.json](entry/src/main/resources/base/profile/backup_config.json)
  - 问题：`encrypt:false`、S1；笔记/收藏明文；系统备份带走 Preferences。
  - 建议：评估 `encrypt:true` 或登记威胁模型；敏感内容提示。

---

## 4. 第一轮执行顺序

| 顺序 | 项 | 核心理由 | 进入条件 | 完成标志 |
|---|---|---|---|---|
| 1 | B1 权限 | 所有真机同步验证的前置 | 本文件建立 | 权限弹窗/授予/拒绝/重试闭环，构建成功 |
| 2 | H1 同步追赶 | 权限修好后才能验证数据是否真的收敛 | B1 完成 | 新设备/上线 PULL 可验证 |
| 3 | H2 删除墓碑 | 依赖 H1 的同步链路做双端验证 | H1 完成 | 删除/复活/并发编辑场景通过 |
| 4 | H3 笔记未保存 | 独立用户数据安全项，可与 H2 并行准备 | 无 | 返回确认闭环 |
| 5 | H4 API 口径 | 交付/验收决策，避免后续返工 | 前四项完成 | 配置与文档一致 |

**第一轮完成标准**：五项全部 `已完成`；`BUILD SUCCESSFUL`；O3 无新增；`PROJECT_PLAN/ISSUES_RISKS/REVISION_LOG/START_HERE` 同步；每项独立 commit。

**当前进度（2026-10-23）**：第一轮 B1、H1、H2、H3、H4 全部完成；第二轮 M1、M2、M3 已完成（代码/构建；设备验证待 O23/O24/O25/O7），下一步 M4 数据访问层去重。

---

## 5. 第一轮第 1 步：B1 任务卡

### 5.1 目标

补齐 `ohos.permission.DISTRIBUTED_DATASYNC` 的运行时申请与初始化门禁，保证真机上分布式 KV 能真正可用，同时不破坏本地模式。

### 5.2 API 证据（官方文档 + 本机 SDK 双重核对）

- 官方权限列表：`ohos.permission.DISTRIBUTED_DATASYNC`，权限级别 normal，**授权方式 user_grant**。
- 本机 SDK `PermissionDefinitions.json`：`grantMode: user_grant`。
- `@ohos.abilityAccessCtrl.d.ts`：
  - `createAtManager()`；
  - `checkAccessTokenSync(tokenID, permissionName)`（since 10）；
  - `requestPermissionsFromUser(context, permissionList)`（Promise，since 9）；
  - `requestPermissionOnSetting(context, permissionList)`（since 12，用于用户拒绝后的再次授权）；
  - `GrantStatus.PERMISSION_GRANTED = 0`。
- `@ohos.distributedDeviceManager.d.ts`：`getAvailableDeviceListSync()` 标注 `@permission ohos.permission.DISTRIBUTED_DATASYNC`，未授权抛 201。
- `PermissionRequestResult.authResults`：`0=已授权`，`-1=未授权`，`2=无效请求`。
- 官方说明：用户拒绝后，`requestPermissionsFromUser` **不能再次拉起弹窗**，需 `requestPermissionOnSetting` 或系统设置。

### 5.3 实现方案

1. 新增 `entry/src/main/ets/service/PermissionService.ets`
   - `isSyncPermissionGranted(): boolean`：`bundleManager.getBundleInfoForSelfSync(GET_BUNDLE_INFO_WITH_APPLICATION)` → `appInfo.accessTokenId` → `checkAccessTokenSync`。
   - `requestSyncPermission(context: common.UIAbilityContext): Promise<boolean>`：未授予时调用 `requestPermissionsFromUser`，解析 `authResults`；进程内只主动请求一次。
   - `requestSyncPermissionOnSetting(context: common.UIAbilityContext): Promise<boolean>`：用户拒绝后走 `requestPermissionOnSetting`，异常时回退 `isSyncPermissionGranted()`。
   - 所有可抛异常包 try/catch，不新增 O3 告警。
2. 修改 `SyncService.ets`
   - `init` 开头先判断权限；未授予则记日志并 return，**不设置** `initialized=true`。
   - `getKVStore().then` 成功后调用 `notifyStatusListeners()`（让同步面板从“单机模式”及时恢复）。
   - 暴露 `isPermissionGranted()` / `requestPermission(context)` / `requestPermissionOnSetting(context)`；授权成功后调用 `init(context)`。
3. 修改 `EntryAbility.ets`
   - `loadContent` 成功后调用一次 `SyncService.requestPermission(this.context)`；
   - `onForeground` 调 `SyncService.init(this.context)`，覆盖“去系统设置授权后返回”的场景。
4. 修改 `SyncPanel.ets`
   - 新增 `@State permissionGranted`；
   - 未授权时显示说明与“授权分布式同步”按钮；点击后先 `requestPermission`，仍失败再 `requestPermissionOnSetting`；
   - 授权成功后 `refresh()`，并提示“已授权，等待设备上线”。
5. 不改动任何数据文件、路由、模型；`FavoriteService` 仅通过 `SyncService.init` 的门禁自然降级。

### 5.4 验收与回归

- 构建：`BUILD SUCCESSFUL`，O3 告警按「文件+类型」无新增。
- 模拟器/真机：
  1. 首次启动出现权限弹窗；授予 → 同步面板显示“分布式同步已就绪”，0 台设备为预期；
  2. 拒绝 → 本地收藏/笔记/主题正常；面板显示未授权与重试按钮；
  3. 点重试 → 拉起设置授权；授予后返回 → 面板状态刷新；
  4. 杀进程重开 → 已授权不再弹窗，同步服务正常初始化。
- 无法验证项：真实双端同步仍归 O7 真机联调，不在本步冒充通过。

### 5.5 回滚

仅新增权限服务与初始化门禁；回滚删除新文件、还原 `SyncService.init`/`EntryAbility`/`SyncPanel` 改动即可，无数据迁移。

---

## 6. 变更记录

| 日期 | 变更 | 理由 |
|---|---|---|
| 2026-10-22 | 建立本文件，收录审计 1 阻塞 + 4 高 + 11 中 + 10 低，共 26 项；第一轮定为 B1/H1/H2/H3/H4；B1 开始执行 | 用户要求把审计项固化为第一轮优化目标，并按项目流程逐项实施 |
| 2026-10-22 | B1 完成代码与构建验证；新增 PermissionService、SyncService 权限门禁与 KV ready 通知、EntryAbility 启动申请、SyncPanel 授权入口；设备验证登记待 O7 | 构建 BUILD SUCCESSFUL，16 条 WARN 与 O3 一致；当前无连接设备，不能把弹窗/拒绝/重试验收标为已通过 |
| 2026-10-22 | 文件更名 `OPTIMIZATION_PLAN_V1.md`，增加 V1 版本标识；新增「已完成项显式标注」规则、完成汇总表；H1 完成并记录 | 用户要求文件名体现第一版、计划书已完成项必须标注；H1 代码/构建完成，双端验证待 O7 |
| 2026-10-22 | H2 删除墓碑完成并记录（commit `bdb18ee`）：新增 Tombstone 模型、三类实体墓碑持久化与 KV 覆盖写、实体/墓碑三路 LWW 合并、重新收藏版本推进、themeIds 墓碑校验、KV 未就绪待写队列与墓碑重放；双端验证登记 O20/O7 | 删除直接删键会导致离线旧记录复活、远端删除覆盖较新编辑；按审计建议以墓碑参与 LWW，并将无法在当前环境验证的双端场景如实登记 |
| 2026-10-22 | H3 笔记未保存退出保护完成并记录（commit `27378bc`）：新增原稿基准与脏标记、顶部/系统返回统一拦截、放弃修改确认弹层、离开流程标记；返回交互待设备验证（O21） | 原实现返回/系统返回直接离开，长笔记会静默丢失；按验收要求补齐「有修改才确认、取消留下、放弃才离开」闭环 |
| 2026-10-22 | H3 复核补强（commit `77d0e5f`）：载入原稿不覆盖已输入内容 | 复核发现加载期间 TextArea 可编辑，异步回填会覆盖用户早期输入并把脏标记误清零；改为仅在未修改时回填正文，原稿始终作为脏基准 |
| 2026-10-22 | H4 API 口径统一完成并记录：保持 `compatibleSdkVersion: 5.0.4(16)` 不变，README/PROJECT_PLAN/START_HERE/相关代码注释统一为「最低 API 16（任务书要求 ≥ 12）」；目标设备安装待 O22 | 任务书要求是 ≥ 12，当前最低 16 已满足；本机无 API 12 SDK/镜像，下调后无法做安装回归，按 H4 建议选择「统一文档口径为 API 16」而非未经验证的降级 |
| 2026-10-22 | 第二轮 M1 完成并记录（commit `7b9043d`，M6.6）：新增共享 DeviceIdentity（ODID 优先、UUID 回退与旧 store 迁移）、所有写入刷新 deviceId、nextUpdatedAt 严格递增、冲突台账记录胜方设备并在同步面板展示；残余 UUID 备份复制风险登记 O23 | 更新不刷新 deviceId 会让平局兜底指向创建者而非最后写入者；各服务独立生成 ID 导致跨实体判定不一致；墙钟回拨会让新编辑输给旧版本。按审计建议共享设备标识并显式化版本推进 |
| 2026-10-22 | 第二轮 M1 复核补强（commit `35f9dcf`）：回退设备标识从 Preferences 移到 `cacheDir/lww_device_id.txt` | 官方备份默认 includes 不包含 cache，彻底规避「备份恢复到新设备复制同一 deviceId」；cache 清理换 ID 仅影响平局归因，不影响数据与同步收敛 |
| 2026-10-23 | 第二轮 M2 完成并记录（commit `01bdb1e`，M6.7）：标签编辑器删除自定义标签改为本地暂存、保存时统一提交；取消不产生持久化副作用；同名重新新增视为撤销删除；交互待 O24 设备验证 | 原实现删除即全局落盘+同步，取消无法撤销；按审计建议区分编辑期与提交期 |
| 2026-10-23 | 第二轮 M3 完成并记录（commit `b1786b0`，M6.8）：MyNotes 订阅 FavoriteService.onDataChanged 并在 aboutToDisappear 用同一引用注销；保留 onPageShow 兜底；页面停留刷新待 O25 设备验证 | 页面停留时远端合并/其它页面增删笔记不会刷新，用户看到过期聚合列表；按审计建议补订阅闭环 |
