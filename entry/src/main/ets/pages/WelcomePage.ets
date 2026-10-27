/**
 * 文件：WelcomePage.ets
 * 职责：欢迎页。
 *
 * 显示 1.5 秒后判断登录态：
 * - 已登录：启动 MainAbility，并延迟结束当前 EntryAbility；
 * - 未登录：replaceUrl 到登录页。
 * 计时器在页面销毁时清理，避免重复跳转。
 */
import router from '@ohos.router';
import { common, Want } from '@kit.AbilityKit';
import { AuthService } from '../services/AuthService';

@Entry
@Component
struct WelcomePage {
  @StorageLink('bgPrimary') bgPrimary: string = '#F7F6F2';
  @StorageLink('textPrimary') textPrimary: string = '#17181A';
  @StorageLink('textSecondary') textSecondary: string = '#6B6F76';

  private timer: number = 0;
  private navigating: boolean = false;
  private authService: AuthService = AuthService.getInstance();

  /**
   * 欢迎页展示 1.5 秒后进入分流逻辑。
   */
  aboutToAppear() {
    this.authService.setContext(getContext(this));
    this.timer = setTimeout(() => {
      this.enterApp();
    }, 1500);
  }

  aboutToDisappear() {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = 0;
    }
  }

  /**
   * 进入主界面的分流：
   * navigating 防止重复点击/重复计时导致多次跳转；
   * 已登录启动 MainAbility，未登录去登录页。
   */
  async enterApp() {
    if (this.navigating) {
      return;
    }
    this.navigating = true;
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = 0;
    }

    const context = getContext(this) as common.UIAbilityContext;
    const loggedIn: boolean = await this.authService.isLoggedIn();
    if (!loggedIn) {
      this.navigating = false;
      router.replaceUrl({ url: 'pages/LoginPage' });
      return;
    }

    const want: Want = {
      bundleName: context.applicationInfo.name,
      abilityName: 'MainAbility'
    };
    try {
      await context.startAbility(want);
      // 给 MainAbility 留出创建窗口的时间，避免同进程 Ability 切换时窗口被提前销毁
      setTimeout(() => {
        context.terminateSelf();
      }, 800);
    } catch (e) {
      console.error('Start MainAbility failed:', e);
      this.navigating = false;
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#FDEBED', 0.0], ['#F7F6F2', 1.0]]
        })

      Image($r('app.media.welcome_glow'))
        .width(480)
        .height(480)
        .position({ x: '52%', y: '-10%' })

      Column() {
        Blank()

        Stack() {
          Image($r('app.media.startIcon'))
            .width(96)
            .height(96)
            .borderRadius(26)
            .objectFit(ImageFit.Cover)
        }
        .width(96)
        .height(96)
        .shadow({ radius: 24, color: '#40C8424C', offsetY: 8 })

        Text('清听')
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textPrimary)
          .margin({ top: 22 })

        Text('听见每一天')
          .fontSize(14)
          .fontColor(this.textSecondary)
          .margin({ top: 8 })

        Blank()
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgPrimary)
  }
}
