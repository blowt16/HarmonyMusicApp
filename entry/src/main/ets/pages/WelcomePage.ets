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

  aboutToAppear() {
    this.authService.setContext(getContext(this));
    const skipDelay: boolean = AppStorage.get<boolean>('skipWelcomeDelay') === true;
    if (skipDelay) {
      AppStorage.setOrCreate<boolean>('skipWelcomeDelay', false);
      this.enterApp();
      return;
    }
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
