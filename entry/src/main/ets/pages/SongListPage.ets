/**
 * 文件：SongListPage.ets
 * 职责：歌单 / 专辑详情页，显示封面、名称、歌曲列表和全部播放 / 随机播放。
 *
 * 页面参数由 Index.openPlaylist 通过 router 传入：
 * playlistId、playlistName、coverUrl、isAlbum、artistName。
 * 专辑走 getAlbumDetail（搜索接口兜底），普通歌单走 getPlaylistDetail。
 */
import { ApiService } from '../services/ApiService';
import { PlayerService } from '../services/PlayerService';
import { thumbnail } from '../utils/ImageUtils';
import { Song, PlaylistDetail, PlayMode } from '../models/MusicModel';
import { SongItem } from '../components/SongItem';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
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
struct SongListPage {
  @StorageLink('bgPrimary') bgPrimary: string = '#F7F6F2';
  @StorageLink('bgSecondary') bgSecondary: string = '#FFFFFF';
  @StorageLink('textPrimary') textPrimary: string = '#17181A';
  @StorageLink('textTertiary') textTertiary: string = '#9A9EA5';
  @StorageLink('accent') accent: string = '#C8424C';
  @StorageLink('accentLight') accentLight: string = '#FDEBED';
  @StorageLink('bgImage') bgImage: string = '';
  @StorageLink('bgOpacity') bgOpacity: number = 0.15;
  @StorageLink('isDark') isDark: boolean = false;

  @State playlistName: string = '';
  @State playlistId: number = 0;
  @State coverUrl: string = '';
  @State isAlbum: boolean = false;
  @State artistName: string = '';
  @State songs: Song[] = [];
  @State isLoading: boolean = true;
  @State currentPlayingId: number = -1;
  @State customMaterialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;

  private apiService: ApiService = ApiService.getInstance();
  private playerService: PlayerService = PlayerService.getInstance();

  private songListener: ((song: Song | null) => void) | null = null;

