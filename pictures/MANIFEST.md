# 图片资源清单 / Pictures Index

> 本目录仅存放图片资源，未改动项目任何其它文件。图片按数据条目一一对应命名，便于后续在 `heritage_data.json` / `MockHeritages.ets` 的 `path` 字段中直接引用（相对 `resources/rawfile/` 使用，例如 `images/smx-yangshao-01/01.jpg`）。

## 目录结构

```
pictures/
└── images/
    └── <site-id>/
        ├── cover.jpg      # 列表封面（对应 coverImage）
        ├── 01.jpg ~ 04.jpg # 详情页「遗址图集」(detail.images，按数组顺序)
        └── e<NN>-<MM>.jpg  # 历史事件图集 (events[i].images[j])
```

### 仰韶村遗址（`smx-yangshao-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/smx-yangshao-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/smx-yangshao-01/01.jpg` | `detail.images[0]` | 仰韶村遗址全景（北依韶山的黄土台地地貌） ✅ |
| `images/smx-yangshao-01/02.jpg` | `detail.images[1]` | 小口尖底瓶（距今6000—5000年，残留物检出发酵酒） ✅ |
| `images/smx-yangshao-01/03.jpg` | `detail.images[2]` | 1921年首次科学发掘现场（安特生、袁复礼主持） ✅ |
| `images/smx-yangshao-01/04.jpg` | `detail.images[3]` | 仰韶文化博物馆（2024年9月全新开馆） ✅ |
| `images/smx-yangshao-01/e02-01.jpg` | `events[1].images[0]` | 中国第一次科学考古发掘：仰韶文化命名，中国现代考古学诞生 / 中国第一张田野考古地形图（袁复礼绘制） ✅ |
| `images/smx-yangshao-01/e02-02.jpg` | `events[1].images[1]` | 中国第一次科学考古发掘：仰韶文化命名，中国现代考古学诞生 / 安特生旧居（村民王二保家老窑洞） ✅ |
| `images/smx-yangshao-01/e06-01.jpg` | `events[5].images[0]` | 第四次考古发掘启动，多学科手段全面介入 / 青灰色「混凝土」式地坪（第四次发掘发现） ✅ |
| `images/smx-yangshao-01/e07-01.jpg` | `events[6].images[0]` | 「百年百大」荣誉与多学科新成果：象牙镯形器、5000年前发酵酒 / 象牙镯形器（第四次发掘首次发现，钻孔工艺精良） ✅ |
| `images/smx-yangshao-01/e07-02.jpg` | `events[6].images[1]` | 「百年百大」荣誉与多学科新成果：象牙镯形器、5000年前发酵酒 / 玉钺（军事王权象征，仰韶村遗址首次发现） ✅ |

### 虢国墓地（`smx-guoguo-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/smx-guoguo-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/smx-guoguo-01/01.jpg` | `detail.images[0]` | 虢国博物馆外景（遗址上专题性遗址类博物馆） ✅ |
| `images/smx-guoguo-01/02.jpg` | `detail.images[1]` | 玉柄铁剑（「中华第一剑」，通长34.2厘米） ✅ |
| `images/smx-guoguo-01/03.jpg` | `detail.images[2]` | 一号车马坑（虢季陪葬坑，13车64马军阵） ✅ |
| `images/smx-guoguo-01/04.jpg` | `detail.images[3]` | 缀玉瞑目（58件玉饰，金缕玉衣雏形） ✅ |
| `images/smx-guoguo-01/e01-01.jpg` | `events[0].images[0]` | 三门峡水利枢纽建设中虢国墓地现世，车马坑获原地保护 / 三门峡市车马坑陈列馆（1956年原地保护车马坑，5车10马） ✅ |
| `images/smx-guoguo-01/e03-01.jpg` | `events[2].images[0]` | 虢季墓（M2001）发掘：玉柄铁剑出土，入选全国十大考古新发现 / 玉柄铁剑（「中华第一剑」，通长34.2厘米） ✅ |
| `images/smx-guoguo-01/e04-01.jpg` | `events[3].images[0]` | 虢仲墓（M2009）发掘：出土玉器冠绝周代，蝉联全国十大考古新发现 / 虢仲墓（M2009）出土白玉器（西周玉礼文化典型代表） ✅ |

