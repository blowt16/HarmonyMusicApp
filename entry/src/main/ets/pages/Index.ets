import { ApiService } from '../services/ApiService';
import { PlayerService } from '../services/PlayerService';
import { StorageService } from '../services/StorageService';
import { AuthService } from '../services/AuthService';
import { AudioSessionService } from '../services/AudioSessionService';
import { WidgetService } from '../services/WidgetService';
import { LOCAL_DEMO_SONG, LOCAL_FALLBACK_SONGS } from '../services/MockData';
import { thumbnail } from '../utils/ImageUtils';
import { Song, AudioQuality, PlaylistInfo, EffectLevel, PlayerState } from '../models/MusicModel';
import { FavoritesView } from './views/FavoritesView';
import { ProfileView } from './views/ProfileView';
import router from '@ohos.router';
import { common, Want } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  hdsMaterial,
  HdsBarStyle,
  HdsTabsFloatingStyle,
  ScrollEffectType,
  BlurStrategy
} from '@kit.UIDesignKit';
import { SymbolGlyphModifier, LengthMetrics } from '@kit.ArkUI';

const TAB_SELECTED_COLOR: string = '#C8424C';
const TAB_UNSELECTED_COLOR: string = '#6B6F76';

interface TabItem {
  symbolGlyph: SymbolGlyphModifier;
  symbolGlyph1: SymbolGlyphModifier;
  label: string;
}

const TAB_CONFIG: TabItem[] = [
  {
    symbolGlyph: new SymbolGlyphModifier($r('sys.symbol.house')).fontColor([TAB_UNSELECTED_COLOR]),
    symbolGlyph1: new SymbolGlyphModifier($r('sys.symbol.house_fill')).fontColor([TAB_SELECTED_COLOR]),
    label: '首页'
  },
  {
    symbolGlyph: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass')).fontColor([TAB_UNSELECTED_COLOR]),
    symbolGlyph1: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass')).fontColor([TAB_SELECTED_COLOR]),
    label: '搜索'
  },
  {
    symbolGlyph: new SymbolGlyphModifier($r('sys.symbol.heart')).fontColor([TAB_UNSELECTED_COLOR]),
    symbolGlyph1: new SymbolGlyphModifier($r('sys.symbol.heart_fill')).fontColor([TAB_SELECTED_COLOR]),
    label: '收藏'
  },
  {
    symbolGlyph: new SymbolGlyphModifier($r('sys.symbol.person')).fontColor([TAB_UNSELECTED_COLOR]),
    symbolGlyph1: new SymbolGlyphModifier($r('sys.symbol.person_fill')).fontColor([TAB_SELECTED_COLOR]),
    label: '我的'
  }
];

@Entry
@Component
struct Index {
  @StorageLink('bgPrimary') bgPrimary: string = '#F7F6F2';
  @StorageLink('bgSecondary') bgSecondary: string = '#FFFFFF';
  @StorageLink('textPrimary') textPrimary: string = '#17181A';
  @StorageLink('textSecondary') textSecondary: string = '#6B6F76';
  @StorageLink('textTertiary') textTertiary: string = '#9A9EA5';
  @StorageLink('accent') accent: string = '#C8424C';
  @StorageLink('accentLight') accentLight: string = '#FDEBED';
  @StorageLink('border') themeBorder: string = '#ECE8E0';
  @StorageLink('isDark') isDark: boolean = false;
  @StorageLink('bgImage') bgImage: string = '';
  @StorageLink('bgOpacity') bgOpacity: number = 0.15;
  @StorageLink('effectLevel') effectLevel: number = EffectLevel.MEDIUM;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  @State currentTabIndex: number = 0;

  // 首页
  @State featured: PlaylistInfo | null = null;
  @State recommendPlaylists: PlaylistInfo[] = [];
  @State hotPlaylists: PlaylistInfo[] = [];
  @State isLoadingHome: boolean = true;
  @State homeError: boolean = false;

  // 收藏 / 最近播放
  @State favorites: Song[] = [];
  @State history: Song[] = [];
  @State nickname: string = 'demo';

