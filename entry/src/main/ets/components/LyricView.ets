import { LyricLine, Song } from '../models/MusicModel';
import { PlayerService } from '../services/PlayerService';

/**
 * 文件：LyricView.ets
 * 职责：播放页的歌词区域。
 *
 * 数据来源：
 * - PlayerService 的歌词变化监听器负责告诉当前行索引；
 * - 歌曲变化时重新读取歌词；本地示例音频直接显示“无歌词”空态。
 * 点击某行歌词会调用 seekTo，下一轮 timeUpdate 会自动重新计算当前行。
 */
@Component
export struct LyricView {
  @StorageLink('playerMuted') playerMuted: string = '#C9C7D0';
  @StorageLink('playerAccent') playerAccent: string = '#FF6B72';

  @State lyrics: LyricLine[] = [];
  @State currentIndex: number = -1;
  @State isLocalDemo: boolean = false;

  private playerService: PlayerService = PlayerService.getInstance();
  private scroller: Scroller = new Scroller();

  private lyricListener: ((index: number, text: string) => void) | null = null;
  private songListener: ((song: Song | null) => void) | null = null;

  /**
   * 注册歌词 / 歌曲监听。
   * 歌曲变化后延迟 300ms 再读歌词，给 PlayerService 留出写入新歌词的时间。
   */
  aboutToAppear() {
    this.loadLyrics();

    this.lyricListener = (index: number, text: string) => {
      this.currentIndex = index;
      if (index >= 0) {
        this.scrollToCurrentLyric();
      }
    };
    this.playerService.addLyricChangeListener(this.lyricListener);

    this.songListener = (song: Song | null) => {
      this.isLocalDemo = song !== null && song.assetName !== undefined;
      setTimeout(() => {
        this.loadLyrics();
      }, 300);
    };
    this.playerService.addSongChangeListener(this.songListener);
  }

  aboutToDisappear() {
    if (this.lyricListener) {
      this.playerService.removeLyricChangeListener(this.lyricListener);
    }
    if (this.songListener) {
      this.playerService.removeSongChangeListener(this.songListener);
    }
  }

  /**
   * 读取当前歌曲的歌词。
   * 本地示例没有歌词，直接清空列表让 UI 显示空态。
   */
  loadLyrics() {
    const song: Song | null = this.playerService.getCurrentSong();
    this.isLocalDemo = song !== null && song.assetName !== undefined;
    const allLyrics: LyricLine[] = this.playerService.getLyrics();
    this.lyrics = this.isLocalDemo ? [] : allLyrics;
    this.currentIndex = this.playerService.getCurrentLyricIndex();
    if (this.currentIndex >= 0) {
      setTimeout(() => {
        this.scrollToCurrentLyric();
      }, 100);
    }
  }

  scrollToCurrentLyric() {
    if (this.currentIndex >= 0) {
      // 列表顶部有一个占位 ListItem，因此歌词实际下标要 +1
      this.scroller.scrollToIndex(this.currentIndex + 1, true, ScrollAlign.CENTER);
    }
  }

  onLyricTap(lyric: LyricLine, index: number) {
    this.playerService.seekTo(lyric.time);
    this.currentIndex = index;
    this.scrollToCurrentLyric();
  }

  build() {
    Column() {
      if (this.lyrics.length > 0) {
        List({ scroller: this.scroller }) {
          ListItem() {
            Row().width('100%').height(120)
          }

          ForEach(this.lyrics, (lyric: LyricLine, index: number) => {
            ListItem() {
              Text(lyric.text)
                .fontSize(index === this.currentIndex ? 22 : 17)
                .fontColor(index === this.currentIndex ? this.playerAccent : this.playerMuted)
                .fontWeight(index === this.currentIndex ? FontWeight.Bold : FontWeight.Medium)
                .textAlign(TextAlign.Center)
                .width('100%')
                .padding({ top: 14, bottom: 14 })
                .animation({ duration: 300, curve: Curve.EaseOut })
            }
            .onClick(() => {
              this.onLyricTap(lyric, index);
            })
          })

          ListItem() {
            Row().width('100%').height(120)
          }
        }
        .width('100%')
        .height('100%')
        .divider({ strokeWidth: 0 })
        .scrollBar(BarState.Off)
      } else {
        Column() {
          Text('♪')
            .fontSize(44)
            .fontColor(this.playerMuted)
            .opacity(0.7)

          Text(this.isLocalDemo ? '示例音频，无歌词' : '暂无歌词')
            .fontSize(15)
            .fontColor(this.playerMuted)
            .margin({ top: 16 })

          Text(this.isLocalDemo ? '本地示例不包含歌词' : '静静聆听音乐的美好')
            .fontSize(13)
            .fontColor(this.playerMuted)
            .opacity(0.65)
            .margin({ top: 6 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
  }
}
