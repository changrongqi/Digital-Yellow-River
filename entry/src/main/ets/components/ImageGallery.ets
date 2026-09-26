/**
 * 图集组件（M1.10：真实图片占位 + 点击放大，动态布局）。
 *
 * 用途：考古页签（遗址级 images）与事件子详情页（事件级 images）共用。
 *
 * 功能：
 * - 缩略图网格：Flex wrap 响应式布局（每行 3 列，宽度按容器百分比自适应，
 *   配合 aspectRatio(1) 等比方块，适配手机/平板任意宽度）；
 * - 点击缩略图 → 全屏 Lightbox 放大：bindContentCover 页面级遮罩（不被 Scroll 裁剪），
 *   深色遮罩 + 居中大图（objectFit Contain 保持比例）、右上关闭、
 *   底部图注/来源、多图时左右切换 + 页码；
 * - 图片动态加载：resourceManager.getRawFileContent → @kit.ImageKit
 *   image.createImageSource(buf).createPixelMap() → Image(PixelMap)
 *   （Image 组件 source 支持 PixelMap，d.ts 已核证；path 为空或加载失败显示占位卡，
 *   不崩溃）。
 *
 * 占位策略：path 为空串（待填充）或 rawfile 读取失败 → 虚线边框占位卡
 * （「图片待补充」+ 建议来源），真实图片待用户提供/稳定渠道后填入 rawfile。
 *
 * 数据：@Prop images（父组件数据加载完成后传入，深拷贝；空数组不渲染）。
 */

import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HeritageImage } from '../model/Heritage';

const DOMAIN = 0x0000;
const TAG = 'ImageGallery';

@Component
export struct ImageGallery {
  /** 图集数据（父组件传入，@Prop 深拷贝；heritage 加载完成后再渲染，规避空数据） */
  @Prop images: HeritageImage[] = [];
  /** 动态加载结果：rawfile → PixelMap；null = 待填充占位/加载失败 */
  @State pixelMaps: (image.PixelMap | null)[] = [];
  /** Lightbox 是否打开（bindContentCover 页面级全屏遮罩） */
  @State showLightbox: boolean = false;
  /** 当前放大图索引 */
  @State lightboxIndex: number = 0;
  /** 组件是否已卸载（异步加载完成后回写 @State 的保护标志） */
  private disposed: boolean = false;

  aboutToAppear(): void {
    this.pixelMaps = this.initNulls(this.images.length);
    this.loadImages();
  }

  aboutToDisappear(): void {
    this.disposed = true;
  }

  /** 初始全 null 数组（与 images 对齐，逐项异步替换） */
  private initNulls(count: number): (image.PixelMap | null)[] {
    const arr: (image.PixelMap | null)[] = [];
    for (let i = 0; i < count; i++) {
      arr.push(null);
    }
    return arr;
  }

