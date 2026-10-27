/**
 * 文件：ProfileView.ets
 * 职责：我的 Tab，显示个人卡、收藏 / 最近播放统计、设置入口与退出登录。
 *
 * 与 FavoritesView 一样，数据由 Index 通过 @Prop 传入，
 * 点击设置 / 退出 / 查看收藏通过回调交给 Index 处理。
 * 个人卡里不重复放退出按钮，避免和底部操作区重复。
 */
@Component
export struct ProfileView {
  @StorageLink('bgPrimary') bgPrimary: string = '#F7F6F2';
  @StorageLink('bgSecondary') bgSecondary: string = '#FFFFFF';
  @StorageLink('textPrimary') textPrimary: string = '#17181A';
  @StorageLink('textSecondary') textSecondary: string = '#6B6F76';
  @StorageLink('textTertiary') textTertiary: string = '#9A9EA5';
  @StorageLink('accent') accent: string = '#C8424C';
  @StorageLink('accentLight') accentLight: string = '#FDEBED';
  @StorageLink('border') themeBorder: string = '#ECE8E0';

  @Prop nickname: string = 'demo';
  @Prop favoriteCount: number = 0;
  @Prop historyCount: number = 0;

  onOpenSettings: () => void = () => {};
  onLogout: () => void = () => {};
  onOpenFavorites: () => void = () => {};

  @Builder
  FavoriteStat() {
    Column() {
      Text(`${this.favoriteCount}`)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.textPrimary)
      Text('收藏')
        .fontSize(12)
        .fontColor(this.textTertiary)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .onClick(() => {
      this.onOpenFavorites();
    })
  }

  @Builder
  HistoryStat() {
    Column() {
      Text(`${this.historyCount}`)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.textPrimary)
      Text('最近播放')
        .fontSize(12)
        .fontColor(this.textTertiary)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .onClick(() => {
      this.onOpenFavorites();
    })
  }

  build() {
    Column() {
      Row()
        .height(110)
        .width('100%')

      Scroll() {
        Column() {
          // 个人卡
          Column() {
            Row() {
              Stack() {
                Circle()
                  .width(64)
                  .height(64)
                  .fill(this.accentLight)
                SymbolGlyph($r('sys.symbol.person_fill'))
                  .fontSize(34)
                  .fontColor([this.accent])
              }
              .width(64)
              .height(64)

              Column() {
                Text(this.nickname || 'demo')
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.textPrimary)
                Text('本地演示账号')
                  .fontSize(12)
                  .fontColor(this.textTertiary)
                  .margin({ top: 5 })
              }
              .layoutWeight(1)
              .margin({ left: 14 })
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Divider()
              .strokeWidth(0.5)
              .color(this.themeBorder)
              .margin({ top: 18, bottom: 14 })

            Row() {
              this.FavoriteStat()
              Divider()
                .vertical(true)
                .height(28)
                .strokeWidth(0.5)
                .color(this.themeBorder)
              this.HistoryStat()
            }
            .width('100%')
          }
          .width('100%')
          .padding(20)
          .backgroundColor(this.bgSecondary)
          .borderRadius(20)

          // 设置与退出
          Column() {
            Row() {
              SymbolGlyph($r('sys.symbol.gearshape'))
                .fontSize(20)
                .fontColor([this.accent])
              Text('设置')
                .fontSize(15)
                .fontColor(this.textPrimary)
                .layoutWeight(1)
                .margin({ left: 12 })
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(16)
                .fontColor([this.textTertiary])
            }
            .width('100%')
            .height(56)
            .padding({ left: 18, right: 16 })
            .onClick(() => {
              this.onOpenSettings();
            })

            Divider()
              .strokeWidth(0.5)
              .color(this.themeBorder)
              .margin({ left: 18, right: 18 })

            Row() {
              Text('退出登录')
                .fontSize(15)
                .fontColor(this.accent)
                .layoutWeight(1)
              Text('清除登录态并回到登录页')
                .fontSize(12)
                .fontColor(this.textTertiary)
            }
            .width('100%')
            .height(56)
            .padding({ left: 18, right: 16 })
            .onClick(() => {
              this.onLogout();
            })
          }
          .width('100%')
          .backgroundColor(this.bgSecondary)
          .borderRadius(20)
          .margin({ top: 14 })

          Text('清听 · HarmonyOS 课程设计')
            .fontSize(12)
            .fontColor(this.textTertiary)
            .margin({ top: 24, bottom: 120 })
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
        .constraintSize({ minHeight: '100%' })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}