  /**
   * 从路由参数还原歌单信息，注册播放歌曲监听，然后加载详情。
   */
  async aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.playlistName = params['playlistName'] as string || '';
      this.playlistId = params['playlistId'] as number || 0;
      this.coverUrl = params['coverUrl'] as string || '';
      this.isAlbum = params['isAlbum'] === true;
      this.artistName = params['artistName'] as string || '';
    }

    const materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
    if (materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0) {
      this.customMaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;
    }

    this.currentPlayingId = this.playerService.getCurrentSong()?.id ?? -1;
    this.songListener = (song: Song | null) => {
      this.currentPlayingId = song ? song.id : -1;
    };
    this.playerService.addSongChangeListener(this.songListener);

    await this.loadPlaylistDetail();
  }

  aboutToDisappear() {
    if (this.songListener) {
      this.playerService.removeSongChangeListener(this.songListener);
    }
  }

  /**
   * 加载详情：
   * 专辑和普通歌单走不同接口；请求失败保留空态并提示，不把异常抛到 UI。
   */
  async loadPlaylistDetail() {
    this.isLoading = true;
    try {
      let detail: PlaylistDetail | null = null;
      if (this.isAlbum) {
        detail = await this.apiService.getAlbumDetail(this.playlistId, this.playlistName, this.artistName, this.coverUrl);
      } else {
        detail = await this.apiService.getPlaylistDetail(this.playlistId);
      }
      if (detail && detail.songs.length > 0) {
        this.songs = detail.songs;
        if (detail.info.coverUrl) {
          this.coverUrl = detail.info.coverUrl;
        }
        if (detail.info.name) {
          this.playlistName = detail.info.name;
        }
      } else {
        promptAction.showToast({ message: '暂时无法加载，请重试', duration: 2000 });
      }
    } catch (e) {
      console.error('Load detail error:', e);
      promptAction.showToast({ message: '网络异常，请检查网络后重试', duration: 2000 });
    }
    this.isLoading = false;
  }

  /**
   * 点击单曲播放：不可播放的 VIP/付费歌曲在入口处拦截，
   * 可播放时把整个歌单作为播放队列，再进入播放页。
   */
  playSong(song: Song, index: number) {
    if (!this.playerService.canPlay(song)) {
      promptAction.showToast({
        message: 'VIP/付费歌曲，演示环境无法在线播放；可换免费歌曲',
        duration: 2500
      });
      return;
    }
    this.playerService.setPlaylist(this.songs, index);
    this.playerService.playSong(song);
    router.pushUrl({ url: 'pages/PlayPage' });
  }

  /**
   * 全部播放 / 随机播放。
   * 先筛出可播放歌曲；一首都没有时提示，避免进入播放页后空转。
   */
  playAll(random: boolean) {
    if (this.songs.length === 0) {
      return;
    }
    const playableIndices: number[] = [];
    for (let i = 0; i < this.songs.length; i++) {
      if (this.playerService.canPlay(this.songs[i])) {
        playableIndices.push(i);
      }
    }
    if (playableIndices.length === 0) {
      promptAction.showToast({ message: '该歌单没有可在线播放的歌曲', duration: 2500 });
      return;
    }
    const index: number = random
      ? playableIndices[Math.floor(Math.random() * playableIndices.length)]
      : playableIndices[0];
    this.playerService.setPlayMode(random ? PlayMode.RANDOM : PlayMode.SEQUENCE);
    this.playerService.setPlaylist(this.songs, index);
    this.playerService.playSong(this.songs[index]);
    router.pushUrl({ url: 'pages/PlayPage' });
  }

  @Builder
  PlaylistHeader() {
    Column() {
      Row() {
        Image(thumbnail(this.coverUrl, 320, 320))
          .width(160)
          .height(160)
          .borderRadius(16)
          .objectFit(ImageFit.Cover)
          .backgroundColor(this.accentLight)

        Column() {
          Text(this.playlistName)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textPrimary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.songs.length} 首歌曲`)
            .fontSize(12)
            .fontColor(this.textTertiary)
            .margin({ top: 6 })
          if (this.artistName) {
            Text(this.artistName)
              .fontSize(12)
              .fontColor(this.textTertiary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 4 })
          }
        }
        .layoutWeight(1)
        .margin({ left: 14 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Row({ space: 12 }) {
        Button() {
          Row() {
            SymbolGlyph($r('sys.symbol.play_fill'))
              .fontSize(16)
              .fontColor(['#FFFFFF'])
            Text('全部播放')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .margin({ left: 6 })
          }
        }
        .layoutWeight(1)
        .height(44)
        .backgroundColor(this.accent)
        .borderRadius(22)
        .onClick(() => {
          this.playAll(false);
        })

        Button() {
          Row() {
            SymbolGlyph($r('sys.symbol.shuffle'))
              .fontSize(16)
              .fontColor([this.accent])
            Text('随机播放')
              .fontSize(14)
              .fontColor(this.accent)
              .margin({ left: 6 })
          }
        }
        .layoutWeight(1)
        .height(44)
        .backgroundColor(this.accentLight)
        .borderRadius(22)
        .onClick(() => {
          this.playAll(true);
        })
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.bgImage ? '#00000000' : this.bgSecondary)
    .borderRadius(20)
  }

  build() {
    Stack() {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor(this.bgPrimary)

      if (this.bgImage) {
        Image(this.bgImage)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.isDark ? '#000000' : '#F7F6F2')
          .opacity(this.bgOpacity)
      }

      HdsNavigation() {
        Column() {
          Row()
            .height(110)
            .width('100%')

          if (this.isLoading) {
            Column() {
              LoadingProgress()
                .width(36)
                .height(36)
                .color(this.accent)
              Text('加载歌曲列表中…')
                .fontSize(13)
                .fontColor(this.textTertiary)
                .margin({ top: 10 })
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else if (this.songs.length === 0) {
            Column() {
              Text('该歌单暂无歌曲')
                .fontSize(15)
                .fontColor(this.textPrimary)
              Button('重新加载')
                .height(38)
                .fontSize(14)
                .fontColor('#FFFFFF')
                .backgroundColor(this.accent)
                .borderRadius(19)
                .margin({ top: 14 })
                .onClick(() => {
                  this.loadPlaylistDetail();
                })
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else {
            Column() {
              this.PlaylistHeader()

              List() {
                ForEach(this.songs, (song: Song, index: number) => {
                  ListItem() {
                    SongItem({
                      song: song,
                      index: index,
                      isActive: song.id === this.currentPlayingId,
                      onItemClick: (clickedSong: Song, clickedIndex: number) => {
                        this.playSong(clickedSong, clickedIndex);
                      }
                    })
                  }
                })
                ListItem() {
                  Row().width('100%').height(120)
                }
              }
              .width('100%')
              .layoutWeight(1)
              .margin({ top: 12 })
              .backgroundColor(this.bgImage ? '#00000000' : this.bgSecondary)
              .borderRadius(20)
              .clip(true)
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ left: 20, right: 20 })
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
      }
      .titleBar({
        avoidLayoutSafeArea: true,
        content: {
          title: { mainTitle: '歌单' }
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
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
