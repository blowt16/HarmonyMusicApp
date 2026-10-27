import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AudioSessionService } from '../services/AudioSessionService';
import { ThemeManager } from '../services/ThemeManager';
import { StorageService } from '../services/StorageService';
import { AuthService } from '../services/AuthService';
import { ImageCacheService } from '../services/ImageCacheService';
import { PlayerService } from '../services/PlayerService';
import { EffectLevel } from '../models/MusicModel';

const DOMAIN = 0x0000;

/**
 * 文件：MainAbility.ets
 * 职责：主界面 / 播放的宿主 Ability。
 *
 * 负责：
 * - 登录门禁：未登录直接送回 EntryAbility 的登录页；
 * - 初始化音频会话、封面缓存、主题和用户外观设置；
 * - 加载 pages/Index（四个 Tab 的主界面）；
 * - 销毁时释放播放器、AVSession 等资源。
 */
export default class MainAbility extends UIAbility {
  private audioSessionService: AudioSessionService = AudioSessionService.getInstance();
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private storageService: StorageService = StorageService.getInstance();
  private authService: AuthService = AuthService.getInstance();
  private imageCacheService: ImageCacheService = ImageCacheService.getInstance();
  private playerService: PlayerService = PlayerService.getInstance();
  private mainWindow: window.Window | null = null;
  // 登录检查是异步的，先存成 Promise，窗口创建时再 await，避免重复检查
  private authCheck: Promise<boolean> | null = null;

  /**
   * Ability 创建。
   * 先做登录门禁，再初始化播放相关服务；
   * 未登录时启动 EntryAbility(showLogin=true) 并延迟结束自己。
   */
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'MainAbility onCreate');

    // 注入上下文；播放 rawfile 示例音频需要 ResourceManager
    this.storageService.setContext(this.context);
    this.authService.setContext(this.context);
    this.playerService.setResourceManager(this.context.resourceManager);

    // onCreate 是异步的，窗口生命周期不会等待它完成；
    // 把登录检查保存为 Promise，窗口创建时再据此决定是否加载页面。
    this.authCheck = this.authService.isLoggedIn();
    this.authCheck.then(async (loggedIn: boolean) => {
      if (!loggedIn) {
        // 登录门禁：没登录就送回 EntryAbility 的登录页，并结束当前 Ability
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

      // 已登录：同步主题和用户保存的外观设置
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

      // 音频会话失败不阻塞主界面，只是通知栏 / 后台播控可能不可用
      try {
        await this.audioSessionService.init(this.context);
        hilog.info(DOMAIN, 'testTag', '%{public}s', 'AudioSessionService initialized');
      } catch (err) {
        hilog.error(DOMAIN, 'testTag', 'Failed to init AudioSessionService: %{public}s', JSON.stringify(err));
      }

      // 封面缓存初始化失败也不影响播放，后续会回退到直接使用网络 URL
      try {
        await this.imageCacheService.init(this.context);
        hilog.info(DOMAIN, 'testTag', '%{public}s', 'ImageCacheService initialized');
      } catch (err) {
        hilog.error(DOMAIN, 'testTag', 'Failed to init ImageCacheService: %{public}s', JSON.stringify(err));
      }
    });
  }

  /**
   * 已有实例再次被拉起时触发。
   * 当前没有额外参数处理，只记录日志，方便排查通知栏点击等入口。
   */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'MainAbility onNewWant');
  }

  /**
   * 窗口创建：等待登录检查结果，已登录才设置系统栏并加载 Index。
   * 未登录时 onCreate 已经在做跳转，这里直接不加载内容。
   */
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

  /**
   * 系统栏透明 + 内容颜色跟随主题。
   */
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

  /**
   * Ability 销毁：按「停止 → 释放播放器 → 重置状态 → 销毁 AVSession」顺序清理。
   * 先停播再释放，避免释放过程中还有播放事件回调。
   */
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