### 二里头遗址（`ly-erlitou-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/ly-erlitou-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/ly-erlitou-01/01.jpg` | `detail.images[0]` | 二里头遗址航拍图（伊洛河间高地，现存约300万平方米） ✅ |
| `images/ly-erlitou-01/02.jpg` | `detail.images[1]` | 绿松石龙形器（64.5厘米，2000余片绿松石） ✅ |
| `images/ly-erlitou-01/03.jpg` | `detail.images[2]` | 二里头夏都遗址博物馆（2019年10月开馆） ✅ |
| `images/ly-erlitou-01/04.jpg` | `detail.images[3]` | 乳钉纹青铜爵（中国最早的青铜酒器之一） ✅ |

### 龙门石窟（`ly-longmen-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/ly-longmen-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/ly-longmen-01/01.jpg` | `detail.images[0]` | 卢舍那大佛（奉先寺主佛，通高17.14米） ✅ |
| `images/ly-longmen-01/02.jpg` | `detail.images[1]` | 奉先寺大卢舍那像龛（九尊大像群雕） ✅ |
| `images/ly-longmen-01/03.jpg` | `detail.images[2]` | 龙门石窟远眺（伊河两岸崖壁窟龛） ✅ |
| `images/ly-longmen-01/04.jpg` | `detail.images[3]` | 宾阳中洞主佛（北魏「秀骨清像」） ✅ |

### 殷墟（`ay-yinxu-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/ay-yinxu-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/ay-yinxu-01/01.jpg` | `detail.images[0]` | 殷墟宫殿宗庙遗址（商代晚期王都核心区） ✅ |
| `images/ay-yinxu-01/02.jpg` | `detail.images[1]` | YH127甲骨窖穴（1936年出土17096片甲骨） ✅ |
| `images/ay-yinxu-01/03.jpg` | `detail.images[2]` | 妇好墓出土文物（妇好鸮尊等1928件随葬品） ✅ |
| `images/ay-yinxu-01/04.jpg` | `detail.images[3]` | 殷墟博物馆新馆（2024年2月开馆） ✅ |

### 郑州商城遗址（`zz-shangcheng-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/zz-shangcheng-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/zz-shangcheng-01/01.jpg` | `detail.images[0]` | 郑州商城商代城墙（3600年夯土城墙，高出地面4—5米） ✅ |
| `images/zz-shangcheng-01/02.jpg` | `detail.images[1]` | 杜岭方鼎（通高100厘米、重86.4公斤，河南博物院镇院之宝） ✅ |
| `images/zz-shangcheng-01/03.jpg` | `detail.images[2]` | 郑州商都遗址博物院（2022年7月开馆） ✅ |
| `images/zz-shangcheng-01/04.jpg` | `detail.images[3]` | 书院街墓地金覆面（2022年出土，中原首见商代金覆面） ✅ |

### 北宋东京城遗址（`kf-bianliang-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/kf-bianliang-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/kf-bianliang-01/01.jpg` | `detail.images[0]` | 州桥石壁浮雕（海马瑞兽祥云，通高3.3米、总长约30米） ✅ |
| `images/kf-bianliang-01/02.jpg` | `detail.images[1]` | 州桥及汴河遗址考古现场（4400平方米探方） ✅ |
| `images/kf-bianliang-01/03.jpg` | `detail.images[2]` | 北宋东京城平面布局图（三重城与御街） ✅ |
| `images/kf-bianliang-01/04.jpg` | `detail.images[3]` | 明代州桥复原图（李琛手绘） ✅ |

