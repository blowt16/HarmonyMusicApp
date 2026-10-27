import { EffectLevel } from '../models/MusicModel';
import { StorageService } from '../services/StorageService';
import { PlayerService } from '../services/PlayerService';
import { LOCAL_DEMO_SONG, LOCAL_FALLBACK_SONGS } from '../services/MockData';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { common } from '@kit.AbilityKit';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  hdsMaterial,
  ScrollEffectType,
  BlurStrategy
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';

interface BuiltInBackground {
  name: string;
  rawFile: string;
  preview: Resource;
}

const BUILTIN_BACKGROUNDS: BuiltInBackground[] = [
  { name: '晨光', rawFile: 'backgrounds/bg_sunrise.jpg', preview: $rawfile('backgrounds/bg_sunrise.jpg') },
  { name: '天蓝', rawFile: 'backgrounds/bg_sky.jpg', preview: $rawfile('backgrounds/bg_sky.jpg') },
  { name: '薄荷', rawFile: 'backgrounds/bg_mint.jpg', preview: $rawfile('backgrounds/bg_mint.jpg') },
  { name: '柔光', rawFile: 'backgrounds/bg_pastel.jpg', preview: $rawfile('backgrounds/bg_pastel.jpg') },
  { name: '玻璃', rawFile: 'backgrounds/bg_glass.jpg', preview: $rawfile('backgrounds/bg_glass.jpg') },
  { name: '现场', rawFile: 'backgrounds/bg_concert.jpg', preview: $rawfile('backgrounds/bg_concert.jpg') },
  { name: '黑胶', rawFile: 'backgrounds/bg_vinyl.jpg', preview: $rawfile('backgrounds/bg_vinyl.jpg') }
];

@Component
struct EffectLevelOption {
  @StorageLink('textPrimary') textPrimary: string = '#17181A';
  @StorageLink('textSecondary') textSecondary: string = '#6B6F76';
  @StorageLink('accent') accent: string = '#C8424C';
  @StorageLink('accentLight') accentLight: string = '#FDEBED';
  @StorageLink('effectLevel') globalLevel: number = EffectLevel.MEDIUM;

  @Prop level: EffectLevel;
  @Prop label: string;
  @Prop desc: string;

  private storageService: StorageService = StorageService.getInstance();
  private playerService: PlayerService = PlayerService.getInstance();

  build() {
    Row() {
      Column() {
        Text(this.label)
          .fontSize(15)
          .fontColor(this.globalLevel === this.level ? this.accent : this.textPrimary)
          .fontWeight(this.globalLevel === this.level ? FontWeight.Bold : FontWeight.Medium)
        Text(this.desc)
          .fontSize(12)
          .fontColor(this.textSecondary)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.globalLevel === this.level) {
        Text('✓')
          .fontSize(18)
          .fontColor(this.accent)
          .fontWeight(FontWeight.Bold)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 13, bottom: 13 })
    .backgroundColor(this.globalLevel === this.level ? this.accentLight : Color.Transparent)
    .borderRadius(12)
    .onClick(async () => {
      this.globalLevel = this.level;
      await this.storageService.setEffectLevel(this.level);
    })
  }
}

@Entry
@Component
struct SettingsPage {
  @StorageLink('bgPrimary') bgPrimary: string = '#F7F6F2';
  @StorageLink('bgSecondary') bgSecondary: string = '#FFFFFF';
  @StorageLink('textPrimary') textPrimary: string = '#17181A';
  @StorageLink('textSecondary') textSecondary: string = '#6B6F76';
  @StorageLink('textTertiary') textTertiary: string = '#9A9EA5';
  @StorageLink('accent') accent: string = '#C8424C';
  @StorageLink('accentLight') accentLight: string = '#FDEBED';
  @StorageLink('border') themeBorder: string = '#ECE8E0';
  @StorageLink('bgImage') bgImage: string = '';
  @StorageLink('bgOpacity') bgOpacity: number = 0.15;
  @StorageLink('isDark') isDark: boolean = false;

  @State customMaterialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;

  private storageService: StorageService = StorageService.getInstance();
  private playerService: PlayerService = PlayerService.getInstance();

  aboutToAppear(): void {
    const materialTypes: hdsMaterial.MaterialType[] = hdsMaterial.getSystemMaterialTypes();
    if (materialTypes.includes(hdsMaterial.MaterialType.IMMERSIVE)) {
      this.customMaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;
    } else {
      this.customMaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;
    }
  }

