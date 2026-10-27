import { ImageCacheService } from '../services/ImageCacheService';

/**
 * 文件：CachedImage.ets
 * 职责：带本地缓存的图片组件。
 *
 * 渲染策略：先用原始 URL 立即显示，避免白屏；
 * ImageCacheService 下载/命中缓存后再把路径换成 file:// 本地路径。
 * 说明：当前主列表主要直接使用 thumbnail()，这个组件保留为可选方案。
 */
@Component
struct CachedImage {
  @Prop src: string = '';
  @State displayPath: string = '';

  private imageCacheService: ImageCacheService = ImageCacheService.getInstance();

  imgWidth: Length = '100%';
  imgHeight: Length = '100%';
  imgObjectFit: ImageFit = ImageFit.Cover;
  imgBorderRadius: Length = 0;
  imgBackgroundColor: ResourceColor = '#F0F0F0';

  aboutToAppear(): void {
    if (!this.src) {
      return;
    }
    // 立即用原 URL 显示，不阻塞渲染
    this.displayPath = this.src;
    // 后台获取缓存路径，就绪后替换
    this.imageCacheService.getCachedPath(this.src).then((cached: string) => {
      if (cached && cached !== this.src) {
        this.displayPath = cached;
      }
    });
  }

  build() {
    if (this.displayPath) {
      Image(this.displayPath)
        .width(this.imgWidth)
        .height(this.imgHeight)
        .objectFit(this.imgObjectFit)
        .borderRadius(this.imgBorderRadius)
        .backgroundColor(this.imgBackgroundColor)
    } else {
      Row()
        .width(this.imgWidth)
        .height(this.imgHeight)
        .borderRadius(this.imgBorderRadius)
        .backgroundColor(this.imgBackgroundColor)
    }
  }
}

export { CachedImage }
