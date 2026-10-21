# START_HERE — 接手入口（先读本文件，≤3 分钟）

黄河记忆 = 鸿蒙离线文化遗产 App。ArkTS/ArkUI，API12 Stage，零网络：rawfile 数据 + Preferences 本地 + distributedKVStore 同步。
仓库路径 `e:\HarmonyOS_coding`。代码可编译，但**内容/部分功能未达计划书宣称状态**，见「真实状态」「已知缺陷」。

## 阅读顺序（只按需深入，勿一次通读全部）
1. 本文件（全部）
2. `PITFALLS.md`（编码前必读全文，21 条硬坑）
3. `PROJECT_PLAN.md` §0 速记 + §5 里程碑（要改计划才读全文）
4. 按任务：写内容 → `CONTENT_METHODOLOGY.md`；排障/构建告警 → `ISSUES_RISKS.md`；查决策史 → `REVISION_LOG.md`

## 不可违反（违反=返工）
- 禁 `any`、禁解构；build() 根节点前禁任何语句（含 const）
- @Builder 参数按值传递，状态不刷新；需实时状态就在 Builder 内直读 `this.x`（Index.TabLabel 是故意保留）
- 新路由页必须注册 `entry/src/main/resources/base/profile/main_pages.json`；跳转统一带 `id`
- 数据双份同构：rawfile `heritage_data.json` + `MockHeritages.ets`；唯一解析入口 `HeritageDataLoader.parseHeritageList`
- JSON 正文内嵌引号用中文「」；mock 模板串内换行写 `\\n`；整表 0 条=失败并抛异常
- 用户数据 Favorite/Note/Theme 必有 `deviceId`+`updatedAt`；冲突 LWW（新者胜，平局 deviceId 字典序小者胜）
- 分布式键前缀 `fav_`/`note_`/`theme_`；独立 Preferences store：`yellow_river_user_data`、`yellow_river_themes`
- 零网络；图片只能放 `resources/rawfile/images/` 并由 `path` 引用
- 同文件禁并行改；改完回读；一次一个子任务 → build 成功 → commit `[M?.?] 摘要`
- 计划书可改，但理由必须写进 `REVISION_LOG.md`；「改计划」优先于「绕过计划」

## 真实状态（2026-10-21 实测，勿信文档声称）
- 构建：`BUILD SUCCESSFUL`；16 条 deprecation WARN + 1 条 skip sign，与 O3 基线一致
- 代码：M1~M4 完成；M5 C1.1~C1.3 完成；C2/C3 未开始
- 数据 rawfile：23 遗址、184 事件（每址 8 条）、事件 figures 120/184、artifacts 111/184；事件图集仅 6 条有内容
- 数据缺口：`poems` **0 条**；23 条 `coverImage` 全空；92 条遗址图集 `path` 全空
- UI：详情页实际页签 = 介绍/考古/事件/文旅/笔记；**无诗词是已定方案**（用户已从计划删除该板块）
- git：接手时先 `git status` 确认工作区；文档已拆分并提交

## 已知缺陷（按优先级）
- P0 `entry/src/main/ets/data/MockHeritages.ets`：`MOCK_JSON` 从第 11 条 `mock-shaolin-01` 起结构损坏（12 处裸 `{` + 12 处多余 `}`，首错 position 140731 / 源行约 2503），`JSON.parse` 必失败 → 预览器兜底全空。rawfile 同样内容合法。修法：删无缩进的裸行，并在 mock 侧验证 parse 出 23 条
- 非缺陷（勿修）诗词板块已由用户从计划中删除：`poems` 空字段（0 条）与 Detail 无诗词页签均为预期，保留空变量不影响业务，暂不处理；README/计划书残留「诗词」表述仅口径问题，不补内容/页签
- P1 `components/graph/GraphCanvas.ets` 只在 `onReady`/`onAreaChange` 重绘；切主题/增删归类后 Canvas 可能仍显示旧图。需为 `@Prop theme/heritages` 加 `@Watch`
- P2 `pages/KnowledgeGraph.ets` 空主题分支只有「归类管理」，没有重命名/删除入口 → 空主题无法管理
- P2 `service/SyncService.ets` `getKVStore().then` 成功后未 `notifyStatusListeners()`；面板若早于 KV 就绪构建，可能一直显示「单机模式」
- P3 图片全空（O1）；`router` API deprecated 为已知技术债（不要顺手重构）
- P3 模拟器无蓝牙，无法真实组网（O7 已实证）；同步/LWW 只能真机验收

## 验证命令（PowerShell，项目根目录）
```powershell
$env:DEVECO_SDK_HOME='E:\DevEco Studio\sdk'
$env:NODE_HOME='E:\DevEco Studio\tools\node'
$env:Path='E:\DevEco Studio\jbr\bin;'+$env:Path
& 'E:\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
判据：`BUILD SUCCESSFUL`；WARN 与 O3 基线按「文件+类型」比对，行号漂移不算新增。

## 接手第一步（建议顺序）
1. 读 PITFALLS；跑一次 build 确认基线
2. 修 P0（mock JSON），用 Node 模拟模板求值后 `JSON.parse` 验证 23 条
3. 诗词板块已删，勿补；仅需时统一 README/计划书口径
4. 修 GraphCanvas @Watch、空主题入口、SyncService 通知
5. 内容继续深写前，先读 CONTENT_METHODOLOGY 并保持双份同步