  async pickBgImage() {
    try {
      const photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      const photoViewPicker = new picker.PhotoViewPicker();
      const result = await photoViewPicker.select(photoSelectOptions);
      if (result.photoUris.length > 0) {
        AppStorage.setOrCreate<string>('bgImage', result.photoUris[0]);
        await this.storageService.setBgImage(result.photoUris[0]);
        promptAction.showToast({ message: '背景图片已更换', duration: 1500 });
      }
    } catch (e) {
      console.error('Pick background image error:', e);
      promptAction.showToast({ message: '选择图片失败', duration: 1500 });
    }
  }

  async clearBgImage() {
    AppStorage.setOrCreate<string>('bgImage', '');
    await this.storageService.setBgImage('');
    promptAction.showToast({ message: '已恢复默认背景', duration: 1500 });
  }

  isBuiltInSelected(bg: BuiltInBackground): boolean {
    const fileName: string = bg.rawFile.substring(bg.rawFile.lastIndexOf('/') + 1);
    return this.bgImage.endsWith(fileName);
  }

  async applyBuiltInBackground(bg: BuiltInBackground) {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const data: Uint8Array = await context.resourceManager.getRawFileContent(bg.rawFile);
      const dir: string = context.filesDir + '/backgrounds';
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir);
      }
      const fileName: string = bg.rawFile.substring(bg.rawFile.lastIndexOf('/') + 1);
      const path: string = dir + '/' + fileName;
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, data.buffer);
      fs.closeSync(file);
      const uri: string = 'file://' + path;
      AppStorage.setOrCreate<string>('bgImage', uri);
      await this.storageService.setBgImage(uri);
      // 内置背景默认至少 35% 遮罩，避免主界面文字压在彩色图上不好读
      if (this.bgOpacity < 0.35) {
        await this.setBgOpacity(0.35);
      }
      promptAction.showToast({ message: '背景已应用', duration: 1500 });
    } catch (e) {
      console.error('Apply built-in background error:', e);
      promptAction.showToast({ message: '背景设置失败，请重试', duration: 2000 });
    }
  }

  async setBgOpacity(opacity: number) {
    AppStorage.setOrCreate<number>('bgOpacity', opacity);
    await this.storageService.setBgOpacity(opacity);
  }

  @Builder
  GroupTitle(title: string) {
    Row() {
      Text(title)
        .fontSize(13)
        .fontColor(this.textSecondary)
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .padding({ top: 22, bottom: 8, left: 4 })
  }

  @Builder
  EffectGroup() {
    Column() {
      EffectLevelOption({ level: EffectLevel.OFF, label: '关闭', desc: '无光感效果，纯净界面' })
      Divider().strokeWidth(0.5).color(this.themeBorder).margin({ left: 16, right: 16 })
      EffectLevelOption({ level: EffectLevel.LOW, label: '低', desc: '轻微光晕，低调优雅' })
      Divider().strokeWidth(0.5).color(this.themeBorder).margin({ left: 16, right: 16 })
      EffectLevelOption({ level: EffectLevel.MEDIUM, label: '中', desc: '适中光感，推荐选择' })
      Divider().strokeWidth(0.5).color(this.themeBorder).margin({ left: 16, right: 16 })
      EffectLevelOption({ level: EffectLevel.HIGH, label: '高', desc: '强烈光效，视觉震撼' })
    }
    .width('100%')
    .padding(4)
    .backgroundColor(this.bgSecondary)
    .borderRadius(20)
  }

  @Builder
  BackgroundGroup() {
    Column() {
      if (this.bgImage) {
        Stack() {
          Image(this.bgImage)
            .width('100%')
            .height(120)
            .objectFit(ImageFit.Cover)
            .borderRadius(12)
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor(this.isDark ? '#000000' : '#FFFFFF')
            .opacity(this.bgOpacity)
        }
        .width('100%')
        .height(120)
        .margin({ bottom: 12 })
      }

      Button(this.bgImage ? '更换背景图片' : '选择背景图片')
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(this.accent)
        .borderRadius(22)
        .onClick(() => {
          this.pickBgImage();
        })

      Text('推荐背景')
        .width('100%')
        .textAlign(TextAlign.Start)
        .fontSize(13)
        .fontColor(this.textSecondary)
        .margin({ top: 14, bottom: 8 })

      List({ space: 10 }) {
        ForEach(BUILTIN_BACKGROUNDS, (bg: BuiltInBackground) => {
          ListItem() {
            Column() {
              Image(bg.preview)
                .width(72)
                .height(128)
                .borderRadius(10)
                .objectFit(ImageFit.Cover)
                .border({
                  width: this.isBuiltInSelected(bg) ? 2 : 0,
                  color: this.accent
                })

              Text(bg.name)
                .fontSize(11)
                .fontColor(this.textSecondary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width(72)
                .textAlign(TextAlign.Center)
                .margin({ top: 4 })
            }
            .width(72)
            .onClick(() => {
              this.applyBuiltInBackground(bg);
            })
          }
        })
      }
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(152)

      if (this.bgImage) {
        Row() {
          Text('透明度')
            .fontSize(13)
            .fontColor(this.textSecondary)
          Slider({
            value: this.bgOpacity * 100,
            min: 5,
            max: 60,
            step: 5
          })
            .selectedColor(this.accent)
            .layoutWeight(1)
            .margin({ left: 12 })
            .onChange((value: number) => {
              this.setBgOpacity(value / 100);
            })
          Text(`${Math.round(this.bgOpacity * 100)}%`)
            .fontSize(12)
            .fontColor(this.textSecondary)
            .width(40)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .padding({ top: 14 })

        Button('恢复默认背景')
          .width('100%')
          .height(40)
          .fontSize(13)
          .fontColor(this.accent)
          .backgroundColor(this.accentLight)
          .borderRadius(20)
          .margin({ top: 10 })
          .onClick(() => {
            this.clearBgImage();
          })
      }

      Text('背景图片会显示在主界面、搜索、收藏和歌单页，播放页固定深色沉浸。')
        .fontSize(11)
        .fontColor(this.textTertiary)
        .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.bgSecondary)
    .borderRadius(20)
  }

  @Builder
  LocalDemoGroup() {
    Column() {
      Row() {
        Column() {
          Text('播放本地示例')
            .fontSize(15)
            .fontColor(this.textPrimary)
            .fontWeight(FontWeight.Medium)
          Text('断网演示 · 24 秒项目自生成环境音，无第三方版权')
            .fontSize(11)
            .fontColor(this.textTertiary)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.play_fill'))
          .fontSize(18)
          .fontColor([this.accent])
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .onClick(() => {
        this.playerService.setPlaylist(LOCAL_FALLBACK_SONGS, 0);
        this.playerService.playSong(LOCAL_DEMO_SONG);
        router.pushUrl({ url: 'pages/PlayPage' });
      })
    }
    .width('100%')
    .backgroundColor(this.bgSecondary)
    .borderRadius(20)
  }

  @Builder
  AboutGroup() {
    Column() {
      Row() {
        Text('应用名称')
          .fontSize(14)
          .fontColor(this.textPrimary)
        Blank()
        Text('清听')
          .fontSize(14)
          .fontColor(this.textSecondary)
      }
      .width('100%')
      .height(44)

      Divider().strokeWidth(0.5).color(this.themeBorder)

      Row() {
        Text('版本')
          .fontSize(14)
          .fontColor(this.textPrimary)
        Blank()
        Text('1.0.0')
          .fontSize(14)
          .fontColor(this.textSecondary)
      }
      .width('100%')
      .height(44)

      Divider().strokeWidth(0.5).color(this.themeBorder)

      Text('课程设计演示应用：固定演示账号，本地校验，不连接真实账号系统。在线数据来自公开音乐接口，失败时使用本地示例。')
        .fontSize(11)
        .fontColor(this.textTertiary)
        .lineHeight(18)
        .width('100%')
        .padding({ top: 12, bottom: 4 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    .backgroundColor(this.bgSecondary)
    .borderRadius(20)
  }

  build() {
    HdsNavigation() {
      Scroll() {
        Column() {
          Row()
            .height(70)
            .width('100%')

          Column() {
            this.GroupTitle('播放效果')
            this.EffectGroup()

            this.GroupTitle('背景设置')
            this.BackgroundGroup()

            this.GroupTitle('本地示例')
            this.LocalDemoGroup()

            this.GroupTitle('关于')
            this.AboutGroup()

            Blank().height(40)
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor(this.bgPrimary)
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: '设置' }
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(40)
        },
        blurStrategy: BlurStrategy.ADAPTIVE,
        originalStyle: { backgroundStyle: { backgroundColor: '#00F7F6F2' } },
        scrollEffectStyle: { backgroundStyle: { backgroundColor: '#00F7F6F2' } },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: this.customMaterialLevel
        }
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(false)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
