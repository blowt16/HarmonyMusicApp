import { PlayerService } from '../services/PlayerService';
import { PlayMode, PlayerState, Song } from '../models/MusicModel';

/**
 * 文件：PlayerControls.ets
 * 职责：播放页底部的控制条：进度、播放模式、上一首 / 播放 / 下一首、播放列表入口。
 *
 * 组件只负责显示和转发操作，真正的播放状态由 PlayerService 维护：
 * 进入时读取一次当前状态，之后通过监听器增量更新。
 */
@Component
export struct PlayerControls {
  @StorageLink('playerText') playerText: string = '#F5F5F7';
  @StorageLink('playerMuted') playerMuted: string = '#C9C7D0';
  @StorageLink('playerAccent') playerAccent: string = '#FF6B72';

  playlistAction: () => void = () => {};

  @State currentState: PlayerState = PlayerState.STOPPED;
  @State currentSong: Song | null = null;
  @State currentPosition: number = 0;
  @State duration: number = 0;
  @State playMode: PlayMode = PlayMode.SEQUENCE;

  private playerService: PlayerService = PlayerService.getInstance();

  private stateListener: ((state: PlayerState) => void) | null = null;
  private songListener: ((song: Song | null) => void) | null = null;
  private progressListener: ((position: number, duration: number) => void) | null = null;

  /**
   * 先同步一次当前状态，避免第一帧空白；再注册三类监听。
   */
  aboutToAppear() {
    this.currentState = this.playerService.getPlayerState();
    this.currentSong = this.playerService.getCurrentSong();
    this.currentPosition = this.playerService.getCurrentPosition();
    this.duration = this.playerService.getDuration();
    this.playMode = this.playerService.getPlayMode();

    this.stateListener = (state: PlayerState) => {
      this.currentState = state;
    };
    this.playerService.addStateChangeListener(this.stateListener);

    this.songListener = (song: Song | null) => {
      this.currentSong = song;
    };
    this.playerService.addSongChangeListener(this.songListener);

    this.progressListener = (position: number, duration: number) => {
      this.currentPosition = position;
      this.duration = duration;
    };
    this.playerService.addProgressChangeListener(this.progressListener);
  }

  aboutToDisappear() {
    if (this.stateListener) {
      this.playerService.removeStateChangeListener(this.stateListener);
    }
    if (this.songListener) {
      this.playerService.removeSongChangeListener(this.songListener);
    }
    if (this.progressListener) {
      this.playerService.removeProgressChangeListener(this.progressListener);
    }
  }

  build() {
    Column() {
      // 进度条
      Row() {
        Text(this.formatTime(this.currentPosition))
          .fontSize(12)
          .fontColor(this.playerMuted)

        Slider({
          value: this.currentPosition,
          min: 0,
          max: this.duration > 0 ? this.duration : 1,
          step: 1
        })
          .selectedColor(this.playerAccent)
          .trackColor('#33FFFFFF')
          .blockColor('#FFFFFF')
          .layoutWeight(1)
          .margin({ left: 8, right: 8 })
          .onChange((value: number) => {
            this.playerService.seekTo(value);
          })

        Text(this.formatTime(this.duration))
          .fontSize(12)
          .fontColor(this.playerMuted)
      }
      .width('100%')
      .padding({ left: 24, right: 24 })

      // 控制按钮行
      Row() {
        Button() {
          if (this.playMode === PlayMode.SEQUENCE) {
            SymbolGlyph($r('sys.symbol.list_bullet'))
              .fontSize(22)
              .fontColor([this.playerMuted])
          } else if (this.playMode === PlayMode.LOOP) {
            SymbolGlyph($r('sys.symbol.repeat'))
              .fontSize(22)
              .fontColor([this.playerAccent])
          } else if (this.playMode === PlayMode.SINGLE) {
            SymbolGlyph($r('sys.symbol.repeat_1'))
              .fontSize(22)
              .fontColor([this.playerAccent])
          } else if (this.playMode === PlayMode.RANDOM) {
            SymbolGlyph($r('sys.symbol.shuffle'))
              .fontSize(22)
              .fontColor([this.playerMuted])
          }
        }
        .width(48)
        .height(48)
        .backgroundColor('transparent')
        .accessibilityText('切换播放模式')
        .onClick(() => {
          this.togglePlayMode();
        })

        Button() {
          SymbolGlyph($r('sys.symbol.backward_fill'))
            .fontSize(26)
            .fontColor([this.playerText])
        }
        .width(50)
        .height(50)
        .backgroundColor('transparent')
        .accessibilityText('上一首')
        .onClick(() => {
          this.playerService.playPrevious();
        })

        Button() {
          if (this.currentState === PlayerState.PLAYING) {
            SymbolGlyph($r('sys.symbol.pause_fill'))
              .fontSize(34)
              .fontColor(['#FFFFFF'])
          } else {
            SymbolGlyph($r('sys.symbol.play_fill'))
              .fontSize(34)
              .fontColor(['#FFFFFF'])
          }
        }
        .width(66)
        .height(66)
        .borderRadius(33)
        .backgroundColor(this.playerAccent)
        .accessibilityText(this.currentState === PlayerState.PLAYING ? '暂停' : '播放')
        .onClick(() => {
          if (this.currentState === PlayerState.PLAYING) {
            this.playerService.pause();
          } else {
            this.playerService.play();
          }
        })

        Button() {
          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .fontSize(26)
            .fontColor([this.playerText])
        }
        .width(50)
        .height(50)
        .backgroundColor('transparent')
        .accessibilityText('下一首')
        .onClick(() => {
          this.playerService.playNext();
        })

        Button() {
          SymbolGlyph($r('sys.symbol.list_bullet'))
            .fontSize(22)
            .fontColor([this.playerMuted])
        }
        .width(48)
        .height(48)
        .backgroundColor('transparent')
        .accessibilityText('播放列表')
        .onClick(() => {
          this.playlistAction();
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
      .padding({ top: 8, bottom: 8 })
    }
  }

  formatTime(seconds: number): string {
    if (!seconds || seconds < 0 || !isFinite(seconds)) {
      return '00:00';
    }
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  togglePlayMode() {
    const modes = [PlayMode.SEQUENCE, PlayMode.LOOP, PlayMode.RANDOM, PlayMode.SINGLE];
    const currentIndex = modes.indexOf(this.playMode);
    this.playMode = modes[(currentIndex + 1) % modes.length];
    this.playerService.setPlayMode(this.playMode);
  }
}
