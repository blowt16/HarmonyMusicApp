/**
 * 文件：ImageUtils.ets
 * 职责：处理封面 URL。
 *
 * 网易云音乐支持在图片 URL 后加 ?param=宽y高 获取指定尺寸缩略图，
 * 列表里用小图可以明显减少流量和解码开销。
 */

/**
 * 生成缩略图 URL
 * @param url 原始封面 URL
 * @param width 目标宽度
 * @param height 目标高度
 * @returns 带 ?param=WxH 的缩略图 URL
 */
/**
 * 生成缩略图 URL。
 * 先去掉原 URL 上已有的查询参数，再统一追加新的 ?param=WxH，
 * 避免出现两个 ? 或重复参数。
 */
export function thumbnail(url: string, width: number, height: number): string {
  if (!url) {
    return '';
  }
  // 已经有 ?param 则替换
  const base: string = url.split('?')[0];
  return `${base}?param=${width}y${height}`;
}
