# 踩坑清单（必须遵守，遇坑及时补充）

> 本文件是 [PROJECT_PLAN.md](PROJECT_PLAN.md) 原 §6 的独立分册，原 21 条内容原样迁移（无删改），C1.4 新增第 22 条，C1.5 新增第 23 条，M6.1 新增第 24 条。
> 下文「使用纪律」为硬约束：每个子任务开工前通读全文，编码过程中逐条自查（尤其第 1~5、13、15、16 条），提交前再对照一次；踩到新坑立即补条目并同步 REVISION_LOG.md。

## 6. 踩坑清单（必须遵守，遇坑及时补充）

> **使用纪律**：① 每个子任务开工前通读本清单全文；② 编码过程中逐条自查（尤其第 1~5、13、15、16 条属 ArkUI/ArkTS 声明式约束，最容易反复踩）；
> ③ 提交前再对照一次；④ 踩到新坑立即补条目并同步 REVISION_LOG.md，禁止只改代码不改清单。
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
22. **Canvas 组件三个高频坑（C1.4 图谱重构实测）**：① **Canvas 不会因 @Prop 变化自动重绘**——即使 `@Prop heritages` 已更新，`onReady`/`onAreaChange` 不触发就仍是旧画面；必须给每个影响画面的 @Prop 加 `@Watch` 回调重绘（O9 根因），并对「同对象改字段」（如主题重命名）用版本号兜底。② **自定义组件字段名不能与 CustomComponent 内置属性同名**——本次把视口缩放字段命名为 `scale`，编译报 `Property 'scale' is not assignable to ... CustomComponent`（内置 `scale()` 是通用属性方法）；改用 `viewScale` 等前缀命名，同理避开 `width`/`height`/`position`/`clip`/`opacity` 等。③ **滚动容器内做画布交互不要用裸 `onTouch`**——外层 `Scroll` 的滑动手势会与画布拖动竞争，裸 onTouch 无法稳定抢到手势；改用 `GestureGroup(Exclusive(Tap, Parallel(Pan, Pinch)))` 绑定在 Canvas 上，子组件自定义手势默认优先于父级 Scroll（官方 FAQ：父子同类型手势默认子组件优先），平移/缩放/点选才能各自稳定识别。另附：Canvas 若自行 `fillRect` 铺底色会盖住父卡片 `borderRadius` 圆角，正确做法是 Canvas 不填充、父容器设底色 + `.clip(true)`。
23. **Heritage 的 era/type/city 是字符串枚举，不能与空串 `''` 比较（C1.5 实测）**：在 GraphLayout/KnowledgeGraph 写 `if (item.era !== '' && item.era === anchor.era)` 时 ArkTS 直接报 `This comparison appears to be unintentional because the types 'HeritageEra' and '""' have no overlap`（HeritageCity/HeritageType 同）——虽然运行值是中文字符串，类型上并不与 `''` 重叠。规则：模型层的这三个字段已保证是合法枚举，**直接做相等比较**；「空值」只存在于未解析 JSON 层，应在 Loader 解析时处理，不要下沉到业务/布局层。
24. **user_grant 权限不能只声明，必须运行时申请；用户拒绝后同一 API 不能再弹窗（M6.1 实测 + 官方文档）**：`ohos.permission.DISTRIBUTED_DATASYNC` 在本机 SDK `PermissionDefinitions.json` 中是 `grantMode: user_grant`，只在 `module.json5` 声明不会自动授权。未授权时 `distributedDeviceManager.getAvailableDeviceListSync()` 抛 201；若业务层 catch 后返回空数组，界面会把它误显示成「暂无在线设备/单机模式」，与 O7 的蓝牙组网问题混在一起。规则：① 查询用 `bundleManager.getBundleInfoForSelfSync(GET_BUNDLE_INFO_WITH_APPLICATION).appInfo.accessTokenId` + `abilityAccessCtrl.checkAccessTokenSync`（API 10+；不要用 API 20+ 的 `getSelfPermissionStatus`，会超出兼容下限）；② 首次申请用 `abilityAccessCtrl.createAtManager().requestPermissionsFromUser(UIAbilityContext, [permission])`，解析 `authResults`（0=授予，-1=拒绝，2=无效请求）；③ 用户拒绝后 `requestPermissionsFromUser` **不能再次拉起弹窗**，需 `requestPermissionOnSetting`（API 12+）或引导去系统设置；④ 权限应作为同步初始化门禁：未授权时不要置 `initialized=true`，授权成功后必须能重试初始化；⑤ 服务层不要直接弹窗（拿不到 UIAbilityContext），由 EntryAbility/SyncPanel 发起。