  // 搜索
  @State searchKeyword: string = '';
  @State searchResults: Song[] = [];
  @State onlyPlayable: boolean = false;
  @State searchLoading: boolean = false;
  @State searchPage: number = 1;
  @State searchTotal: number = 0;
  @State searchError: boolean = false;
  @State loadMoreFailed: boolean = false;
  @State showHistory: boolean = true;
  @State searchHistory: string[] = [];
  @State currentPlayingId: number = -1;

  // MiniPlayer
  @State miniCurrentSong: Song | null = null;
  @State miniPlayerState: PlayerState = PlayerState.STOPPED;
  @State miniSupportsImmersive: boolean = false;
  @State miniBarExpanded: boolean = false;

  private apiService: ApiService = ApiService.getInstance();
  private playerService: PlayerService = PlayerService.getInstance();
  private storageService: StorageService = StorageService.getInstance();
  private authService: AuthService = AuthService.getInstance();
  private audioSessionService: AudioSessionService = AudioSessionService.getInstance();
  private tabsController: HdsTabsController = new HdsTabsController();
  private customMaterialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;

  private songListener: ((song: Song | null) => void) | null = null;
  private miniStateListener: ((state: PlayerState) => void) | null = null;
  private errorListener: ((message: string) => void) | null = null;
  private isLoggingOut: boolean = false;

  async aboutToAppear() {
    this.storageService.setContext(getContext(this));
    this.authService.setContext(getContext(this));
    const savedNickname: string = await this.authService.getNickname();
    if (savedNickname) {
      this.nickname = savedNickname;
    }

    const savedQuality: AudioQuality = await this.storageService.getAudioQuality();
    this.playerService.setQuality(savedQuality);

    const materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
    this.miniSupportsImmersive = materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0;
    this.customMaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;

    this.songListener = (song: Song | null) => {
      this.miniCurrentSong = song;
      if (song) {
        this.currentPlayingId = song.id;
      }
    };
    this.playerService.addSongChangeListener(this.songListener);

    this.miniCurrentSong = this.playerService.getCurrentSong();
    this.miniPlayerState = this.playerService.getPlayerState();
    if (this.miniCurrentSong) {
      this.currentPlayingId = this.miniCurrentSong.id;
    }

    this.miniStateListener = (state: PlayerState) => {
      this.miniPlayerState = state;
    };
    this.playerService.addStateChangeListener(this.miniStateListener);

    // 列表页发起播放时 PlayPage 可能尚未挂载，错误提示统一由常驻的 Index 监听
    this.errorListener = (message: string) => {
      promptAction.showToast({ message, duration: 2000 });
    };
    this.playerService.addErrorListener(this.errorListener);

    await this.refreshLibrary();
    await this.loadSearchHistory();
    await this.loadHome();
  }

  aboutToDisappear() {
    if (this.songListener) {
      this.playerService.removeSongChangeListener(this.songListener);
    }
    if (this.miniStateListener) {
      this.playerService.removeStateChangeListener(this.miniStateListener);
    }
    if (this.errorListener) {
      this.playerService.removeErrorListener(this.errorListener);
    }
  }

  onPageShow() {
    this.refreshLibrary();
    WidgetService.refreshAll();
  }

  async refreshLibrary() {
    this.favorites = await this.storageService.getFavorites();
    this.history = await this.storageService.getPlayHistory();
  }

  async loadSearchHistory() {
    this.searchHistory = await this.storageService.getSearchHistory();
  }

  async loadHome() {
    this.isLoadingHome = true;
    this.homeError = false;
    try {
      const albums: PlaylistInfo[] = await this.apiService.getNewAlbums(8);
      const tops: PlaylistInfo[] = await this.apiService.getTopPlaylists('全部', 8);
      this.recommendPlaylists = albums;
      this.hotPlaylists = tops;
      if (albums.length > 0) {
        this.featured = albums[0];
      } else if (tops.length > 0) {
        this.featured = tops[0];
      } else {
        this.featured = null;
        this.homeError = true;
      }
    } catch (e) {
      console.error('Load home error:', e);
      this.homeError = true;
    }
    this.isLoadingHome = false;
  }

  greeting(): string {
    const hour: number = new Date().getHours();
    if (hour < 6) {
      return '夜深了';
    }
    if (hour < 12) {
      return '早上好';
    }
    if (hour < 18) {
      return '下午好';
    }
    return '晚上好';
  }

