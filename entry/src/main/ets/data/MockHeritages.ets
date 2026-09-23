/**
 * 预览环境兜底示例数据（与 heritage_data.json 字段一致，含完整五层级详情）。
 *
 * 仅在 rawfile 加载失败时注入（典型场景：DevEco 预览器无资源访问能力），
 * 便于预览器调试列表与详情 UI；真机正常走 rawfile，不受影响。
 * 发现页与详情页共用，避免两处漂移。
 */

import { Heritage, Poem } from '../model/Heritage';
import { HeritageEra, HeritageType, HeritageCity } from '../model/Types';

const EMPTY_POEMS: Poem[] = [];

export const MOCK_HERITAGES: Heritage[] = [
  {
    id: 'mock-yangshao',
    name: '仰韶村遗址',
    era: HeritageEra.YANGSHAO,
    type: HeritageType.KILN_SITE,
    city: HeritageCity.SANMENXIA,
    coverImage: '',
    summary: '中国现代考古学的诞生地，仰韶文化命名地，出土大量彩陶器物的新石器时代聚落遗址。',
    detail: {
      intro: '仰韶村遗址位于河南省三门峡市渑池县，距今约7000—5000年，是新石器时代中晚期的典型聚落遗址。1921年安特生等在此发掘并命名「仰韶文化」，标志着中国现代考古学的诞生。遗址出土以红陶、彩陶为代表的丰富遗存，是研究华夏文明起源的重要实物资料。',
      discovery: '1921年首次发掘即出土彩陶、石器等大批遗物，「仰韶文化」由此命名。此后历次发掘发现房址、窖穴、灰坑及瓮棺葬等遗迹，确认遗址包含仰韶文化早中晚期及庙底沟二期、河南龙山文化等多个时期遗存。2021年入选百年百大考古发现。',
      events: [
        '1921年：安特生主持首次发掘，命名仰韶文化，中国现代考古学由此起步。',
        '2021年：入选「百年百大考古发现」，并启动第四次大规模发掘。'
      ],
      poems: EMPTY_POEMS,
      tourism: '位于渑池县仰韶乡，建有仰韶文化博物馆与遗址公园，可参观发掘现场与出土彩陶文物，是了解华夏彩陶文化的重要研学目的地。'
    }
  },
  {
    id: 'mock-erlitou',
    name: '二里头遗址',
    era: HeritageEra.XIA_SHANG,
    type: HeritageType.CAPITAL_SITE,
    city: HeritageCity.LUOYANG,
    coverImage: '',
    summary: '被誉为「最早的中国」，学界公认的夏朝中晚期都城遗址，发现中国最早的宫城、青铜礼器群与绿松石龙形器。',
    detail: {
      intro: '二里头遗址位于河南省洛阳市偃师区，距今约3800—3500年，属夏代中晚期都城遗址，被学界普遍认为是「最早的中国」。遗址面积约300万平方米，发现了中国最早的城市主干道网、宫城与青铜铸造作坊，标志着中国青铜时代的开端与王权国家的形成。',
      discovery: '1959年由徐旭生先生调查发现，此后历经60余次发掘。宫城内发现成组大型夯土基址，2002年出土的绿松石龙形器全长约70厘米，由2000余片绿松石片嵌成，是夏代高等级礼制的直观物证。',
      events: [
        '1959年：徐旭生调查夏墟，二里头遗址被发现。',
        '2002年：出土大型绿松石龙形器，轰动学界。'
      ],
      poems: EMPTY_POEMS,
      tourism: '二里头夏都遗址博物馆于2019年开馆，展示二里头文化与夏朝历史，是「最早的中国」主题研学与参观胜地。'
    }
  },
  {
    id: 'mock-yinxu',
    name: '殷墟',
    era: HeritageEra.XIA_SHANG,
    type: HeritageType.CAPITAL_SITE,
    city: HeritageCity.ANYANG,
    coverImage: '',
    summary: '商代晚期都城遗址，中国历史上第一个有文献可考并为考古证实的都城，甲骨文的发现地，世界文化遗产。',
    detail: {
      intro: '殷墟位于河南省安阳市西北郊小屯村一带，是商朝晚期都城遗址，是中国历史上第一个有明确文献记载、并为考古发掘所证实的都城。出土大量甲骨卜辞、青铜礼器与宫殿、王陵遗迹，甲骨文的发现将中国信史向前推进了约一千年。',
      discovery: '1899年王懿荣发现甲骨文，学界由此追踪到小屯。1928年中央研究院历史语言研究所开始正式发掘。1976年妇好墓出土随葬品1928件。2006年殷墟列入世界遗产名录。',
      events: [
        '1899年：王懿荣于药材「龙骨」上辨识出甲骨文。',
        '1928年：殷墟科学发掘拉开序幕。',
        '2006年：列入《世界遗产名录》。'
      ],
      poems: [
        {
          title: '诗经·商颂·玄鸟（节选）',
          author: '佚名',
          content: '天命玄鸟，降而生商，宅殷土芒芒。'
        }
      ],
      tourism: '位于安阳市殷都区，建有殷墟博物馆新馆（2024年开馆），宫殿宗庙遗址与王陵区对外开放。'
    }
  },
  {
    id: 'mock-tokyo',
    name: '北宋东京城遗址',
    era: HeritageEra.SONG,
    type: HeritageType.CAPITAL_SITE,
    city: HeritageCity.KAIFENG,
    coverImage: '',
    summary: '北宋都城汴京故城遗址，州桥石壁浮雕与汴河遗址印证「东京梦华」，世界城市史上罕见的「城摞城」。',
    detail: {
      intro: '北宋东京城遗址位于今河南省开封市，是北宋都城汴京故城遗存。开封地下层层叠叠掩埋着战国大梁城、唐代汴州城、北宋东京城、金代汴京城与明清开封城，形成世界城市史上罕见的「城摞城」奇观。',
      discovery: '州桥及附近汴河遗址考古发现大型石壁浮雕，海马瑞兽、飞鹤祥云纹饰与《东京梦华录》记载相互印证，再现北宋都城的繁华盛景。',
      events: [
        '960年：赵匡胤建立北宋，定都东京开封府。',
        '2022年：州桥及附近汴河遗址入选年度全国十大考古新发现。'
      ],
      poems: EMPTY_POEMS,
      tourism: '位于开封市区，州桥及汴河遗址公众考古研学基地已开放，可近距离观看石壁浮雕与发掘现场。'
    }
  }
];
