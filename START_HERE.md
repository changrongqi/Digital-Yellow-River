# START_HERE — 任意一次接手的入口（先读本文件，≤3 分钟）

黄河记忆 = 鸿蒙离线文化遗产 App。ArkTS/ArkUI，最低 API16 Stage（任务书要求 ≥12），零网络：rawfile 数据 + Preferences 本地 + distributedKVStore 同步。
仓库路径 `e:\HarmonyOS_coding`。
本文件只写**长期有效**的结构性信息；当前进度、数据统计、已知 bug 一律不写在此（会过期），按「当前状态去哪查」现场核实。

## 阅读顺序（只按需深入，勿一次通读全部）
1. 本文件（全部）
2. `PITFALLS.md`（编码前必读全文，41 条硬坑）
3. `PROJECT_PLAN.md` §0 速记 + §5 里程碑（要改计划才读全文）
4. 按任务：写内容 → `CONTENT_METHODOLOGY.md`；排障/构建告警 → `ISSUES_RISKS.md`；推进优化 → `OPTIMIZATION_PLAN_V1.md`；查决策史 → `REVISION_LOG.md`

## 不可违反（违反=返工）
- 禁 `any`、禁解构；build() 根节点前禁任何语句（含 const）
- @Builder 参数按值传递，状态不刷新；需实时状态就在 Builder 内直读 `this.x`（Index.TabLabel 是故意保留）
- 新路由页必须注册 `entry/src/main/resources/base/profile/main_pages.json`；跳转统一带 `id`
- 数据双份同构：rawfile `heritage_data.json` + `MockHeritages.ets`；唯一解析入口 `HeritageDataLoader.parseHeritageList`
- JSON 正文内嵌引号用中文「」；mock 模板串内换行写 `\\n`；整表 0 条=失败并抛异常
- 用户数据 Favorite/Note/Theme 必有 `deviceId`+`updatedAt`；`deviceId` 统一由 `DeviceIdentity` 提供（ODID 优先，回退 UUID 存 cacheDir 不随备份复制）且每次写入刷新；冲突 LWW（新者胜，平局 deviceId 字典序小者胜）；`updatedAt`/墓碑 `deletedAt` 严格递增
- 分布式键前缀 `fav_`/`note_`/`theme_`；独立 Preferences store：`yellow_river_user_data`、`yellow_river_themes`
- 删除用户数据写墓碑（`deletedAt`+`deviceId`）覆盖同一 KV 键并参与 LWW，禁直接删键；KV 未就绪时的写入排队，ready 后补写
- 笔记编辑页返回必须拦截未保存修改：脏基准=载入原文；顶部返回与系统返回共用 `handleBack`；保存/删除后直接离开
- 编辑弹层中的删除/修改先本地暂存，保存时统一提交；取消/关闭必须无持久化与同步副作用（标签/主题/笔记同理）
- 服务层订阅：`aboutToAppear` 用稳定函数引用注册，`aboutToDisappear` 用同一引用注销；不要在 `onPageShow` 重复注册
- 数据刷新单通道：使用数据的页面直接订阅服务，父容器（Index）不中转刷新信号；同一逻辑操作的多条服务通知合并为一次刷新
- 无障碍与可读性：glyph 控件补 `accessibilityText` + `accessibilityLevel('yes')`，选择项补 `accessibilitySelected`；关键触控区 ≥44vp；文字对比度 ≥4.5:1（按实际背景核算）；禁用 API 18 的 `accessibilityRole`（最低运行 API16）
- 色彩模式：本应用只支持浅色；`setColorMode(COLOR_MODE_LIGHT)` 必须在 `loadContent` 成功回调内调用；系统栏浅底深字；要支持深色必须先完成 L1 token + 全套 dark 资源
- 滚动定位：滚动容器内让指定内容进入视野时，用 `onAreaChange` 的 `position`（父坐标系=滚动内容坐标，不用 globalPosition 换算）作为 `scrollTo` 目标；已可见不滚，首次渲染未测量时由回调补滚
- 大屏限宽：正文内容列用 `.width('100%') + constraintSize({ maxWidth: 680 })`，靠 Scroll `.align(Alignment.Top)` 居中；禁止写死 `.width(680)`（手机窄屏溢出）
- 推荐转收藏：推荐节点转主题藏品必须「判重 `isFavorite` → `addFavorite` → 取记录追加 themeId → `updateFavoriteThemes`」，禁用 `toggleFavorite`；两次通知用暂挂标志合并为一次刷新；成功后把选中种类从 `RECOMMEND` 切为 `HERITAGE` 再刷新，否则信息卡会被清空
- 设计 token：中性色统一用 `utils/ThemeTokens`（背景/文字/边框/操作/状态）；`#FFFFFF` 按「文字/描边」与「卡片/表面」语义分流；EraTheme 与 Theme 色板是业务数据，禁止并入 token
- 元信息：bundleName 为 `com.huanghe.memory`，与 `SyncService.BUNDLE_NAME` 必须一致；应用名「黄河记忆」
- 本地门禁：提交前跑 `scripts/ci-check.ps1`（规则检查 + clean 构建 + 33 个本地单测 + 告警基线 4）；`hvigorw test` 失败不改退出码，必须解析 test_result.txt
- 派生数据：筛选/排序结果缓存到 `@State`（变化入口重算，build 内不调用原函数）；关联计数用一次 Map 聚合；服务通知无法分类型时用签名判断是否重算
- 路由：页面禁止直接调用 `router`，统一走 `utils/RouterUtil`；push 参数用 `RouteParams`，getParams 返回 `Record<string, Object>`（对 interface 下标访问会触发 arkts-no-props-by-index）
- 内容缺口：人物/文物/图片无可靠来源时保持为空，页面隐藏对应区块，禁止虚构；缺口见 ISSUES_RISKS O35
- 预置数据加载统一走 `HeritageRepository`（`{list,byId,isMock}`）；JSON 字段统一 `JsonField`；`detail` 缺失/null/非对象降级为空 detail，不得丢整条
- mock 数据 id 必须与 rawfile 正式 id 完全一致（禁 `mock-*` 前缀）；图谱节点只保留 key/label/kind/样式/坐标，未读字段及时删除
- API 口径以 `build-profile.json5` 为准：最低 API16（任务书要求 ≥12），文档禁写死 12；下调最低版本必须配套 SDK 与安装回归
- 零网络；图片只能放 `resources/rawfile/images/` 并由 `path` 引用
- 同文件禁并行改；改完回读；一次一个子任务 → build 成功 → commit `[M?.?] 摘要`
- 计划书可改，但理由必须写进 `REVISION_LOG.md`；「改计划」优先于「绕过计划」

