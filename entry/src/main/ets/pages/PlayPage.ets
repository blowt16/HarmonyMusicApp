import { PlayerService } from '../services/PlayerService';
import { StorageService } from '../services/StorageService';
import { thumbnail } from '../utils/ImageUtils';
import { Song, PlayerState, AudioQuality, SongQualityInfo } from '../models/MusicModel';
import { PlayerControls } from '../components/PlayerControls';
import { LyricView } from '../components/LyricView';
import router from '@ohos.router';
import { window } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct PlayPage {
  @StorageLink('playerBg') playerBg: string = '#0B0C10';
  @StorageLink('playerSurface') playerSurface: string = '#1A1A20';
  @StorageLink('playerText') playerText: string = '#F5F5F7';
  @StorageLink('playerMuted') playerMuted: string = '#C9C7D0';
  @StorageLink('playerAccent') playerAccent: string = '#FF6B72';
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  @State currentSong: Song | null = null;
  @State playerState: PlayerState = PlayerState.STOPPED;
  @State coverRotation: number = 0;
  @State isFavorite: boolean = false;
  @State currentQuality: AudioQuality = AudioQuality.EXHIGH;
  @State showQualityDialog: boolean = false;
  @State showPlaylist: boolean = false;
  @State swiperIndex: number = 0;

  private playerService: PlayerService = PlayerService.getInstance();
  private storageService: StorageService = StorageService.getInstance();
  private timer: number = 0;
  private swiperController: SwiperController = new SwiperController();

  private songListener: ((song: Song | null) => void) | null = null;
  private stateListener: ((state: PlayerState) => void) | null = null;

  async aboutToAppear() {
    this.applyPlayerTokens();
    this.setStatusBarLight(true);

    this.currentSong = this.playerService.getCurrentSong();
    this.playerState = this.playerService.getPlayerState();
    this.currentQuality = this.playerService.getQuality();
    if (this.playerState === PlayerState.PLAYING) {
      this.startRotation();
    }

    this.songListener = async (song: Song | null) => {
      this.currentSong = song;
      if (song) {
        this.isFavorite = await this.storageService.isFavorite(song.id);
      }
      if (song && this.playerState !== PlayerState.PLAYING && this.playerState !== PlayerState.LOADING) {
        this.playerService.playSong(song);
      }
    };
    this.playerService.addSongChangeListener(this.songListener);

    this.stateListener = (state: PlayerState) => {
      this.playerState = state;
      if (state === PlayerState.PLAYING) {
        this.startRotation();
      } else {
        this.stopRotation();
      }
    };
    this.playerService.addStateChangeListener(this.stateListener);

    if (this.currentSong) {
      this.isFavorite = await this.storageService.isFavorite(this.currentSong.id);
    }
  }

  aboutToDisappear() {
    this.stopRotation();
    this.setStatusBarLight(false);
    this.restorePlayerTokens();
    if (this.songListener) {
      this.playerService.removeSongChangeListener(this.songListener);
    }
    if (this.stateListener) {
      this.playerService.removeStateChangeListener(this.stateListener);
    }
  }

  applyPlayerTokens() {
    AppStorage.setOrCreate<string>('playerBg', '#0B0C10');
    AppStorage.setOrCreate<string>('playerSurface', '#1A1A20');
    AppStorage.setOrCreate<string>('playerText', '#F5F5F7');
    AppStorage.setOrCreate<string>('playerMuted', '#C9C7D0');
    AppStorage.setOrCreate<string>('playerAccent', '#FF6B72');
  }

  restorePlayerTokens() {
    AppStorage.setOrCreate<string>('playerBg', '#F7F6F2');
    AppStorage.setOrCreate<string>('playerSurface', '#FFFFFF');
    AppStorage.setOrCreate<string>('playerText', '#17181A');
    AppStorage.setOrCreate<string>('playerMuted', '#6B6F76');
    AppStorage.setOrCreate<string>('playerAccent', '#C8424C');
  }

  async setStatusBarLight(darkPage: boolean) {
    try {
      const mainWindow = await window.getLastWindow(getContext(this));
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: darkPage ? '#0B0C10' : '#F7F6F2',
        statusBarContentColor: darkPage ? '#FFFFFF' : '#000000',
        navigationBarContentColor: darkPage ? '#FFFFFF' : '#000000'
      });
    } catch (e) {
      // 系统栏设置失败时保持当前值
    }
  }

  startRotation() {
    if (this.timer) {
      return;
    }
    this.timer = setInterval(() => {
      this.coverRotation = (this.coverRotation + 1) % 360;
    }, 50);
  }

  stopRotation() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = 0;
    }
  }

  async toggleFavorite() {
    if (!this.currentSong) {
      return;
    }
    this.isFavorite = await this.storageService.toggleFavorite(this.currentSong);
  }

  @Builder
  Header() {
    Row() {
      Button() {
        Text('‹')
          .fontSize(30)
          .fontColor(this.playerText)
          .width('100%')
          .height(30)
          .textAlign(TextAlign.Center)
          .offset({ y: -4 })
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .backgroundColor('#26FFFFFF')
      .onClick(() => {
        router.back();
      })

      Text(this.swiperIndex === 0 ? '正在播放' : (this.currentSong?.name || '歌词'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.playerText)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: 14, right: 10 })

      Text(this.getQualityLabel(this.currentQuality))
        .fontSize(12)
        .fontColor(this.playerMuted)
        .height(34)
        .padding({ left: 14, right: 14 })
        .backgroundColor('#1AFFFFFF')
        .borderRadius(17)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.showQualityDialog = true;
        })

      Button() {
        SymbolGlyph(this.isFavorite ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
          .fontSize(20)
          .fontColor([this.isFavorite ? this.playerAccent : this.playerText])
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .backgroundColor('#26FFFFFF')
      .margin({ left: 10 })
      .onClick(() => {
        this.toggleFavorite();
      })
    }
    .width('100%')
    .padding({ left: 20, right: 20 })
    .margin({ top: this.statusBarHeight + 12 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Stack() {
      // 深色背景：封面放大模糊 + 深色遮罩
      if (this.currentSong?.coverUrl) {
        Image(thumbnail(this.currentSong.coverUrl, 500, 500))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .blur(50)
          .scale({ x: 1.25, y: 1.25 })
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.playerBg)
          .opacity(0.74)
      } else {
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 180,
            colors: [['#1E1E26', 0.0], ['#0B0C10', 1.0]]
          })
      }

      Column() {
        this.Header()

        Swiper(this.swiperController) {
          // 封面页
          Column() {
            if (this.currentSong?.coverUrl) {
              Image(thumbnail(this.currentSong.coverUrl, 300, 300))
                .width(250)
                .height(250)
                .borderRadius(125)
                .border({ width: 6, color: '#33FFFFFF' })
                .rotate({ angle: this.coverRotation })
                .objectFit(ImageFit.Cover)
                .backgroundColor(this.playerSurface)
                .shadow({ radius: 24, color: '#99000000' })
            } else {
              Stack() {
                Circle()
                  .width(250)
                  .height(250)
                  .fill('#26FF6B72')
                Text('♪')
                  .fontSize(76)
                  .fontColor(this.playerAccent)
              }
              .width(250)
              .height(250)
              .borderRadius(125)
              .border({ width: 6, color: '#33FFFFFF' })
              .shadow({ radius: 24, color: '#99000000' })
            }

            Column() {
              Text(this.currentSong?.name || '未知歌曲')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.playerText)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 26 })

              Text(this.currentSong?.artist || '未知歌手')
                .fontSize(15)
                .fontColor(this.playerMuted)
                .margin({ top: 8 })

              Text(this.currentSong?.album || '未知专辑')
                .fontSize(13)
                .fontColor(this.playerMuted)
                .opacity(0.75)
                .margin({ top: 5 })

              if (this.currentSong?.assetName) {
                Text('本地示例')
                  .fontSize(11)
                  .fontColor(this.playerAccent)
                  .backgroundColor('#33FF6B72')
                  .borderRadius(10)
                  .padding({ left: 9, right: 9, top: 3, bottom: 3 })
                  .margin({ top: 12 })
              } else if (this.currentSong?.filePath) {
                Text('本地音乐')
                  .fontSize(11)
                  .fontColor(this.playerAccent)
                  .backgroundColor('#33FF6B72')
                  .borderRadius(10)
                  .padding({ left: 9, right: 9, top: 3, bottom: 3 })
                  .margin({ top: 12 })
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .height('100%')
          .padding({ top: 10 })
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Center)

          // 歌词页
          LyricView()
            .width('100%')
            .height('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .loop(false)
        .indicator(false)
        .index(this.swiperIndex)
        .onChange((index: number) => {
          this.swiperIndex = index;
        })

        PlayerControls({
          playlistAction: (): void => {
            this.showPlaylist = true;
          }
        })
          .margin({ bottom: 24 })
      }
      .width('100%')
      .height('100%')

      if (this.showQualityDialog) {
        this.QualityDialog()
      }

      if (this.showPlaylist) {
        this.PlaylistDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.playerBg)
  }

  @Builder
  QualityDialog() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#B3000000')
        .onClick(() => {
          this.showQualityDialog = false;
        })

      Column() {
        Text('选择音质')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.playerText)
          .margin({ top: 20, bottom: 12 })

        ForEach(this.getQualityOptions(), (item: QualityOption) => {
          Row() {
            Column() {
              Text(item.label)
                .fontSize(16)
                .fontColor(this.currentQuality === item.quality ? this.playerAccent : this.playerText)
                .fontWeight(this.currentQuality === item.quality ? FontWeight.Bold : FontWeight.Medium)

              Text(item.desc)
                .fontSize(12)
                .fontColor(this.playerMuted)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            if (this.currentQuality === item.quality) {
              Text('✓')
                .fontSize(18)
                .fontColor(this.playerAccent)
                .fontWeight(FontWeight.Bold)
            }
          }
          .width('100%')
          .height(58)
          .padding({ left: 20, right: 20 })
          .onClick(() => {
            this.changeQuality(item.quality);
          })
        })

        Row()
          .width('100%')
          .height(28)
      }
      .width('100%')
      .backgroundColor(this.playerSurface)
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  PlaylistDialog() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#B3000000')
        .onClick(() => {
          this.showPlaylist = false;
        })

      Column() {
        Row() {
          Text('播放列表')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.playerText)
          Blank()
          Text(`${this.playerService.getPlaylist().length} 首`)
            .fontSize(13)
            .fontColor(this.playerMuted)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 12 })

        List({ space: 0 }) {
          ForEach(this.playerService.getPlaylist(), (item: Song, index: number) => {
            ListItem() {
              Row() {
                Column() {
                  Text(item.name)
                    .fontSize(15)
                    .fontColor(item.id === this.currentSong?.id ? this.playerAccent : this.playerText)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(item.artist || '未知')
                    .fontSize(12)
                    .fontColor(this.playerMuted)
                    .margin({ top: 2 })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (item.id === this.currentSong?.id) {
                  Text('♪')
                    .fontSize(16)
                    .fontColor(this.playerAccent)
                    .margin({ left: 8 })
                }
              }
              .width('100%')
              .padding({ left: 20, right: 20, top: 12, bottom: 12 })
              .onClick(() => {
                this.showPlaylist = false;
                if (!this.playerService.canPlay(item)) {
                  promptAction.showToast({
                    message: 'VIP/付费歌曲，演示环境无法在线播放',
                    duration: 2000
                  });
                  return;
                }
                this.playerService.playAt(index);
              })
            }
          })
        }
        .width('100%')
        .height('52%')
        .backgroundColor('#141419')
        .borderRadius({ topLeft: 12, topRight: 12 })

        Row()
          .width('100%')
          .height(28)
      }
      .width('100%')
      .borderRadius({ topLeft: 20, topRight: 20 })
      .backgroundColor(this.playerSurface)
    }
    .width('100%')
    .height('100%')
  }

  getQualityOptions(): QualityOption[] {
    const available: SongQualityInfo[] = this.playerService.getAvailableQualities();
    const allOptions: QualityOption[] = [
      { quality: AudioQuality.STANDARD, label: '标准', desc: '128kbps · 流畅播放' },
      { quality: AudioQuality.HIGHER, label: '较高', desc: '192kbps · 均衡之选' },
      { quality: AudioQuality.EXHIGH, label: '极高', desc: '320kbps · 高品质' },
      { quality: AudioQuality.LOSSLESS, label: '无损', desc: 'FLAC · 极致音质' },
    ];

    const availableLevels: Set<number> = new Set();
    for (const q of available) {
      availableLevels.add(q.level);
    }

    const result: QualityOption[] = [];
    for (const opt of allOptions) {
      const isAvailable: boolean = availableLevels.has(opt.quality);
      const qualityInfo: SongQualityInfo | undefined = available.find(
        (q: SongQualityInfo) => q.level === opt.quality
      );
      const sizeStr: string = qualityInfo && qualityInfo.size > 0
        ? ` · ${this.formatSize(qualityInfo.size)}`
        : '';
      const desc: string = isAvailable ? opt.desc + sizeStr : opt.desc + ' · 不可用';
      result.push({ quality: opt.quality, label: opt.label, desc: desc });
    }
    return result;
  }

  changeQuality(quality: AudioQuality) {
    this.currentQuality = quality;
    this.playerService.setQuality(quality);
    this.storageService.setAudioQuality(quality);
    this.showQualityDialog = false;
  }

  getQualityLabel(quality: AudioQuality): string {
    switch (quality) {
      case AudioQuality.STANDARD:
        return '标准';
      case AudioQuality.HIGHER:
        return '较高';
      case AudioQuality.EXHIGH:
        return '极高';
      case AudioQuality.LOSSLESS:
        return '无损';
      default:
        return '极高';
    }
  }

  formatSize(bytes: number): string {
    if (bytes <= 0) {
      return '';
    }
    const mb: number = bytes / 1024 / 1024;
    return mb.toFixed(1) + 'MB';
  }
}

interface QualityOption {
  quality: AudioQuality;
  label: string;
  desc: string;
}
