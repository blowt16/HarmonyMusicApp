import { common, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AuthService } from '../services/AuthService';
import { AuthValidationResult } from '../services/AuthValidator';

@Entry
@Component
struct LoginPage {
  @StorageLink('bgPrimary') bgPrimary: string = '#F7F6F2';
  @StorageLink('bgSecondary') bgSecondary: string = '#FFFFFF';
  @StorageLink('textPrimary') textPrimary: string = '#17181A';
  @StorageLink('textSecondary') textSecondary: string = '#6B6F76';
  @StorageLink('textTertiary') textTertiary: string = '#9A9EA5';
  @StorageLink('accent') accent: string = '#C8424C';
  @StorageLink('accentLight') accentLight: string = '#FDEBED';
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  @State username: string = '';
  @State password: string = '';
  @State agreed: boolean = false;
  @State usernameError: string = '';
  @State passwordError: string = '';
  @State generalError: string = '';
  @State loginLoading: boolean = false;

  private authService: AuthService = AuthService.getInstance();

  aboutToAppear() {
    this.authService.setContext(getContext(this));
    this.setStatusBarLight(true);
  }

  aboutToDisappear() {
    this.setStatusBarLight(false);
  }

  async setStatusBarLight(lightContent: boolean) {
    try {
      const mainWindow = await window.getLastWindow(getContext(this));
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: lightContent ? '#FFFFFF' : '#000000',
        navigationBarContentColor: '#000000'
      });
    } catch (e) {
      // 系统栏设置失败时保持 Ability 默认值
    }
  }

  async doLogin() {
    this.usernameError = '';
    this.passwordError = '';
    this.generalError = '';

    if (!this.agreed) {
      promptAction.showToast({ message: '请先勾选演示使用说明', duration: 1500 });
      return;
    }

    const validation: AuthValidationResult = AuthService.validate(this.username, this.password);
    if (!validation.success) {
      if (validation.message === '请输入账号') {
        this.usernameError = validation.message;
      } else {
        this.passwordError = validation.message;
      }
      return;
    }

    this.loginLoading = true;
    const result: AuthValidationResult = await this.authService.login(this.username, this.password);
    if (!result.success) {
      this.generalError = result.message;
      this.loginLoading = false;
      return;
    }

    const context = getContext(this) as common.UIAbilityContext;
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
      this.generalError = '进入主界面失败，请重试';
      this.loginLoading = false;
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.bgPrimary)

      Scroll() {
        Column() {
          // 珊瑚色装饰区
          Stack({ alignContent: Alignment.TopStart }) {
            Column()
              .width('100%')
              .height(300)
              .linearGradient({
                angle: 160,
                colors: [['#E4575F', 0.0], ['#C8424C', 1.0]]
              })

            Column() {
              Row()
                .height(this.statusBarHeight + 44)
                .width('100%')

              Row() {
                Image($r('app.media.startIcon'))
                  .width(52)
                  .height(52)
                  .borderRadius(14)
                  .objectFit(ImageFit.Cover)
                Column() {
                  Text('清听')
                    .fontSize(26)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                  Text('听见每一天')
                    .fontSize(12)
                    .fontColor('#FFE4E6')
                    .margin({ top: 4 })
                }
                .margin({ left: 12 })
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Text('登录后收藏喜欢的歌曲\n和最近播放记录都会保存在本机')
                .fontSize(14)
                .fontColor('#FFF1F2')
                .lineHeight(22)
                .margin({ top: 30 })
            }
            .width('100%')
            .height(300)
            .padding({ left: 24, right: 24 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .height(300)

          // 表单面板
          Column() {
            Text('欢迎回来')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textPrimary)
              .width('100%')

            Text('使用固定演示账号进入清听')
              .fontSize(13)
              .fontColor(this.textSecondary)
              .width('100%')
              .margin({ top: 6 })

            Column() {
              TextInput({ placeholder: '请输入账号', text: this.username })
                .width('100%')
                .height(52)
                .fontSize(15)
                .fontColor(this.textPrimary)
                .placeholderColor(this.textTertiary)
                .backgroundColor(this.bgPrimary)
                .borderRadius(16)
                .padding({ left: 16, right: 16 })
                .onChange((value: string) => {
                  this.username = value;
                  this.usernameError = '';
                  this.generalError = '';
                })
            }
            .width('100%')
            .margin({ top: 24 })

            if (this.usernameError) {
              Text(this.usernameError)
                .fontSize(11)
                .fontColor(this.accent)
                .width('100%')
                .padding({ left: 4, top: 4 })
            }

            TextInput({ placeholder: '请输入密码', text: this.password })
              .width('100%')
              .height(52)
              .type(InputType.Password)
              .fontSize(15)
              .fontColor(this.textPrimary)
              .placeholderColor(this.textTertiary)
              .backgroundColor(this.bgPrimary)
              .borderRadius(16)
              .padding({ left: 16, right: 16 })
              .margin({ top: 8 })
              .onChange((value: string) => {
                this.password = value;
                this.passwordError = '';
                this.generalError = '';
              })
              .onSubmit(() => {
                this.doLogin();
              })

            if (this.passwordError) {
              Text(this.passwordError)
                .fontSize(11)
                .fontColor(this.accent)
                .width('100%')
                .padding({ left: 4, top: 4 })
            }

            if (this.generalError) {
              Text(this.generalError)
                .fontSize(12)
                .fontColor(this.accent)
                .width('100%')
                .margin({ bottom: 8 })
            }

            Row() {
              Checkbox({ name: 'demo_agreement', group: 'login' })
                .width(20)
                .height(20)
                .selectedColor(this.accent)
                .select(this.agreed)
                .onChange((value: boolean) => {
                  this.agreed = value;
                })
              Text('我已阅读并同意')
                .fontSize(12)
                .fontColor(this.textSecondary)
                .margin({ left: 6 })
              Text('《演示使用说明》')
                .fontSize(12)
                .fontColor(this.accent)
                .onClick(() => {
                  promptAction.showToast({
                    message: '课程演示应用：固定账号本地校验，不连接真实账号系统，不保存密码。',
                    duration: 2500
                  });
                })
            }
            .width('100%')
            .margin({ top: 8, bottom: 16 })

            Button(this.loginLoading ? '登录中…' : '登录')
              .width('100%')
              .height(52)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .backgroundColor(this.accent)
              .borderRadius(26)
              .enabled(!this.loginLoading)
              .opacity(this.loginLoading ? 0.6 : 1)
              .onClick(() => {
                this.doLogin();
              })

            Text('演示账号：demo / 123456')
              .fontSize(12)
              .fontColor(this.textSecondary)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 18 })

            Text('本项目为课程演示，本地校验，不连接真实账号系统，也不保存密码。')
              .fontSize(11)
              .fontColor(this.textTertiary)
              .width('100%')
              .textAlign(TextAlign.Center)
              .lineHeight(17)
              .margin({ top: 8 })
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 28, bottom: 32 })
          .backgroundColor(this.bgSecondary)
          .borderRadius({ topLeft: 28, topRight: 28 })
          .margin({ top: -28 })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
  }
}