## 构建验证（PowerShell，项目根目录）
```powershell
$env:DEVECO_SDK_HOME='E:\DevEco Studio\sdk'
$env:NODE_HOME='E:\DevEco Studio\tools\node'
$env:Path='E:\DevEco Studio\jbr\bin;'+$env:Path
& 'E:\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
判据：`BUILD SUCCESSFUL`；WARN 按 `ISSUES_RISKS.md` O3 基线以「文件+类型」比对，行号漂移不算新增。
一键门禁：`powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci-check.ps1`（规则检查 + clean 构建 + 本地单测 + 告警/测试结果校验）。

## 当前状态去哪查（每次接手都现场核实，勿信文档声称）
- 进度：`PROJECT_PLAN.md` §5 状态表 + 实际代码，两者不一致时以代码为准
- 优化：`OPTIMIZATION_PLAN_V1.md`（26 项分级/依赖/轮次/验收，状态唯一权威；与 §5 M6 配合）
- 数据：用 PowerShell `ConvertFrom-Json` 统计 rawfile 条数/字段；mock 需模拟模板求值（`\\n`→`\n`）后再 `JSON.parse` 校验
- 问题：`ISSUES_RISKS.md` 的 O 系列（R 系列为阶段前置项，需清零）
- 历史：`REVISION_LOG.md` + `git log`

## 工作流
1. 读本文件 + PITFALLS + 相关分册
2. 跑一次 build，确认基线与告警无新增
3. 一次只做一个子任务；动手前查官方文档 + 本机 SDK d.ts
4. build 成功 → 更新 `PROJECT_PLAN.md` 状态 → 记 `REVISION_LOG.md` → commit `[M?.?] 摘要`
5. 发现新坑/新问题：先补 `PITFALLS.md` / `ISSUES_RISKS.md`，再提交
