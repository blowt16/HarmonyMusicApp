import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AudioSessionService } from '../services/AudioSessionService';
import { ThemeManager } from '../services/ThemeManager';
import { StorageService } from '../services/StorageService';
import { AuthService } from '../services/AuthService';
import { ImageCacheService } from '../services/ImageCacheService';
import { PlayerService } from '../services/PlayerService';
import { WidgetService } from '../services/WidgetService';
import { EffectLevel } from '../models/MusicModel';

const DOMAIN = 0x0000;

/**
 * 主界面/播放 Ability：承接窗口、音频、封面缓存，并做登录门禁。
 */
export default class MainAbility extends UIAbility {
  private audioSessionService: AudioSessionService = AudioSessionService.getInstance();
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private storageService: StorageService = StorageService.getInstance();
  private authService: AuthService = AuthService.getInstance();
  private imageCacheService: ImageCacheService = ImageCacheService.getInstance();
  private playerService: PlayerService = PlayerService.getInstance();
  private mainWindow: window.Window | null = null;
  private authCheck: Promise<boolean> | null = null;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'MainAbility onCreate');

    this.storageService.setContext(this.context);
    this.authService.setContext(this.context);
    this.playerService.setResourceManager(this.context.resourceManager);

    // onCreate 是异步的，窗口生命周期不会等待它完成；
    // 把登录检查保存为 Promise，窗口创建时再据此决定是否加载页面。
    this.authCheck = this.authService.isLoggedIn();
    this.authCheck.then(async (loggedIn: boolean) => {
      if (!loggedIn) {
        try {
          await this.context.startAbility({
            bundleName: this.context.applicationInfo.name,
            abilityName: 'EntryAbility',
            parameters: { showLogin: true }
          });
        } catch (err) {
          hilog.error(DOMAIN, 'testTag', 'Start EntryAbility failed: %{public}s', JSON.stringify(err));
        }
        setTimeout(() => {
          this.context.terminateSelf();
        }, 800);
        return;
      }

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

      try {
        await this.audioSessionService.init(this.context);
        hilog.info(DOMAIN, 'testTag', '%{public}s', 'AudioSessionService initialized');
      } catch (err) {
        hilog.error(DOMAIN, 'testTag', 'Failed to init AudioSessionService: %{public}s', JSON.stringify(err));
      }

      try {
        await this.imageCacheService.init(this.context);
        hilog.info(DOMAIN, 'testTag', '%{public}s', 'ImageCacheService initialized');
      } catch (err) {
        hilog.error(DOMAIN, 'testTag', 'Failed to init ImageCacheService: %{public}s', JSON.stringify(err));
      }
    });
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'MainAbility onNewWant');
  }

  onForeground(): void {
    WidgetService.refreshAll();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'MainAbility onWindowStageCreate');
    const check: Promise<boolean> = this.authCheck ?? Promise.resolve(false);
    check.then((loggedIn: boolean) => {
      if (!loggedIn) {
        return;
      }
      windowStage.getMainWindow().then((mainWindow: window.Window) => {
        this.mainWindow = mainWindow;
        mainWindow.setWindowLayoutFullScreen(true);
        const avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        AppStorage.setOrCreate<number>('statusBarHeight', px2vp(avoidArea.topRect.height));
        AppStorage.setOrCreate<number>('bottomNavBarHeight', px2vp(avoidArea.bottomRect.height));
        this.updateSystemBars();
      });

      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load content: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading main content');
      });
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
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'MainAbility onWindowStageDestroy');
  }

  async onDestroy(): Promise<void> {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'MainAbility onDestroy');
    try {
      this.playerService.stop();
      await this.playerService.release();
      this.playerService.reset();
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to release player: %{public}s', JSON.stringify(err));
    }
    try {
      await this.audioSessionService.destroy();
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to destroy AudioSessionService: %{public}s', JSON.stringify(err));
    }
  }
}