### 戚城遗址（`py-qi-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/py-qi-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/py-qi-01/01.jpg` | `detail.images[0]` | 戚城遗址古城垣（东周夯土城墙，最高残存8.5米） ✅ |
| `images/py-qi-01/02.jpg` | `detail.images[1]` | 会盟台（春秋夯筑高台，七次诸侯会盟之地） ✅ |
| `images/py-qi-01/03.jpg` | `detail.images[2]` | 「中华第一龙」蚌塑龙形图案（距今6500余年） ✅ |
| `images/py-qi-01/04.jpg` | `detail.images[3]` | 子路墓祠（子路博物馆，「仲夫子祠」） ✅ |

### 偃师商城遗址（`ly-yanshi-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/ly-yanshi-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/ly-yanshi-01/01.jpg` | `detail.images[0]` | 偃师商城遗址宫城区四号宫殿遗址保护展示 ✅ |
| `images/ly-yanshi-01/02.jpg` | `detail.images[1]` | 大城西城垣遗址（三重城垣格局） ✅ |
| `images/ly-yanshi-01/03.jpg` | `detail.images[2]` | 偃师商城宫城复原效果图 ✅ |
| `images/ly-yanshi-01/04.jpg` | `detail.images[3]` | 水系遗存（倒「几」字形水道，商代最早最完备城市水系） ✅ |

### 汉魏洛阳故城（`ly-hanwei-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/ly-hanwei-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/ly-hanwei-01/01.jpg` | `detail.images[0]` | 太极殿遗址（「正殿之祖」，2015年度全国十大考古新发现） ✅ |
| `images/ly-hanwei-01/02.jpg` | `detail.images[1]` | 阊阖门遗址（迄今年代最早的连接双阙的宫城城门） ✅ |
| `images/ly-hanwei-01/03.jpg` | `detail.images[2]` | 铜驼街遗址（车辙石板路面，中轴线御道） ✅ |
| `images/ly-hanwei-01/04.jpg` | `detail.images[3]` | 汉魏洛阳故城遗址博物馆（高台阙楼形制，2025年开放） ✅ |

### 王城岗遗址（`zz-wangchenggang-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/zz-wangchenggang-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/zz-wangchenggang-01/01.jpg` | `detail.images[0]` | 王城岗龙山大城城墙（中原龙山晚期最大城址） ✅ |
| `images/zz-wangchenggang-01/02.jpg` | `detail.images[1]` | 王城岗遗址远景（告成镇，嵩山背景下） ✅ |
| `images/zz-wangchenggang-01/03.jpg` | `detail.images[2]` | 奠基坑遗迹（筑城人牲祭祀实证） ✅ |
| `images/zz-wangchenggang-01/04.jpg` | `detail.images[3]` | 登封观星台（相邻地标，元代郭守敬创建） ✅ |

### 少林寺常住院（`zz-shaolin-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/zz-shaolin-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/zz-shaolin-01/01.jpg` | `detail.images[0]` | 少林寺常住院山门（「天下第一名刹」） ✅ |
| `images/zz-shaolin-01/02.jpg` | `detail.images[1]` | 千佛殿《五百罗汉朝毗卢》壁画（明代） ✅ |
| `images/zz-shaolin-01/03.jpg` | `detail.images[2]` | 少林寺塔林（中国现存规模最大的古塔建筑群） ✅ |
| `images/zz-shaolin-01/04.jpg` | `detail.images[3]` | 少林功夫表演（少林武术发源地） ✅ |

### 邙山陵墓群（`ly-mangshan-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/ly-mangshan-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/ly-mangshan-01/01.jpg` | `detail.images[0]` | 邙山陵墓群田野封土冢（「北邙山头少闲土」） ✅ |
| `images/ly-mangshan-01/02.jpg` | `detail.images[1]` | 北魏宣武帝景陵地宫（洛阳古墓博物馆） ✅ |
| `images/ly-mangshan-01/03.jpg` | `detail.images[2]` | 东汉大汉冢（符合文献记载的东汉帝陵墓冢） ✅ |
| `images/ly-mangshan-01/04.jpg` | `detail.images[3]` | 洛阳古墓博物馆（河南古代壁画馆） ✅ |

