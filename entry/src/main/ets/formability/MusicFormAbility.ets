import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { StorageService } from '../services/StorageService';
import { WidgetService, WidgetData } from '../services/WidgetService';

/**
 * 2×2 动态服务卡片：读取本地最近播放，卡片展示“继续听”或“发现好音乐”。
 */
export default class MusicFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    StorageService.getInstance().setContext(this.context);

    const params = want.parameters;
    let formId: string = '';
    if (params !== undefined) {
      const value = params[formInfo.FormParam.IDENTITY_KEY];
      if (typeof value === 'string') {
        formId = value;
      }
    }
    if (formId) {
      this.registerAndRefresh(formId);
    }

    const initial: WidgetData = {
      title: '今天想听什么？',
      subtitle: '打开清听',
      status: '发现好音乐'
    };
    return formBindingData.createFormBindingData(initial);
  }

  onUpdateForm(formId: string): void {
    console.info('MusicFormAbility onUpdateForm', formId);
    StorageService.getInstance().setContext(this.context);
    this.pushUpdate(formId);
  }

  onRemoveForm(formId: string): void {
    StorageService.getInstance().setContext(this.context);
    StorageService.getInstance().removeFormId(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  private async registerAndRefresh(formId: string): Promise<void> {
    await StorageService.getInstance().addFormId(formId);
    await this.pushUpdate(formId);
  }

  private async pushUpdate(formId: string): Promise<void> {
    const data: WidgetData = await WidgetService.buildData();
    try {
      await formProvider.updateForm(formId, formBindingData.createFormBindingData(data));
    } catch (e) {
      console.error('Form update error:', formId, e);
    }
  }
}