  /** 逐张动态加载 rawfile 图片 → PixelMap（整体赋值触发刷新，踩坑 5） */
  private async loadImages(): Promise<void> {
    const host = this.getUIContext().getHostContext();
    if (host === undefined) {
      return;
    }
    const rm = host.resourceManager;
    for (let i = 0; i < this.images.length; i++) {
      const path: string = this.images[i].path;
      if (path === '') {
        continue; // 待填充占位，跳过加载
      }
      try {
        const data: Uint8Array = await rm.getRawFileContent(path);
        const source: image.ImageSource = image.createImageSource(data.buffer as ArrayBuffer);
        const pm: image.PixelMap = await source.createPixelMap();
        if (this.disposed) {
          return;
        }
        const next: (image.PixelMap | null)[] = this.pixelMaps.slice();
        next[i] = pm;
        this.pixelMaps = next;
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'load image %{public}s failed: %{public}s', path, JSON.stringify(err));
        // 保持 null → 显示占位卡
      }
    }
  }

  private openLightbox(idx: number): void {
    this.lightboxIndex = idx;
    this.showLightbox = true;
  }

  private closeLightbox(): void {
    this.showLightbox = false;
  }

  private prevImage(): void {
    const len: number = this.images.length;
    if (len === 0) {
      return;
    }
    this.lightboxIndex = (this.lightboxIndex - 1 + len) % len;
  }

  private nextImage(): void {
    const len: number = this.images.length;
    if (len === 0) {
      return;
    }
    this.lightboxIndex = (this.lightboxIndex + 1) % len;
  }

  /** 占位卡（path 空/加载失败）：虚线边框 + 待补充说明 + 建议来源 */
  @Builder
  PlaceholderCard(img: HeritageImage) {
    Column() {
      Text('+')
        .fontSize(22)
        .fontColor('#A1887F')
      Text('图片待补充')
        .fontSize(11)
        .fontColor('#A1887F')
        .margin({ top: 4 })
      if (img.source.length > 0) {
        Text(`建议来源：${img.source}`)
          .fontSize(9)
          .fontColor('#BCAAA4')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .margin({ top: 4, left: 6, right: 6 })
      }
    }
    .width('100%')
    .aspectRatio(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#FBEFE5')
    .borderRadius(8)
    .border({ width: 1, color: '#D8C7B8', style: BorderStyle.Dashed })
  }

  /**
   * Lightbox 放大内容（bindContentCover 全屏遮罩展示）。
   * ⚠️ @Builder 直读 this.showLightbox/lightboxIndex/…（踩坑 15：状态源必须直读）。
   */
  @Builder
  LightboxContent() {
    Stack() {
      // 关闭按钮（右上；ArkUI ClickEvent 无 stopPropagation，故遮罩不设整体关闭，
      // 只保留此显式关闭入口，避免点箭头/大图被冒泡误关）
      Text('✕')
        .fontSize(16)
        .fontColor('#FFFFFF')
        .width(34)
        .height(34)
        .textAlign(TextAlign.Center)
        .backgroundColor('rgba(255,255,255,0.16)')
        .borderRadius(17)
        .position({ x: '86%', y: 16 })
        .onClick(() => {
          this.closeLightbox();
        })

      // 大图（Contain 保持比例，动态适配任意屏幕）
      if (this.pixelMaps[this.lightboxIndex] !== null) {
        Image(this.pixelMaps[this.lightboxIndex] as image.PixelMap)
          .objectFit(ImageFit.Contain)
          .width('100%')
          .height('78%')
          .position({ x: 0, y: '9%' })
      } else {
        Text('该图片尚未提供，敬请期待')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .position({ x: 0, y: '42%' })
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      // 多图：左右切换（中心两侧）
      if (this.images.length > 1) {
        Text('‹')
          .fontSize(26)
          .fontColor('#FFFFFF')
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .backgroundColor('rgba(255,255,255,0.16)')
          .borderRadius(20)
          .position({ x: 12, y: '48%' })
          .onClick(() => {
            this.prevImage();
          })
        Text('›')
          .fontSize(26)
          .fontColor('#FFFFFF')
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .backgroundColor('rgba(255,255,255,0.16)')
          .borderRadius(20)
          .position({ x: '88%', y: '48%' })
          .onClick(() => {
            this.nextImage();
          })
        Text(`${this.lightboxIndex + 1} / ${this.images.length}`)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .position({ x: 0, y: '91%' })
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      // 图注 + 来源（底部，多图时在页码下方）
      if (this.images.length > 0) {
        Column() {
          if (this.images[this.lightboxIndex].caption.length > 0) {
            Text(this.images[this.lightboxIndex].caption)
              .fontSize(13)
              .fontColor('#FFFFFF')
              .textAlign(TextAlign.Center)
              .width('100%')
          }
          if (this.images[this.lightboxIndex].source.length > 0) {
            Text(`来源：${this.images[this.lightboxIndex].source}`)
              .fontSize(11)
              .fontColor('rgba(255,255,255,0.72)')
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ top: 4 })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 24 })
        .position({ x: 0, y: this.images.length > 1 ? '95%' : '92%' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.88)')
  }

  build() {
    Column() {
      // 缩略图网格（动态布局：Flex wrap，每行 3 列，宽度百分比自适应）
      if (this.images.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.images, (img: HeritageImage, idx: number) => {
            Column() {
              if (this.pixelMaps[idx] !== null) {
                Image(this.pixelMaps[idx] as image.PixelMap)
                  .objectFit(ImageFit.Cover)
                  .width('100%')
                  .aspectRatio(1)
                  .borderRadius(8)
                  .backgroundColor('#F0EBE5')
              } else {
                this.PlaceholderCard(img)
              }
              if (img.caption.length > 0) {
                Text(img.caption)
                  .fontSize(11)
                  .fontColor('#8D6E63')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .margin({ top: 4 })
              }
            }
            .width('32%')
            .margin({ bottom: 10 })
            .onClick(() => {
              this.openLightbox(idx);
            })
          }, (img: HeritageImage, idx: number) => `${img.path}-${idx}`)
        }
        .width('100%')
      }
    }
    .width('100%')
    // 页面级全屏遮罩（不被 Scroll/卡片裁剪；深色背景由 options 提供）
    .bindContentCover(this.showLightbox, () => {
      this.LightboxContent()
    }, {
      backgroundColor: 'rgba(0,0,0,0.88)',
      modalTransition: ModalTransition.NONE
    })
  }
}