### 巩义黄冶三彩窑址（`zz-huanye-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/zz-huanye-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/zz-huanye-01/01.jpg` | `detail.images[0]` | 黄冶唐三彩窑址（黄冶河两岸窑场分布，文化堆积厚达3米以上） ✅ |
| `images/zz-huanye-01/02.jpg` | `detail.images[1]` | 巩义窑窑炉/作坊遗迹（2002—2004年发掘） ✅ |
| `images/zz-huanye-01/03.jpg` | `detail.images[2]` | 三彩鹅衔梅花杯（巩义市博物馆藏） ✅ |
| `images/zz-huanye-01/04.jpg` | `detail.images[3]` | 唐青花蓝釉点彩水注（巩义市博物馆藏） ✅ |

### 开宝寺塔（铁塔）（`kf-tieta-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/kf-tieta-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/kf-tieta-01/01.jpg` | `detail.images[0]` | 开封铁塔全景（八角十三层琉璃砖塔） ✅ |
| `images/kf-tieta-01/02.jpg` | `detail.images[1]` | 铁塔琉璃花砖（佛龛/乐伎等50余种图案） ✅ |
| `images/kf-tieta-01/03.jpg` | `detail.images[2]` | 铁塔公园「天下第一塔」石碑 ✅ |
| `images/kf-tieta-01/04.jpg` | `detail.images[3]` | 接引殿（铁塔公园内，供奉北宋接引佛） ✅ |

### 繁塔（`kf-fanta-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/kf-fanta-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/kf-fanta-01/01.jpg` | `detail.images[0]` | 繁塔全貌（六角形楼阁式青砖塔，躯粗首小状似编钟） ✅ |
| `images/kf-fanta-01/02.jpg` | `detail.images[1]` | 繁塔佛像砖（一砖一佛，形象百余种） ✅ |
| `images/kf-fanta-01/03.jpg` | `detail.images[2]` | 二层塔心室伎乐砖（1982年重新发现） ✅ |
| `images/kf-fanta-01/04.jpg` | `detail.images[3]` | 禹王台公园古吹台牌坊（清代） ✅ |

### 庙底沟遗址（`smx-miaodigou-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/smx-miaodigou-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/smx-miaodigou-01/01.jpg` | `detail.images[0]` | 庙底沟花瓣纹彩陶（「中华文明之花」） ✅ |
| `images/smx-miaodigou-01/02.jpg` | `detail.images[1]` | 庙底沟遗址考古发掘现场 ✅ |
| `images/smx-miaodigou-01/03.jpg` | `detail.images[2]` | 三门峡庙底沟博物馆（《花开中国》展厅） ✅ |
| `images/smx-miaodigou-01/04.jpg` | `detail.images[3]` | 庙底沟遗址公园景观 ✅ |

### 函谷关（`smx-hangu-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/smx-hangu-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/smx-hangu-01/01.jpg` | `detail.images[0]` | 函谷关「鼎」字形关楼 ✅ |
| `images/smx-hangu-01/02.jpg` | `detail.images[1]` | 太初宫（老子著《道德经》处） ✅ |
| `images/smx-hangu-01/03.jpg` | `detail.images[2]` | 函关古道（汉唐宋车辙遗迹） ✅ |
| `images/smx-hangu-01/04.jpg` | `detail.images[3]` | 老子圣像与道德天书（老子广场） ✅ |

