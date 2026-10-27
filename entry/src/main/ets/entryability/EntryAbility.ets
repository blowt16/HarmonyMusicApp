import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { ThemeManager } from '../services/ThemeManager';
import { StorageService } from '../services/StorageService';
import { AuthService } from '../services/AuthService';
import { EffectLevel } from '../models/MusicModel';

const DOMAIN = 0x0000;

/**
 * 文件：EntryAbility.ets
 * 职责：欢迎页 / 登录页的宿主 Ability，不初始化音频服务。
 *
 * 为什么拆成两个 Ability：
 * - EntryAbility 只处理「进门」：欢迎页、登录页、登录态判断；
 * - MainAbility 处理「播放厅」：主界面、播放、通知栏、后台任务。
 * 登录成功后 EntryAbility 结束自己，返回键不会回到欢迎页；
 * MainAbility 仍有登录门禁，防止通过 aa start 绕过登录。
 */
export default class EntryAbility extends UIAbility {
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private storageService: StorageService = StorageService.getInstance();
  private authService: AuthService = AuthService.getInstance();
  private mainWindow: window.Window | null = null;
  // true 表示本次启动直接加载登录页（退出登录 / MainAbility 门禁送回来）
  private showLogin: boolean = false;

  /**
   * Ability 创建。
   * 这里只准备登录流程需要的上下文和外观设置，不创建播放器。
   */
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'EntryAbility onCreate');

    // 必须在第一个 await 之前解析 Want：框架不会等待异步 onCreate 完成，
    // 窗口创建时就要用 showLogin 决定加载哪个页面。
    const params = want.parameters;
    this.showLogin = params !== undefined && params['showLogin'] === true;

    // Preferences 依赖 Context，先把上下文交给相关服务
    this.storageService.setContext(this.context);
    this.authService.setContext(this.context);

    // 主界面固定浅色方案；这里只同步 token，不注册长期主题监听
    this.themeManager.init(false);

    // 把用户保存的外观设置同步到 AppStorage，页面用 @StorageLink 直接读取
    const savedLevel: EffectLevel = await this.storageService.getEffectLevel();
    AppStorage.setOrCreate<number>('effectLevel', savedLevel);
    const savedBgImage: string = await this.storageService.getBgImage();
    AppStorage.setOrCreate<string>('bgImage', savedBgImage);
    const savedBgOpacity: number = await this.storageService.getBgOpacity();
    AppStorage.setOrCreate<number>('bgOpacity', savedBgOpacity);

    try {
      // 强制浅色，避免系统深色模式把欢迎 / 登录页的配色打乱
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 窗口创建完成：设置沉浸式系统栏，然后按 showLogin 选择页面。
   */
  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'EntryAbility onWindowStageCreate');

    windowStage.getMainWindow().then((mainWindow: window.Window) => {
      this.mainWindow = mainWindow;
      mainWindow.setWindowLayoutFullScreen(true);
      // 读取系统状态栏 / 底部导航栏高度，交给页面做安全区留白
      const avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      AppStorage.setOrCreate<number>('statusBarHeight', px2vp(avoidArea.topRect.height));
      AppStorage.setOrCreate<number>('bottomNavBarHeight', px2vp(avoidArea.bottomRect.height));
      this.updateSystemBars();
    });

    // 退出登录 / 门禁送来时直接进登录页，否则先展示欢迎页
    const page: string = this.showLogin ? 'pages/LoginPage' : 'pages/WelcomePage';
    windowStage.loadContent(page, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading %{public}s', page);
    });
  }

  /**
   * 系统栏透明 + 内容颜色跟随主题（当前固定浅色，所以是黑字）。
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
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'EntryAbility onWindowStageDestroy');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'EntryAbility onDestroy');
  }
}
