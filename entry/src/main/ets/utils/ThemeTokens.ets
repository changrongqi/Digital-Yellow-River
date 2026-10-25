/**
 * 设计 token（L1）：全应用高频颜色的单一来源。
 *
 * 背景：页面/组件此前直接写死色值（#FFFFFF、#7A5C52 等），改色需要全库搜索；
 * 本文件集中高频的**中性色/语义色**，界面层统一引用。
 *
 * 边界：
 * - 年代主题色（utils/EraTheme）与主题色板（model/Theme.THEME_PALETTE）是**业务数据**，
 *   不属于中性 token，继续保留在各自单一来源中；
 * - 语义按用途命名：BG_* 背景、TEXT_* 文字、BORDER/DIVIDER 边框分隔、PRIMARY/DANGER 操作色；
 * - 色值与此前界面保持一致（TEXT_SUBTLE 为原 #7D655B，避免批量替换引入视觉变化）。
 *
 * 使用约定：新代码禁止再写这些色值字面量；确需新增色值先判断是否应补 token。
 */
export class ThemeTokens {
  // ==================== 背景 / 表面 ====================
  /** 页面底色（米白） */
  static readonly BG_PAGE = '#FAF6F0';
  /** 卡片 / 弹层表面 */
  static readonly BG_CARD = '#FFFFFF';
  /** 画布浅底（图谱画布） */
  static readonly BG_CANVAS = '#FDFBF8';
  /** 浅棕表面（次要按钮、选中 chip、浅底卡） */
  static readonly BG_SOFT = '#EFEBE9';
  /** 警示浅底（mock 提示条） */
  static readonly BG_WARNING = '#FFF3E0';

  // ==================== 文字 ====================
  /** 主文字（深棕） */
  static readonly TEXT_PRIMARY = '#3E2723';
  /** 次要文字（中棕，米白底对比度 5.09~6.03） */
  static readonly TEXT_SECONDARY = '#7A5C52';
  /** 弱化文字（灰棕，米白底对比度 4.76~5.64） */
  static readonly TEXT_MUTED = '#77635C';
  /** 弱化文字变体（原 #7D655B，用于图集/时间轴辅助说明） */
  static readonly TEXT_SUBTLE = '#7D655B';
  /** 深色底上的白字 */
  static readonly TEXT_ON_PRIMARY = '#FFFFFF';

  // ==================== 操作 / 强调 ====================
  /** 主操作色（棕） */
  static readonly PRIMARY = '#6D4C41';
  /** 危险操作色（红） */
  static readonly DANGER = '#C0392B';

  // ==================== 边框 / 分隔 ====================
  /** 常规边框 */
  static readonly BORDER = '#E0D6CC';
  /** 选中/强调边框 */
  static readonly BORDER_STRONG = '#D7CCC8';
  /** 分隔线 / 浅描边 */
  static readonly DIVIDER = '#F0EBE5';

  // ==================== 状态 / 兜底 ====================
  /** 加载指示等弱化强调色 */
  static readonly ACCENT_MUTED = '#A1887F';
  /** 主题/数据缺失时的兜底强调色 */
  static readonly ACCENT_FALLBACK = '#8D6E63';
  /** 数据缺失徽标底（Favorites 卡片封面占位） */
  static readonly BG_MISSING = '#757575';
  /** 成功操作文字/符号（绿色，加入主题） */
  static readonly TEXT_SUCCESS = '#2E7D32';

  // ==================== 浅底卡片 / 徽标 ====================
  /** 小徽标底（图谱节点类型标签） */
  static readonly BG_BADGE = '#F5EFE9';
  /** 说明块底（图谱推荐理由） */
  static readonly BG_NOTE = '#FBF7F2';
  /** 图片占位底（图集无图时的浅橘底） */
  static readonly BG_PLACEHOLDER = '#FBEFE5';
  /** 图片占位虚线边框 */
  static readonly BORDER_PLACEHOLDER = '#D8C7B8';
  /** 浮层内分隔线（图谱缩放控件） */
  static readonly DIVIDER_SOFT = '#EFE7E0';
  /** 正文强调文字（文旅解读、事件评述，比 TEXT_PRIMARY 略浅） */
  static readonly TEXT_BODY = '#4E342E';

  // ==================== 增删语义（chip / 按钮） ====================
  /** 「加入」chip 底色 */
  static readonly BG_ADD_CHIP = '#E8F5E9';
  /** 「加入」chip 边框 */
  static readonly BORDER_ADD_CHIP = '#A5D6A7';
  /** 「移出」chip 底色 */
  static readonly BG_REMOVE_CHIP = '#FBE9E7';
  /** 「移出」chip 边框 */
  static readonly BORDER_REMOVE_CHIP = '#FFCCBC';
  /** 选中 chip 上的图标文字（浅橙） */
  static readonly TEXT_ON_SELECTED = '#FFCCBC';
  /** 危险操作浅底（删除主题按钮） */
  static readonly BG_DANGER_SOFT = '#FDECEA';

  // ==================== 系统 / 画布 ====================
  /** 系统栏图标与文字（浅底上的深色内容） */
  static readonly SYSTEM_BAR_CONTENT = '#000000';
  /** 图谱关联/推荐虚线边 */
  static readonly GRAPH_AFFINITY = '#B08D7A';
  /** 图谱节点标签文字（压在连线上，配浅色描边） */
  static readonly GRAPH_LABEL = '#5D4037';
}
