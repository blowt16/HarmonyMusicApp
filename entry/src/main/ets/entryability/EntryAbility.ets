import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { ThemeManager } from '../services/ThemeManager';
import { StorageService } from '../services/StorageService';
import { AuthService } from '../services/AuthService';
import { EffectLevel } from '../models/MusicModel';

const DOMAIN = 0x0000;

/**
 * 欢迎/登录 Ability：不初始化音频服务，只负责进入主界面前的登录流程。
 */
export default class EntryAbility extends UIAbility {
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private storageService: StorageService = StorageService.getInstance();
  private authService: AuthService = AuthService.getInstance();
  private mainWindow: window.Window | null = null;
  private showLogin: boolean = false;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'EntryAbility onCreate');

    // 必须在第一个 await 之前解析 Want：框架不会等待异步 onCreate 完成
    const params = want.parameters;
    this.showLogin = params !== undefined && params['showLogin'] === true;
    const fromWidget: boolean = params !== undefined && params['from'] === 'widget';
    AppStorage.setOrCreate<boolean>('skipWelcomeDelay', fromWidget);

    this.storageService.setContext(this.context);
    this.authService.setContext(this.context);

    // 主界面固定浅色方案；这里只同步 token，不注册长期主题监听
    this.themeManager.init(false);

    const savedLevel: EffectLevel = await this.storageService.getEffectLevel();
    AppStorage.setOrCreate<number>('effectLevel', savedLevel);
    const savedBgImage: string = await this.storageService.getBgImage();
    AppStorage.setOrCreate<string>('bgImage', savedBgImage);
    const savedBgOpacity: number = await this.storageService.getBgOpacity();
    AppStorage.setOrCreate<number>('bgOpacity', savedBgOpacity);

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'EntryAbility onWindowStageCreate');

    windowStage.getMainWindow().then((mainWindow: window.Window) => {
      this.mainWindow = mainWindow;
      mainWindow.setWindowLayoutFullScreen(true);
      const avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      AppStorage.setOrCreate<number>('statusBarHeight', px2vp(avoidArea.topRect.height));
      AppStorage.setOrCreate<number>('bottomNavBarHeight', px2vp(avoidArea.bottomRect.height));
      this.updateSystemBars();
    });

    const page: string = this.showLogin ? 'pages/LoginPage' : 'pages/WelcomePage';
    windowStage.loadContent(page, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading %{public}s', page);
    });
  }

  private updateSystemBars(): void {
    if (!this.mainWindow) {
      return;
    }
    this.mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: this.themeManager.getStatusBarContentColor(),
      navigationBarContentColor: this.themeManager.getNavigationBarContentColor()
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'EntryAbility onWindowStageDestroy');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'EntryAbility onDestroy');
  }
}
