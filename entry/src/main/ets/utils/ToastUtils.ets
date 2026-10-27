import promptAction from '@ohos.promptAction';

/**
 * 文件：ToastUtils.ets
 * 职责：对系统 promptAction.showToast 做一层简单封装，统一提示时长和前缀。
 *
 * 说明：当前页面主要直接调用 promptAction.showToast，这个工具类保留作统一入口，
 * 后续如果要换提示组件，只需要改这里。
 */
export class ToastUtils {
  /**
   * 显示一条普通提示，默认 2 秒。
   */
  static showToast(message: string, duration: number = 2000) {
    promptAction.showToast({
      message: message,
      duration: duration
    });
  }

  /**
   * 成功提示，统一加 ✓ 前缀。
   */
  static showSuccess(message: string) {
    this.showToast(`✓ ${message}`);
  }

  /**
   * 错误提示，统一加 ✕ 前缀。
   */
  static showError(message: string) {
    this.showToast(`✕ ${message}`);
  }

  /**
   * 警告提示，统一加 ⚠ 前缀。
   */
  static showWarning(message: string) {
    this.showToast(`⚠ ${message}`);
  }
}
