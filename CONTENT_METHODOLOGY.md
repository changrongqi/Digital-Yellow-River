# 内容深写与搜证方法论

> 本文件是 [PROJECT_PLAN.md](PROJECT_PLAN.md) 原 §1.1 的独立分册，内容原样迁移（无删改）。
> 适用场景：M1.7 起的每批遗址深写、事件子详情（M1.8）、文旅深度化（M1.9）、遗址/事件图集（M1.10）。**动手写内容前必读**，按此方法论执行。

## 1.1 内容深写与搜证方法论（M1.7~M1.9 实践提炼，持续更新）

> 本小节把「联网搜证 + 深写」的实操方法沉淀为规范，后续每批遗址深写都按此执行。

- **搜证来源优先级**：遗址所在地**县政府官网**（简介/开馆公告/A 级景区名录，如渑池县政府）> **省级文物局/文旅厅** > 省政府门户（市县栏目）> **国家文物局官网**（含「中国考古百年」专栏、博物馆年报系统）> 新华社/人民日报/河南日报等权威媒体 > 政协/方志等地方史料 > 实地攻略（仅参考参观动线与体验描述，数字一律以官方为准）。
- **核证纪律**：① 关键数字（年代/面积/开放时间/电话/出土数量）必须至少 1 个官方来源；② 两条官方来源数字冲突时（如第四次发掘面积 600㎡ vs 200㎡），以最新县政府口径为准，正文不写死争议数；③ 每条事件 furtherReading 注明「机构《篇名》（日期）」全称；④ 新增亮点（如玉钺=军事王权、酿酒工艺）必须能在官方报道中找到对应表述，禁止从科普自媒体转述未经官方证实的说法。
- **事件深写结构**（HeritageEvent 字段填写顺序）：year+title（时间轴主文案）→ summary（一句话概述）→ background（时代背景/前因）→ process（具体经过：日期/人物/器物细节）→ impact（意义/后续影响）→ figures/artifacts（人物与文物清单，宁缺毋滥）→ commentary（深度解说：官方研究细节/学者评价/冷知识）→ furtherReading（来源出处，2~4 个）。
- **文旅深写结构**（TourismInfo）：overview（公园/景区概览、荣誉、场馆简介）→ guide（hours/tickets/contact/address 四键值，**以最新开馆公告为准**）→ itinerary（建议时长 / 推荐动线 / 交通 / 串联联动景区，`\n` 分段）→ interpretation（「看什么、怎么看」按维度分点：地层/器物/聚落/考古史等）。
- **双份同步纪律（R3）**：rawfile 与 Mock 同构；Mock 模板字符串内 `\n` 写 `\\n`（踩坑 19）；每批写毕用 PowerShell `ConvertFrom-Json`（rawfile）+ Node 模拟「模板求值→JSON.parse」（mock）双份校验条数/字段。
- **图片资源现状（2026-10-25 已接入）**：早期实测 WebSearch 配图链接经代理缓存不可稳定下载、版权无法核证，因此先做结构（M1.10 图集 + Lightbox）。现有 123 张已核证素材（来源与授权见 `pictures/MANIFEST.md` 与 `pictures/_manifest.json`），已全部拷入 `entry/src/main/resources/rawfile/images/` 并在 rawfile 与 MockHeritages 双份填入：23 张列表封面（`coverImage`）、92 张详情图集（`detail.images[].path`）、8 张事件图（`events[].images[].path`）。HAP 由 2.4MB 增至约 21MB，属离线包预期成本。
- **图片命名与填法**：`images/<site-id>/cover.jpg`（列表封面）、`images/<site-id>/01.jpg ~ 04.jpg`（详情图集，按数组顺序）、`images/<site-id>/e<NN>-<MM>.jpg`（第 NN 个事件第 MM 张图，事件下标从 0 起、按现有槽位对齐）。新增图片时：① 文件放入 `rawfile/images/<site-id>/`；② rawfile 与 Mock 的对应 `path` 同步填相对路径（`images/...`），caption 写图注、source 写官方来源；③ 无需改代码——ImageGallery 与列表 `CoverImage` 都按 path 动态加载；④ 用 Node 脚本对两份数据做解析校验（条数/路径非空数/按 id 排序后深度相等），避免只改一份（R3）。
