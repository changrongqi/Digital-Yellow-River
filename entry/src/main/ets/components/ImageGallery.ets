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
import { ThemeTokens } from '../utils/ThemeTokens';

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
    // L9：组件卸载时释放全部 PixelMap（Image 组件不再需要，及时归还原生内存）
    this.releaseAll();
  }

  /** 释放当前持有的 PixelMap（整体摘除后逐个 release，异常只记日志） */
  private releaseAll(): void {
    const maps: (image.PixelMap | null)[] = this.pixelMaps;
    this.pixelMaps = [];
    for (let i = 0; i < maps.length; i++) {
      const pm: image.PixelMap | null = maps[i];
      if (pm === null) {
        continue;
      }
      pm.release().catch((err: Object) => {
        hilog.error(DOMAIN, TAG, 'release pixelMap failed: %{public}s', JSON.stringify(err));
      });
    }
  }

  /** 初始全 null 数组（与 images 对齐，逐项异步替换） */
  private initNulls(count: number): (image.PixelMap | null)[] {
    const arr: (image.PixelMap | null)[] = [];
    for (let i = 0; i < count; i++) {
      arr.push(null);
    }
    return arr;
  }

  /** L9：解码尺寸上限（长边 1600px），兼顾缩略图内存与 Lightbox 清晰度 */
  private decodeOptions(width: number, height: number): image.DecodingOptions | undefined {
    const longest: number = Math.max(width, height);
    if (longest <= 1600) {
      return undefined;
    }
    const ratio: number = 1600 / longest;
    const options: image.DecodingOptions = {
      desiredSize: { width: Math.round(width * ratio), height: Math.round(height * ratio) }
    };
    return options;
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
      let source: image.ImageSource | null = null;
      let pixelMap: image.PixelMap | null = null;
      try {
        const data: Uint8Array = await rm.getRawFileContent(path);
        source = image.createImageSource(data.buffer as ArrayBuffer);
        const info: image.ImageInfo = await source.getImageInfo();
        const options: image.DecodingOptions | undefined =
          this.decodeOptions(info.size.width, info.size.height);
        pixelMap = options === undefined ? await source.createPixelMap() : await source.createPixelMap(options);
        if (this.disposed) {
          // 卸载后才完成：立即释放，避免泄漏
          await pixelMap.release();
          pixelMap = null;
          return;
        }
        const next: (image.PixelMap | null)[] = this.pixelMaps.slice();
        next[i] = pixelMap;
        this.pixelMaps = next;
        pixelMap = null; // 所有权转移给 @State 数组，由卸载统一释放
      } catch (err) {
        if (pixelMap !== null) {
          try {
            await pixelMap.release();
          } catch (releaseErr) {
            hilog.error(DOMAIN, TAG, 'release failed pixelMap: %{public}s', JSON.stringify(releaseErr));
          }
        }
        hilog.error(DOMAIN, TAG, 'load image %{public}s failed: %{public}s', path, JSON.stringify(err));
        // 保持 null → 显示占位卡
      } finally {
        if (source !== null) {
          try {
            await source.release();
          } catch (releaseErr) {
            hilog.error(DOMAIN, TAG, 'release imageSource failed: %{public}s', JSON.stringify(releaseErr));
          }
        }
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
        .fontColor(ThemeTokens.TEXT_SUBTLE)
      Text('图片待补充')
        .fontSize(11)
        .fontColor(ThemeTokens.TEXT_SUBTLE)
        .margin({ top: 4 })
      if (img.source.length > 0) {
        Text(`建议来源：${img.source}`)
          .fontSize(9)
          .fontColor(ThemeTokens.TEXT_MUTED)
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
        .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .backgroundColor('rgba(255,255,255,0.16)')
        .borderRadius(22)
        .position({ x: '84%', y: 16 })
        .accessibilityText('关闭图片预览')
        .accessibilityLevel('yes')
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
          .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
          .position({ x: 0, y: '42%' })
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      // 多图：左右切换（中心两侧）
      if (this.images.length > 1) {
        Text('‹')
          .fontSize(26)
          .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor('rgba(255,255,255,0.16)')
          .borderRadius(22)
          .position({ x: 12, y: '48%' })
          .accessibilityText('上一张图片')
          .accessibilityLevel('yes')
          .onClick(() => {
            this.prevImage();
          })
        Text('›')
          .fontSize(26)
          .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor('rgba(255,255,255,0.16)')
          .borderRadius(22)
          .position({ x: '86%', y: '48%' })
          .accessibilityText('下一张图片')
          .accessibilityLevel('yes')
          .onClick(() => {
            this.nextImage();
          })
        Text(`${this.lightboxIndex + 1} / ${this.images.length}`)
          .fontSize(12)
          .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
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
              .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
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
                  .backgroundColor(ThemeTokens.DIVIDER)
              } else {
                this.PlaceholderCard(img)
              }
              if (img.caption.length > 0) {
                Text(img.caption)
                  .fontSize(11)
                  .fontColor(ThemeTokens.TEXT_SECONDARY)
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