### 西水坡遗址（`py-xishuipo-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/py-xishuipo-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/py-xishuipo-01/01.jpg` | `detail.images[0]` | 「中华第一龙」蚌塑龙（中国国家博物馆藏） ✅ |
| `images/py-xishuipo-01/02.jpg` | `detail.images[1]` | M45墓蚌塑龙虎图案复原场景 ✅ |
| `images/py-xishuipo-01/03.jpg` | `detail.images[2]` | 西水坡遗址发掘现场（1987年） ✅ |
| `images/py-xishuipo-01/04.jpg` | `detail.images[3]` | 戚城考古遗址公园·中华第一龙遗址陈列馆 ✅ |

### 回銮碑（`py-huailuan-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/py-huailuan-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/py-huailuan-01/01.jpg` | `detail.images[0]` | 回銮碑（契丹出境碑） ✅ |
| `images/py-huailuan-01/02.jpg` | `detail.images[1]` | 御井（「御井甘泉」开州八景） ✅ |
| `images/py-huailuan-01/03.jpg` | `detail.images[2]` | 澶渊之盟纪念馆 ✅ |
| `images/py-huailuan-01/04.jpg` | `detail.images[3]` | 濮阳老城四牌楼（古十字街） ✅ |

### 修定寺塔（`ay-xiudingsi-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/ay-xiudingsi-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/ay-xiudingsi-01/01.jpg` | `detail.images[0]` | 修定寺塔全景（清凉山下） ✅ |
| `images/ay-xiudingsi-01/02.jpg` | `detail.images[1]` | 塔身浮雕砖（飞天/力士/莲花等72种图案） ✅ |
| `images/ay-xiudingsi-01/03.jpg` | `detail.images[2]` | 塔门三世佛像龛（阿难/迦叶/胁侍菩萨/天王） ✅ |
| `images/ay-xiudingsi-01/04.jpg` | `detail.images[3]` | 修定寺塔花砖修复（1983—1984年） ✅ |

### 安阳文峰塔（`ay-wenfeng-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/ay-wenfeng-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/ay-wenfeng-01/01.jpg` | `detail.images[0]` | 文峰塔全景（上大下小伞状塔形） ✅ |
| `images/ay-wenfeng-01/02.jpg` | `detail.images[1]` | 塔身佛传故事浮雕（晚唐造像遗风） ✅ |
| `images/ay-wenfeng-01/03.jpg` | `detail.images[2]` | 「文峰耸秀」门额与塔门 ✅ |
| `images/ay-wenfeng-01/04.jpg` | `detail.images[3]` | 塔顶平台与塔刹（俯瞰安阳老城） ✅ |

### 灵泉寺石窟（`ay-lingquan-01`）

| 文件 | 数据字段 | 图注 |
|---|---|---|
| `images/ay-lingquan-01/cover.jpg` | `coverImage` | 列表封面 ✅ |
| `images/ay-lingquan-01/01.jpg` | `detail.images[0]` | 灵泉寺石窟全景（宝山峡谷，八山环抱状若莲台） ✅ |
| `images/ay-lingquan-01/02.jpg` | `detail.images[1]` | 大住圣窟（整块巨石开凿，门神护法） ✅ |
| `images/ay-lingquan-01/03.jpg` | `detail.images[2]` | 道凭法师双石塔（中国现存最早的野外双石塔） ✅ |
| `images/ay-lingquan-01/04.jpg` | `detail.images[3]` | 摩崖浮雕塔林（万佛沟） ✅ |

## 说明

- 图片均来自公开网络检索，优先采用政府/文物局/博物馆/主流媒体等官方或权威来源。
- 单张图片来源页 URL 见同目录 `_manifest.json`（字段 `purl` 为来源页，`murl` 为图片原始地址）。
- 已做基本质检：JPEG 有效、宽度 ≥560px、长宽比合理；重复图片已去重。
- 部分图注极为专业的细部（如特定探方、特定器物局部）可能为同遗址/同题材近似图，正式发布前建议按图注逐张复核。

合计图片 123 张。
