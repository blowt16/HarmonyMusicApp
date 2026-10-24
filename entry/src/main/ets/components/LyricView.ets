import { LyricLine, Song } from '../models/MusicModel';
import { PlayerService } from '../services/PlayerService';

@Component
export struct LyricView {
  @StorageLink('playerMuted') playerMuted: string = '#C9C7D0';
  @StorageLink('playerAccent') playerAccent: string = '#FF6B72';

  @State lyrics: LyricLine[] = [];
  @State currentIndex: number = -1;
  @State isLocalDemo: boolean = false;
  @State isLocalFile: boolean = false;

  private playerService: PlayerService = PlayerService.getInstance();
  private scroller: Scroller = new Scroller();

  private lyricListener: ((index: number, text: string) => void) | null = null;
  private songListener: ((song: Song | null) => void) | null = null;

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
      this.isLocalFile = song !== null && song.filePath !== undefined;
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

  loadLyrics() {
    const song: Song | null = this.playerService.getCurrentSong();
    this.isLocalDemo = song !== null && song.assetName !== undefined;
    this.isLocalFile = song !== null && song.filePath !== undefined;
    const allLyrics: LyricLine[] = this.playerService.getLyrics();
    this.lyrics = (this.isLocalDemo || this.isLocalFile) ? [] : allLyrics;
    this.currentIndex = this.playerService.getCurrentLyricIndex();
  }

  scrollToCurrentLyric() {
    if (this.currentIndex >= 0) {
      this.scroller.scrollToIndex(this.currentIndex);
    }
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
                .fontSize(index === this.currentIndex ? 18 : 15)
                .fontColor(index === this.currentIndex ? this.playerAccent : this.playerMuted)
                .fontWeight(index === this.currentIndex ? FontWeight.Bold : FontWeight.Medium)
                .textAlign(TextAlign.Center)
                .width('100%')
                .padding({ top: 10, bottom: 10 })
                .animation({ duration: 300, curve: Curve.EaseOut })
            }
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

          Text(this.isLocalDemo ? '示例音频，无歌词' : (this.isLocalFile ? '本地音乐，无歌词' : '暂无歌词'))
            .fontSize(15)
            .fontColor(this.playerMuted)
            .margin({ top: 16 })

          Text(this.isLocalDemo ? '本地示例不包含歌词' :
            (this.isLocalFile ? '导入文件不包含歌词' : '静静聆听音乐的美好'))
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
