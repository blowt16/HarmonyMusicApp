/**
 * 文件：TimeUtils.ets
 * 职责：把毫秒 / 秒 / 大数字格式化成界面直接可用的字符串。
 */
export class TimeUtils {
  /**
   * 把毫秒格式化成 mm:ss，用于歌曲时长显示。
   */
  static formatDuration(ms: number): string {
    const seconds = Math.floor(ms / 1000);
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  /**
   * 把秒格式化成 mm:ss，用于播放进度显示。
   */
  static formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  /**
   * 把播放量等大数字格式化成「万 / 亿」，保留一位小数。
   * 例：12345 → 1.2万，123456789 → 1.2亿。
   */
  static formatNumber(num: number): string {
    if (num >= 100000000) {
      return (num / 100000000).toFixed(1) + '亿';
    } else if (num >= 10000) {
      return (num / 10000).toFixed(1) + '万';
    }
    return num.toString();
  }
}
