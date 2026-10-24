import { Song } from '../../models/MusicModel';
import { thumbnail } from '../../utils/ImageUtils';

/**
 * 收藏 Tab：收藏 / 最近播放两个 segment。
 * 数据由 Index 统一读取并在切换 Tab、返回页面时刷新。
 */
@Component
export struct FavoritesView {
  @StorageLink('bgPrimary') bgPrimary: string = '#F7F6F2';
  @StorageLink('bgSecondary') bgSecondary: string = '#FFFFFF';
  @StorageLink('textPrimary') textPrimary: string = '#17181A';
  @StorageLink('textSecondary') textSecondary: string = '#6B6F76';
  @StorageLink('textTertiary') textTertiary: string = '#9A9EA5';
  @StorageLink('accent') accent: string = '#C8424C';
  @StorageLink('accentLight') accentLight: string = '#FDEBED';
  @StorageLink('border') themeBorder: string = '#ECE8E0';

  @Prop favorites: Song[] = [];
  @Prop history: Song[] = [];
  @Prop currentPlayingId: number = -1;

  onPlaySong: (song: Song, songs: Song[], index: number) => void = () => {};
  onClearHistory: () => void = () => {};
  onGoSearch: () => void = () => {};
  onGoHome: () => void = () => {};

  @State segmentIndex: number = 0;

  private currentList(): Song[] {
    return this.segmentIndex === 0 ? this.favorites : this.history;
  }

  @Builder
  FavoriteChip() {
    Text(`收藏 ${this.favorites.length}`)
      .fontSize(14)
      .fontWeight(this.segmentIndex === 0 ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.segmentIndex === 0 ? '#FFFFFF' : this.textSecondary)
      .backgroundColor(this.segmentIndex === 0 ? this.accent : this.bgSecondary)
      .borderRadius(18)
      .height(36)
      .padding({ left: 16, right: 16 })
      .textAlign(TextAlign.Center)
      .onClick(() => {
        this.segmentIndex = 0;
      })
  }

  @Builder
  HistoryChip() {
    Text(`最近播放 ${this.history.length}`)
      .fontSize(14)
      .fontWeight(this.segmentIndex === 1 ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.segmentIndex === 1 ? '#FFFFFF' : this.textSecondary)
      .backgroundColor(this.segmentIndex === 1 ? this.accent : this.bgSecondary)
      .borderRadius(18)
      .height(36)
      .padding({ left: 16, right: 16 })
      .textAlign(TextAlign.Center)
      .onClick(() => {
        this.segmentIndex = 1;
      })
  }

  @Builder
  SongRow(song: Song, songs: Song[], index: number) {
    Row() {
      if (song.coverUrl) {
        Image(thumbnail(song.coverUrl, 100, 100))
          .width(40)
          .height(40)
          .borderRadius(6)
          .objectFit(ImageFit.Cover)
          .backgroundColor(this.accentLight)
      } else {
        Stack() {
          Text('♪')
            .fontSize(16)
            .fontColor(this.accent)
        }
        .width(40)
        .height(40)
        .borderRadius(6)
        .backgroundColor(this.accentLight)
      }

      Column() {
        Text(song.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(song.id === this.currentPlayingId ? this.accent : this.textPrimary)
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

      SymbolGlyph($r('sys.symbol.play_fill'))
        .fontSize(18)
        .fontColor([song.id === this.currentPlayingId ? this.accent : this.textTertiary])
        .margin({ left: 8 })
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.bgSecondary)
    .onClick(() => {
      this.onPlaySong(song, songs, index);
    })
  }

  @Builder
  EmptyBlock() {
    Column() {
      SymbolGlyph(this.segmentIndex === 0 ? $r('sys.symbol.heart') : $r('sys.symbol.clock'))
        .fontSize(44)
        .fontColor([this.accent])
        .opacity(0.8)

      Text(this.segmentIndex === 0 ? '还没有收藏的歌曲' : '还没有播放记录')
        .fontSize(15)
        .fontColor(this.textPrimary)
        .margin({ top: 14 })

      Text(this.segmentIndex === 0 ? '收藏喜欢的歌，随时回来听' : '播放过的歌曲会出现在这里')
        .fontSize(12)
        .fontColor(this.textTertiary)
        .margin({ top: 6 })

      Button(this.segmentIndex === 0 ? '去搜索一首喜欢的歌' : '去首页听听')
        .height(40)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(this.accent)
        .borderRadius(20)
        .margin({ top: 18 })
        .onClick(() => {
          if (this.segmentIndex === 1) {
            this.onGoHome();
          } else {
            this.onGoSearch();
          }
        })
    }
    .width('100%')
    .padding({ top: 28, bottom: 28 })
    .backgroundColor(this.bgSecondary)
    .borderRadius(20)
  }

  build() {
    Column() {
      Row()
        .height(110)
        .width('100%')

      Column() {
        Row({ space: 10 }) {
          this.FavoriteChip()
          this.HistoryChip()
          Blank()
          if (this.segmentIndex === 0) {
            Text('我的收藏')
              .fontSize(12)
              .fontColor(this.textTertiary)
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 12 })

        if (this.segmentIndex === 1 && this.history.length > 0) {
          Row() {
            Text('按最近播放排序')
              .fontSize(12)
              .fontColor(this.textTertiary)
            Blank()
            Text('清空历史')
              .fontSize(13)
              .fontColor(this.accent)
              .height(32)
              .padding({ left: 8, right: 8 })
              .onClick(() => {
                this.onClearHistory();
              })
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 8 })
        }

        if (this.currentList().length === 0) {
          this.EmptyBlock()
        } else {
          List({ space: 1 }) {
            ForEach(this.currentList(), (song: Song, index: number) => {
              ListItem() {
                this.SongRow(song, this.currentList(), index)
              }
            })
            ListItem() {
              Row().width('100%').height(120)
            }
          }
          .width('100%')
          .layoutWeight(1)
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
}
