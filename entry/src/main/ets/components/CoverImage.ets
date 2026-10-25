/**
 * 列表封面缩略图（O1 图片接入）。
 *
 * 用途：发现页列表卡与收藏页卡片的方形封面位（72vp）。
 * - 有 coverImage 路径：resourceManager 读 rawfile → ImageKit 解码为 PixelMap 缩略图（长边 ≤320px）；
 * - 路径为空或加载失败：回落文字徽标（城市 + 年代），与接入前视觉一致；
 * - 生命周期：卸载释放、迟到结果立即释放（与 ImageGallery 同一套 L9 规则），避免列表滚动累积原生内存。
 */

import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemeTokens } from '../utils/ThemeTokens';

const DOMAIN = 0x0000;
const TAG = 'CoverImage';
/** 缩略图解码长边上限：72vp 在 3 倍屏约 216px，留余量避免模糊 */
const COVER_MAX_EDGE = 320;

@Component
export struct CoverImage {
  /** rawfile 相对路径（如 images/smx-yangshao-01/cover.jpg；空串=无图） */
  @Prop path: string = '';
  /** 无图时徽标主文字（城市） */
  @Prop label: string = '';
  /** 无图时徽标副文字（年代，可为空） */
  @Prop subLabel: string = '';
  /** 无图时徽标底色（默认主操作色，数据缺失可传 BG_MISSING） */
  @Prop fallbackColor: string = ThemeTokens.ACCENT_FALLBACK;
  /** 解码结果；null = 无图/加载中/失败 */
  @State pixelMap: image.PixelMap | null = null;
  private disposed: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.release();
  }

  /** 释放当前 PixelMap（异常只记日志） */
  private release(): void {
    const pm: image.PixelMap | null = this.pixelMap;
    this.pixelMap = null;
    if (pm === null) {
      return;
    }
    pm.release().catch((err: Object) => {
      hilog.error(DOMAIN, TAG, 'release pixelMap failed: %{public}s', JSON.stringify(err));
    });
  }

  private async load(): Promise<void> {
    if (this.path === '') {
      return;
    }
    const host = this.getUIContext().getHostContext();
    if (host === undefined) {
      return;
    }
    let source: image.ImageSource | null = null;
    let pixelMap: image.PixelMap | null = null;
    try {
      const data: Uint8Array = await host.resourceManager.getRawFileContent(this.path);
      source = image.createImageSource(data.buffer as ArrayBuffer);
      const info: image.ImageInfo = await source.getImageInfo();
      const longEdge: number = Math.max(info.size.width, info.size.height);
      const ratio: number = longEdge > COVER_MAX_EDGE ? COVER_MAX_EDGE / longEdge : 1;
      const options: image.DecodingOptions = {
        desiredSize: {
          width: Math.max(1, Math.round(info.size.width * ratio)),
          height: Math.max(1, Math.round(info.size.height * ratio))
        }
      };
      pixelMap = await source.createPixelMap(options);
      if (this.disposed) {
        await pixelMap.release();
        pixelMap = null;
        return;
      }
      this.pixelMap = pixelMap;
      pixelMap = null; // 所有权转移给 @State，由 release 统一释放
    } catch (err) {
      if (pixelMap !== null) {
        try {
          await pixelMap.release();
        } catch (releaseErr) {
          hilog.error(DOMAIN, TAG, 'release failed pixelMap error: %{public}s', JSON.stringify(releaseErr));
        }
      }
      hilog.error(DOMAIN, TAG, 'load cover %{public}s failed: %{public}s', this.path, JSON.stringify(err));
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

  build() {
    Stack() {
      if (this.pixelMap !== null) {
        Image(this.pixelMap)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .draggable(false)
          .accessibilityText(`${this.label}封面`)
      } else {
        Column() {
          Text(this.label)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
          if (this.subLabel !== '') {
            Text(this.subLabel)
              .fontSize(11)
              .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
              .margin({ top: 4 })
          }
        }
        .justifyContent(FlexAlign.Center)
      }
    }
    .width(72)
    .height(72)
    .borderRadius(10)
    .clip(true)
    .backgroundColor(this.pixelMap === null ? this.fallbackColor : ThemeTokens.BG_SOFT)
  }
}