  formatPlayCount(count: number): string {
    if (count >= 100000000) {
      return (count / 100000000).toFixed(1) + '亿';
    }
    if (count >= 10000) {
      return (count / 10000).toFixed(1) + '万';
    }
    return count.toString();
  }

  openPlaylist(playlist: PlaylistInfo) {
    router.pushUrl({
      url: 'pages/SongListPage',
      params: {
        playlistName: playlist.name,
        playlistId: playlist.id,
        coverUrl: playlist.coverUrl,
        isAlbum: playlist.isAlbum === true,
        artistName: playlist.creator || ''
      }
    });
  }

  visibleSearchResults(): Song[] {
    if (!this.onlyPlayable) {
      return this.searchResults;
    }
    return this.searchResults.filter((song: Song) => this.playerService.canPlay(song));
  }

  async playSongsAt(songs: Song[], index: number) {
    if (index < 0 || index >= songs.length) {
      return;
    }
    if (!this.playerService.canPlay(songs[index])) {
      promptAction.showToast({
        message: 'VIP/付费歌曲，演示环境无法在线播放；可换免费歌曲或导入本地音乐',
        duration: 2500
      });
      return;
    }
    this.playerService.setPlaylist(songs, index);
    await this.playerService.playSong(songs[index]);
    router.pushUrl({ url: 'pages/PlayPage' });
  }

  async playSearchResult(song: Song, index: number) {
    this.playSongsAt(this.visibleSearchResults(), index);
  }

  async playHistorySong(song: Song, songs: Song[], index: number) {
    if (!this.playerService.canPlay(song)) {
      promptAction.showToast({
        message: 'VIP/付费歌曲，演示环境无法在线播放；可换免费歌曲或导入本地音乐',
        duration: 2500
      });
      return;
    }
    this.playerService.setPlaylist(songs, index);
    await this.playerService.playSong(song);
    router.pushUrl({ url: 'pages/PlayPage' });
  }

  async clearHistory() {
    await this.storageService.clearPlayHistory();
    await this.refreshLibrary();
    WidgetService.refreshAll();
    promptAction.showToast({ message: '已清空最近播放', duration: 1500 });
  }

  async runSearch() {
    const keyword: string = this.searchKeyword.trim();
    if (!keyword) {
      return;
    }
    this.searchLoading = true;
    this.searchError = false;
    this.loadMoreFailed = false;
    this.showHistory = false;
    this.searchPage = 1;

    await this.storageService.addSearchHistory(keyword);
    await this.loadSearchHistory();

    const result = await this.apiService.searchMusic(keyword, 1);
    if (result.error === true) {
      this.searchError = true;
      this.searchResults = [];
      this.searchTotal = 0;
    } else {
      this.searchResults = result.songs;
      this.searchTotal = result.total;
    }
    this.searchLoading = false;
  }

  async loadMore() {
    if (this.searchLoading || this.searchResults.length >= this.searchTotal) {
      return;
    }
    this.searchLoading = true;
    const nextPage: number = this.searchPage + 1;
    const result = await this.apiService.searchMusic(this.searchKeyword.trim(), nextPage);
    if (result.error === true) {
      this.loadMoreFailed = true;
    } else {
      this.searchPage = nextPage;
      this.searchResults = this.searchResults.concat(result.songs);
      this.searchTotal = result.total;
      this.loadMoreFailed = false;
    }
    this.searchLoading = false;
  }

  async clearSearchHistory() {
    await this.storageService.clearSearchHistory();
    this.searchHistory = [];
  }

  selectHistory(keyword: string) {
    this.searchKeyword = keyword;
    this.runSearch();
  }

  getMiniBlurScale(): number {
    if (!this.miniSupportsImmersive) {
      return 0.3;
    }
    switch (this.effectLevel) {
      case EffectLevel.OFF:
        return 0;
      case EffectLevel.LOW:
        return 0.3;
      case EffectLevel.MEDIUM:
        return 0.6;
      case EffectLevel.HIGH:
        return 1.0;
      default:
        return 0.6;
    }
  }

  getMiniOverlayOpacity(): number {
    if (!this.miniSupportsImmersive) {
      return 0.12;
    }
    switch (this.effectLevel) {
      case EffectLevel.OFF:
        return 0;
      case EffectLevel.LOW:
        return 0.12;
      case EffectLevel.MEDIUM:
        return 0.25;
      case EffectLevel.HIGH:
        return 0.4;
      default:
        return 0.25;
    }
  }

