import { hilog } from '@kit.PerformanceAnalysisKit';
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';

const DOMAIN = 0x0000;

/**
 * 文件：EntryBackupAbility.ets
 * 职责：应用备份 / 恢复扩展。
 *
 * 当前项目没有自定义备份内容，只保留系统回调并打日志；
 * 如果以后要把 Preferences 或私有目录纳入备份，在这里实现具体逻辑。
 */
export default class EntryBackupAbility extends BackupExtensionAbility {
  /**
   * 系统触发备份时调用。
   */
  async onBackup() {
    hilog.info(DOMAIN, 'testTag', 'onBackup ok');
    await Promise.resolve();
  }

  /**
   * 系统触发恢复时调用；bundleVersion 可用于做版本兼容处理。
   */
  async onRestore(bundleVersion: BundleVersion) {
    hilog.info(DOMAIN, 'testTag', 'onRestore ok %{public}s', JSON.stringify(bundleVersion));
    await Promise.resolve();
  }
}