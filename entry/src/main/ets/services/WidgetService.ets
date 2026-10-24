import { formBindingData, formProvider } from '@kit.FormKit';
import { StorageService } from './StorageService';
import { Song } from '../models/MusicModel';

export interface WidgetData {
  title: string;
  subtitle: string;
  status: string;
}

/**
 * 服务卡片数据与刷新：
 * - 数据源是本地最近播放，不依赖网络；
 * - App 内播放/回到前台时按保存的 formId 主动刷新。
 */
export class WidgetService {
  static async buildData(): Promise<WidgetData> {
    const history: Song[] = await StorageService.getInstance().getPlayHistory();
    if (history.length > 0) {
      const song: Song = history[0];
      return {
        title: song.name || '最近播放',
        subtitle: song.artist || '清听',
        status: '继续听'
      };
    }
    return {
      title: '今天想听什么？',
      subtitle: '打开清听',
      status: '发现好音乐'
    };
  }

  static async updateOne(formId: string, data: WidgetData): Promise<void> {
    try {
      await formProvider.updateForm(formId, formBindingData.createFormBindingData(data));
    } catch (e) {
      console.error('Update form error:', formId, e);
    }
  }

  static async refreshAll(): Promise<void> {
    const formIds: string[] = await StorageService.getInstance().getFormIds();
    if (formIds.length === 0) {
      return;
    }
    const data: WidgetData = await WidgetService.buildData();
    for (const formId of formIds) {
      await WidgetService.updateOne(formId, data);
    }
  }
}