  openSettings() {
    router.pushUrl({ url: 'pages/SettingsPage' });
  }

  async handleLogout() {
    if (this.isLoggingOut) {
      return;
    }
    this.isLoggingOut = true;
    const context = getContext(this) as common.UIAbilityContext;
    try {
      this.playerService.stop();
      await this.playerService.release();
      this.playerService.reset();
      await this.audioSessionService.destroy();
      await this.authService.logout();

      const want: Want = {
        bundleName: context.applicationInfo.name,
        abilityName: 'EntryAbility',
        parameters: { showLogin: true }
      };
      await context.startAbility(want);
      setTimeout(() => {
        context.terminateSelf();
      }, 800);
    } catch (e) {
      console.error('Logout error:', e);
      this.isLoggingOut = false;
      promptAction.showToast({ message: '退出登录失败，请重试', duration: 1500 });
    }
  }

  getBarFloatingStyle(): HdsTabsFloatingStyle {
    const style: HdsTabsFloatingStyle = {
      barBottomMargin: 24,
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: this.customMaterialLevel
      }
    };
    if (this.miniCurrentSong) {
      style.miniBar = {
        miniBarBuilder: (): void => this.MiniBarBuilder(),
        onBarStyleChange: (miniBarStyle: HdsBarStyle): void => {
          this.miniBarExpanded = miniBarStyle === HdsBarStyle.EXPAND;
        }
      };
    }
    return style;
  }

  @Builder
  MiniBarBuilder() {
    if (this.miniCurrentSong) {
      if (this.miniBarExpanded) {
        Row() {
          Image(thumbnail(this.miniCurrentSong.coverUrl, 100, 100))
            .width(46)
            .height(46)
            .borderRadius(23)
            .objectFit(ImageFit.Cover)
            .backgroundColor(this.accentLight)

          Column() {
            Text(this.miniCurrentSong.name || '未知歌曲')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.textPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.miniCurrentSong.artist || '未知歌手')
              .fontSize(12)
              .fontColor(this.textTertiary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {
            router.pushUrl({ url: 'pages/PlayPage' });
          })

          Button() {
            if (this.miniPlayerState === PlayerState.PLAYING) {
              SymbolGlyph($r('sys.symbol.pause_fill'))
                .fontSize(20)
                .fontColor([this.textPrimary])
            } else {
              SymbolGlyph($r('sys.symbol.play_fill'))
                .fontSize(20)
                .fontColor([this.textPrimary])
            }
          }
          .width(44)
          .height(44)
          .backgroundColor('transparent')
          .onClick(() => {
            if (this.miniPlayerState === PlayerState.PLAYING) {
              this.playerService.pause();
            } else {
              this.playerService.play();
            }
          })
        }
        .width('100%')
        .height(60)
        .padding({ left: 12, right: 4 })
        .alignItems(VerticalAlign.Center)
      } else {
        Row() {
          Image(thumbnail(this.miniCurrentSong.coverUrl, 100, 100))
            .width(46)
            .height(46)
            .borderRadius(23)
            .objectFit(ImageFit.Cover)
            .backgroundColor(this.accentLight)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          router.pushUrl({ url: 'pages/PlayPage' });
        })
      }
    }
  }

  @Builder
  SearchPill() {
    Row() {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(18)
        .fontColor([this.textTertiary])
      Text('搜索歌曲、歌手、专辑')
        .fontSize(14)
        .fontColor(this.textTertiary)
        .layoutWeight(1)
        .margin({ left: 8 })
    }
    .width('100%')
    .height(46)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.bgSecondary)
    .borderRadius(23)
    .onClick(() => {
      this.tabsController.changeIndex(1);
    })
  }

  @Builder
  SectionTitle(title: string) {
    Row() {
      Text(title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.textPrimary)
      Blank()
    }
    .width('100%')
    .padding({ top: 26, bottom: 12 })
  }

  @Builder
  FeaturedCard() {
    if (this.featured) {
      Stack({ alignContent: Alignment.BottomStart }) {
        Image(thumbnail(this.featured.coverUrl, 800, 450))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .backgroundColor(this.accentLight)

        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 180,
            colors: [['#00000000', 0.0], ['#B30B0C10', 0.62], ['#E60B0C10', 1.0]]
          })

        Row() {
          Column() {
            Text('精选推荐')
              .fontSize(11)
              .fontColor('#FFD7D9')
            Text(this.featured.name)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 4 })
            Text(this.featured.isAlbum ? (this.featured.creator || '清听精选') : `${this.featured.songCount} 首`)
              .fontSize(12)
              .fontColor('#E8E3DE')
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button() {
            SymbolGlyph($r('sys.symbol.play_fill'))
              .fontSize(24)
              .fontColor(['#FFFFFF'])
          }
          .width(50)
          .height(50)
          .borderRadius(25)
          .backgroundColor(this.accent)
          .onClick(() => {
            if (this.featured) {
              this.openPlaylist(this.featured);
            }
          })
        }
        .width('100%')
        .padding(18)
        .alignItems(VerticalAlign.Bottom)
      }
      .width('100%')
      .aspectRatio(16 / 9)
      .borderRadius(20)
      .clip(true)
      .onClick(() => {
        if (this.featured) {
          this.openPlaylist(this.featured);
        }
      })
    }
  }

  @Builder
  PlaylistCard(playlist: PlaylistInfo) {
    Column() {
      Image(thumbnail(playlist.coverUrl, 300, 300))
        .width(150)
        .height(150)
        .borderRadius(14)
        .objectFit(ImageFit.Cover)
        .backgroundColor(this.accentLight)

      Text(playlist.name)
        .fontSize(14)
        .fontColor(this.textPrimary)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 8 })

      Text(playlist.isAlbum ? (playlist.creator || '专辑') :
        `${playlist.songCount} 首${playlist.playCount > 0 ? ' · ' + this.formatPlayCount(playlist.playCount) : ''}`)
        .fontSize(12)
        .fontColor(this.textTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 3 })
    }
    .width(150)
    .margin({ right: 14 })
    .onClick(() => {
      this.openPlaylist(playlist);
    })
  }

  @Builder
  SongCard(song: Song, songs: Song[], index: number) {
    Column() {
      if (song.coverUrl) {
        Image(thumbnail(song.coverUrl, 300, 300))
          .width(140)
          .height(140)
          .borderRadius(14)
          .objectFit(ImageFit.Cover)
          .backgroundColor(this.accentLight)
      } else {
        Stack() {
          Text('♪')
            .fontSize(46)
            .fontColor(this.accent)
        }
        .width(140)
        .height(140)
        .borderRadius(14)
        .backgroundColor(this.accentLight)
      }

      Text(song.name)
        .fontSize(14)
        .fontColor(song.id === this.currentPlayingId ? this.accent : this.textPrimary)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 8 })

      Text(song.artist)
        .fontSize(12)
        .fontColor(this.textTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 3 })
    }
    .width(140)
    .margin({ right: 14 })
    .onClick(() => {
      this.playSongsAt(songs, index);
    })
  }

  @Builder
  HomeLoadingCard() {
    Row() {
      LoadingProgress()
        .width(22)
        .height(22)
        .color(this.accent)
      Text('正在加载推荐…')
        .fontSize(13)
        .fontColor(this.textSecondary)
        .margin({ left: 10 })
    }
    .width('100%')
    .height(64)
    .padding({ left: 18, right: 18 })
    .backgroundColor(this.bgSecondary)
    .borderRadius(16)
  }

  @Builder
  HomeErrorCard() {
    Column() {
      Text('网络暂时不可用')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textPrimary)
      Text('当前展示本地精选，检查网络后可重新加载在线推荐')
        .fontSize(12)
        .fontColor(this.textTertiary)
        .margin({ top: 6 })
      Button('重新加载')
        .height(38)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(this.accent)
        .borderRadius(19)
        .margin({ top: 14 })
        .onClick(() => {
          this.loadHome();
        })
    }
    .width('100%')
    .padding({ top: 22, bottom: 22 })
    .backgroundColor(this.bgSecondary)
    .borderRadius(20)
  }

  @Builder
  HomeTab() {
    Column() {
      Row()
        .height(80)
        .width('100%')

      Scroll() {
        Column() {
          Column() {
            Text(this.greeting())
              .fontSize(13)
              .fontColor(this.textSecondary)
            Text('听见每一天')
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textPrimary)
              .margin({ top: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: 4, bottom: 16 })

          this.SearchPill()

          Column() {
            if (this.isLoadingHome && this.featured === null) {
              this.HomeLoadingCard()
            } else if (this.homeError) {
              this.HomeErrorCard()
            } else {
              this.FeaturedCard()
            }
          }
          .margin({ top: 18 })

          this.SectionTitle('本地精选')
          List() {
            ForEach(LOCAL_FALLBACK_SONGS, (song: Song, index: number) => {
              ListItem() {
                this.SongCard(song, LOCAL_FALLBACK_SONGS, index)
              }
            })
          }
          .listDirection(Axis.Horizontal)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .width('100%')
          .height(200)

          if (this.history.length > 0) {
            this.SectionTitle('最近播放')
            List() {
              ForEach(this.history.slice(0, 10), (song: Song, index: number) => {
                ListItem() {
                  this.SongCard(song, this.history, index)
                }
              })
            }
            .listDirection(Axis.Horizontal)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .width('100%')
            .height(200)
          }

          if (this.recommendPlaylists.length > 0) {
            this.SectionTitle('为你推荐')
            List() {
              ForEach(this.recommendPlaylists, (playlist: PlaylistInfo) => {
                ListItem() {
                  this.PlaylistCard(playlist)
                }
              })
            }
            .listDirection(Axis.Horizontal)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .width('100%')
            .height(210)
          }

          if (this.hotPlaylists.length > 0) {
            this.SectionTitle('精选歌单')
            List() {
              ForEach(this.hotPlaylists, (playlist: PlaylistInfo) => {
                ListItem() {
                  this.PlaylistCard(playlist)
                }
              })
            }
            .listDirection(Axis.Horizontal)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .width('100%')
            .height(210)
          }

          Blank()
            .height(120)
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgPrimary)
  }

  @Builder
  SearchTab() {
    Column() {
      Row()
        .height(110)
        .width('100%')

      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(18)
            .fontColor([this.textTertiary])
          TextInput({ placeholder: '搜索歌曲、歌手、专辑', text: this.searchKeyword })
            .layoutWeight(1)
            .height(48)
            .fontSize(14)
            .fontColor(this.textPrimary)
            .placeholderColor(this.textTertiary)
            .backgroundColor(Color.Transparent)
            .padding({ left: 8, right: 8 })
            .onChange((value: string) => {
              this.searchKeyword = value;
              if (value === '') {
                this.showHistory = true;
                this.searchResults = [];
                this.searchError = false;
                this.searchTotal = 0;
              }
            })
            .onSubmit(() => {
              this.runSearch();
            })
        }
        .layoutWeight(1)
        .height(48)
        .padding({ left: 14, right: 6 })
        .backgroundColor(this.bgSecondary)
        .borderRadius(24)

        Button('搜索')
          .height(48)
          .width(70)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(this.accent)
          .borderRadius(24)
          .margin({ left: 10 })
          .enabled(!this.searchLoading)
          .opacity(this.searchLoading ? 0.6 : 1)
          .onClick(() => {
            this.runSearch();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 12 })

      Column() {
        if (this.showHistory && this.searchHistory.length > 0 && this.searchResults.length === 0) {
          Row() {
            Text('搜索历史')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textPrimary)
            Blank()
            Text('清空')
              .fontSize(12)
              .fontColor(this.textTertiary)
              .height(32)
              .padding({ left: 8, right: 8 })
              .onClick(() => {
                this.clearSearchHistory();
              })
          }
          .width('100%')
          .padding({ top: 8, bottom: 12 })

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.searchHistory, (keyword: string) => {
              Text(keyword)
                .fontSize(13)
                .fontColor(this.textPrimary)
                .height(34)
                .padding({ left: 14, right: 14 })
                .backgroundColor(this.bgSecondary)
                .borderRadius(17)
                .margin({ right: 8, bottom: 8 })
                .onClick(() => {
                  this.selectHistory(keyword);
                })
            })
          }
          .width('100%')
        }

        if (this.searchLoading && this.searchResults.length === 0) {
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
              .color(this.accent)
            Text('搜索中…')
              .fontSize(13)
              .fontColor(this.textTertiary)
              .margin({ top: 10 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.searchError) {
          Column() {
            Text('网络连接失败')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.textPrimary)
            Text('请检查网络后重试')
              .fontSize(12)
              .fontColor(this.textTertiary)
              .margin({ top: 6 })
            Button('重试')
              .height(38)
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor(this.accent)
              .borderRadius(19)
              .margin({ top: 14 })
              .onClick(() => {
                this.runSearch();
              })

            Button('播放本地示例')
              .height(38)
              .fontSize(14)
              .fontColor(this.accent)
              .backgroundColor(this.accentLight)
              .borderRadius(19)
              .margin({ top: 10 })
              .onClick(() => {
                this.playSongsAt(LOCAL_FALLBACK_SONGS, 0);
              })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.onlyPlayable && this.searchResults.length > 0 &&
          this.visibleSearchResults().length === 0) {
          Column() {
            Text('当前结果都不可在线播放')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.textPrimary)
            Text('这些歌曲多为 VIP/付费或暂无版权；可以关闭筛选，或导入本地音乐。')
              .fontSize(12)
              .fontColor(this.textTertiary)
              .margin({ top: 6 })
              .textAlign(TextAlign.Center)
            Button('关闭筛选')
              .height(38)
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor(this.accent)
              .borderRadius(19)
              .margin({ top: 14 })
              .onClick(() => {
                this.onlyPlayable = false;
              })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.searchResults.length > 0) {
          Row() {
            Text(`找到 ${this.searchTotal} 首歌曲`)
              .fontSize(13)
              .fontColor(this.textTertiary)
            Blank()
            Text(this.onlyPlayable ? '只看可播放 ✓' : '只看可播放')
              .fontSize(12)
              .fontColor(this.onlyPlayable ? this.accent : this.textTertiary)
              .backgroundColor(this.onlyPlayable ? this.accentLight : this.bgSecondary)
              .borderRadius(12)
              .height(28)
              .padding({ left: 10, right: 10 })
              .onClick(() => {
                this.onlyPlayable = !this.onlyPlayable;
              })
          }
          .width('100%')
          .padding({ top: 4, bottom: 8 })

          List() {
            ForEach(this.visibleSearchResults(), (song: Song, index: number) => {
              ListItem() {
                Row() {
                  Image(thumbnail(song.coverUrl, 120, 120))
                    .width(48)
                    .height(48)
                    .borderRadius(10)
                    .objectFit(ImageFit.Cover)
                    .backgroundColor(this.accentLight)
                    .margin({ right: 12 })

                  Column() {
                    Text(song.name)
                      .fontSize(15)
                      .fontColor(song.id === this.currentPlayingId ? this.accent : this.textPrimary)
                      .fontWeight(song.id === this.currentPlayingId ? FontWeight.Bold : FontWeight.Medium)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`${song.artist} · ${song.album}`)
                      .fontSize(12)
                      .fontColor(this.textTertiary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ top: 3 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  if (song.playable === false) {
                    Text(song.fee === 4 ? '付费' : 'VIP')
                      .fontSize(10)
                      .fontColor(this.accent)
                      .backgroundColor(this.accentLight)
                      .borderRadius(8)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .margin({ left: 8 })
                  }
                }
                .width('100%')
                .height(64)
                .padding({ left: 14, right: 14 })
                .backgroundColor(this.bgSecondary)
                .onClick(() => {
                  this.playSearchResult(song, index);
                })
              }
            })

            if (this.searchLoading) {
              ListItem() {
                Row() {
                  LoadingProgress()
                    .width(22)
                    .height(22)
                    .color(this.accent)
                  Text('加载中…')
                    .fontSize(13)
                    .fontColor(this.textTertiary)
                    .margin({ left: 8 })
                }
                .width('100%')
                .height(50)
                .justifyContent(FlexAlign.Center)
              }
            } else if (this.loadMoreFailed) {
              ListItem() {
                Text('加载失败，点击重试')
                  .fontSize(13)
                  .fontColor(this.accent)
                  .width('100%')
                  .height(50)
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    this.loadMore();
                  })
              }
            } else if (this.searchResults.length < this.searchTotal) {
              ListItem() {
                Text('加载更多')
                  .fontSize(13)
                  .fontColor(this.accent)
                  .width('100%')
                  .height(50)
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    this.loadMore();
                  })
              }
            }

            ListItem() {
              Row().width('100%').height(120)
            }
          }
          .width('100%')
          .layoutWeight(1)
          .borderRadius(20)
          .clip(true)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        } else if (!this.showHistory) {
          Column() {
            Text('没有找到相关歌曲')
              .fontSize(15)
              .fontColor(this.textPrimary)
            Text('换一个关键词试试')
              .fontSize(12)
              .fontColor(this.textTertiary)
              .margin({ top: 6 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Column() {
            Text('输入关键词开始搜索')
              .fontSize(15)
              .fontColor(this.textPrimary)
            Text('也可以先看看首页的精选推荐')
              .fontSize(12)
              .fontColor(this.textTertiary)
              .margin({ top: 6 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
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

  build() {
    Stack() {
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
        HdsTabs({ controller: this.tabsController }) {
          TabContent() {
            this.HomeTab()
          }
          .tabBar(new BottomTabBarStyle({
            normal: TAB_CONFIG[0].symbolGlyph,
            selected: TAB_CONFIG[0].symbolGlyph1
          }, TAB_CONFIG[0].label).labelStyle({
            selectedColor: TAB_SELECTED_COLOR,
            unselectedColor: TAB_UNSELECTED_COLOR,
            font: { size: 12, weight: FontWeight.Medium }
          }))

          TabContent() {
            this.SearchTab()
          }
          .tabBar(new BottomTabBarStyle({
            normal: TAB_CONFIG[1].symbolGlyph,
            selected: TAB_CONFIG[1].symbolGlyph1
          }, TAB_CONFIG[1].label).labelStyle({
            selectedColor: TAB_SELECTED_COLOR,
            unselectedColor: TAB_UNSELECTED_COLOR,
            font: { size: 12, weight: FontWeight.Medium }
          }))

          TabContent() {
            FavoritesView({
              favorites: this.favorites,
              history: this.history,
              currentPlayingId: this.currentPlayingId,
              onPlaySong: (song: Song, songs: Song[], index: number): void => {
                this.playHistorySong(song, songs, index);
              },
              onClearHistory: (): void => {
                this.clearHistory();
              },
              onGoSearch: (): void => {
                this.tabsController.changeIndex(1);
              },
              onGoHome: (): void => {
                this.tabsController.changeIndex(0);
              }
            })
          }
          .tabBar(new BottomTabBarStyle({
            normal: TAB_CONFIG[2].symbolGlyph,
            selected: TAB_CONFIG[2].symbolGlyph1
          }, TAB_CONFIG[2].label).labelStyle({
            selectedColor: TAB_SELECTED_COLOR,
            unselectedColor: TAB_UNSELECTED_COLOR,
            font: { size: 12, weight: FontWeight.Medium }
          }))

          TabContent() {
            ProfileView({
              nickname: this.nickname,
              favoriteCount: this.favorites.length,
              historyCount: this.history.length,
              onOpenSettings: (): void => {
                this.openSettings();
              },
              onLogout: (): void => {
                this.handleLogout();
              },
              onOpenFavorites: (): void => {
                this.tabsController.changeIndex(2);
              }
            })
          }
          .tabBar(new BottomTabBarStyle({
            normal: TAB_CONFIG[3].symbolGlyph,
            selected: TAB_CONFIG[3].symbolGlyph1
          }, TAB_CONFIG[3].label).labelStyle({
            selectedColor: TAB_SELECTED_COLOR,
            unselectedColor: TAB_UNSELECTED_COLOR,
            font: { size: 12, weight: FontWeight.Medium }
          }))
        }
        .barOverlap(true)
        .vertical(false)
        .barPosition(BarPosition.End)
        .scrollable(false)
        .animationDuration(0)
        .layoutWeight(1)
        .barFloatingStyle(this.getBarFloatingStyle())
        .onChange((index: number) => {
          this.currentTabIndex = index;
          if (index === 2 || index === 3) {
            this.refreshLibrary();
          }
          if (index === 0 && !this.isLoadingHome && this.recommendPlaylists.length === 0 &&
            this.hotPlaylists.length === 0) {
            this.loadHome();
          }
        })
      }
      .titleBar({
        avoidLayoutSafeArea: true,
        content: {
          title: { mainTitle: '清听' }
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
      .hideBackButton(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
  }
}
