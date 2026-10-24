import { StorageService } from '../services/StorageService';
import { LocalMusicService } from '../services/LocalMusicService';
import { PlayerService } from '../services/PlayerService';
import { Song } from '../models/MusicModel';
import { TimeUtils } from '../utils/TimeUtils';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  hdsMaterial,
  ScrollEffectType,
  BlurStrategy
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';

@Entry
@Component
struct LocalMusicPage {
  @StorageLink('bgPrimary') bgPrimary: string = '#F7F6F2';
  @StorageLink('bgSecondary') bgSecondary: string = '#FFFFFF';
  @StorageLink('textPrimary') textPrimary: string = '#17181A';
  @StorageLink('textSecondary') textSecondary: string = '#6B6F76';
  @StorageLink('textTertiary') textTertiary: string = '#9A9EA5';
  @StorageLink('accent') accent: string = '#C8424C';
  @StorageLink('accentLight') accentLight: string = '#FDEBED';
  @StorageLink('border') themeBorder: string = '#ECE8E0';

  @State songs: Song[] = [];
  @State importing: boolean = false;
  @State customMaterialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;

  private storageService: StorageService = StorageService.getInstance();
  private playerService: PlayerService = PlayerService.getInstance();

  aboutToAppear() {
    this.storageService.setContext(getContext(this));
    const materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
    if (materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0) {
      this.customMaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;
    }
    this.loadSongs();
  }

  onPageShow() {
    this.loadSongs();
  }

  async loadSongs() {
    this.songs = await this.storageService.getLocalSongs();
  }

  async importMusic() {
    if (this.importing) {
      return;
    }
    this.importing = true;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const count: number = await LocalMusicService.importSongs(context);
      await this.loadSongs();
      promptAction.showToast({
        message: count > 0 ? `已导入 ${count} 首本地音乐` : '没有导入新的音频',
        duration: 2000
      });
    } catch (e) {
      console.error('Import local music error:', e);
      promptAction.showToast({ message: '导入失败，请重试', duration: 2000 });
    }
    this.importing = false;
  }

  async playSong(song: Song, index: number) {
    this.playerService.setPlaylist(this.songs, index);
    await this.playerService.playAt(index);
    router.pushUrl({ url: 'pages/PlayPage' });
  }

  confirmDelete(song: Song) {
    AlertDialog.show({
      title: '删除本地歌曲',
      message: `确定删除「${song.name}」？文件也会从应用私有目录删除。`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#C8424C',
        action: () => {
          this.deleteSong(song);
        }
      }
    });
  }

  async deleteSong(song: Song) {
    if (this.playerService.getCurrentSong()?.id === song.id) {
      this.playerService.stop();
      await this.playerService.release();
      this.playerService.reset();
    }
    await LocalMusicService.deleteSong(song);
    await this.loadSongs();
    promptAction.showToast({ message: '已删除本地音乐', duration: 1500 });
  }

  formatDuration(ms: number): string {
    if (!ms || ms <= 0) {
      return '--:--';
    }
    return TimeUtils.formatDuration(ms);
  }

  @Builder
  HeaderCard() {
    Column() {
      Row() {
        Column() {
          Text('本地音乐')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textPrimary)
          Text(`已导入 ${this.songs.length} 首`)
            .fontSize(12)
            .fontColor(this.textTertiary)
            .margin({ top: 5 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button(this.importing ? '导入中…' : '导入音频')
          .height(42)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor(this.accent)
          .borderRadius(21)
          .enabled(!this.importing)
          .opacity(this.importing ? 0.6 : 1)
          .onClick(() => {
            this.importMusic();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text('支持 MP3 / FLAC / M4A / AAC / WAV / OGG。文件只复制到应用私有目录，不上传、不提交仓库，卸载应用后删除。')
        .fontSize(11)
        .fontColor(this.textTertiary)
        .lineHeight(17)
        .width('100%')
        .margin({ top: 12 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.bgSecondary)
    .borderRadius(20)
  }

  @Builder
  EmptyBlock() {
    Column() {
      Text('♪')
        .fontSize(46)
        .fontColor(this.accent)
        .opacity(0.8)
      Text('还没有导入本地音乐')
        .fontSize(15)
        .fontColor(this.textPrimary)
        .margin({ top: 14 })
      Text('从手机里选择自己合法持有的音频文件')
        .fontSize(12)
        .fontColor(this.textTertiary)
        .margin({ top: 6 })
      Button(this.importing ? '导入中…' : '导入音频')
        .height(40)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(this.accent)
        .borderRadius(20)
        .margin({ top: 18 })
        .enabled(!this.importing)
        .onClick(() => {
          this.importMusic();
        })
    }
    .width('100%')
    .padding({ top: 30, bottom: 30 })
    .backgroundColor(this.bgSecondary)
    .borderRadius(20)
  }

  @Builder
  SongRow(song: Song, index: number) {
    Row() {
      Stack() {
        Text('♪')
          .fontSize(20)
          .fontColor(this.accent)
      }
      .width(44)
      .height(44)
      .borderRadius(10)
      .backgroundColor(this.accentLight)

      Column() {
        Text(song.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(song.id === this.playerService.getCurrentSong()?.id ? this.accent : this.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`${song.artist} · ${song.album}`)
          .fontSize(12)
          .fontColor(this.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)

      Text(this.formatDuration(song.duration))
        .fontSize(12)
        .fontColor(this.textTertiary)
        .margin({ right: 10 })

      Button('删除')
        .type(ButtonType.Normal)
        .width(64)
        .height(40)
        .padding(0)
        .fontSize(12)
        .fontColor(this.accent)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.confirmDelete(song);
        })
    }
    .width('100%')
    .height(68)
    .padding({ left: 14, right: 10 })
    .backgroundColor(this.bgSecondary)
    .onClick(() => {
      this.playSong(song, index);
    })
  }

  build() {
    HdsNavigation() {
      Column() {
        Row()
          .height(110)
          .width('100%')

        Column() {
          this.HeaderCard()

          if (this.songs.length === 0) {
            Column() {
              this.EmptyBlock()
            }
            .margin({ top: 14 })
          } else {
            List({ space: 1 }) {
              ForEach(this.songs, (song: Song, index: number) => {
                ListItem() {
                  this.SongRow(song, index)
                }
              })
              ListItem() {
                Row().width('100%').height(40)
              }
            }
            .width('100%')
            .layoutWeight(1)
            .margin({ top: 14 })
            .backgroundColor(this.bgSecondary)
            .borderRadius(20)
            .clip(true)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 20, right: 20 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.bgPrimary)
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: '本地音乐' }
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
