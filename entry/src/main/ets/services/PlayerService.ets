import media from '@ohos.multimedia.media';
import resourceManager from '@ohos.resourceManager';
import { Song, PlayMode, PlayerState, LyricLine, AudioQuality, SongQualityInfo } from '../models/MusicModel';
import { ApiService } from './ApiService';
import { AudioSessionService, MediaCallbacks } from './AudioSessionService';
import { StorageService } from './StorageService';

export class PlayerService {
  private static instance: PlayerService;
  private avPlayer: media.AVPlayer | null = null;
  private apiService: ApiService;
  private audioSessionService: AudioSessionService;
  private storageService: StorageService;
  private resManager: resourceManager.ResourceManager | null = null;
  private rawFdPath: string = '';

  private currentSong: Song | null = null;
  private historyRecorded: boolean = false;
  private playlist: Song[] = [];
  private currentIndex: number = -1;
  private playMode: PlayMode = PlayMode.SEQUENCE;
  private playerState: PlayerState = PlayerState.STOPPED;
  private currentPosition: number = 0;
  private duration: number = 0;
  private lyrics: LyricLine[] = [];
  private currentLyricIndex: number = -1;
  private currentQuality: AudioQuality = AudioQuality.EXHIGH;

  // 播放请求串行化与取消标记，避免快速切歌时两个 playSong 交叉写状态
  private playQueue: Promise<void> = Promise.resolve();
  private playbackEpoch: number = 0;

  // 使用数组支持多个监听器
  private stateChangeListeners: ((state: PlayerState) => void)[] = [];
  private songChangeListeners: ((song: Song | null) => void)[] = [];
  private progressChangeListeners: ((position: number, duration: number) => void)[] = [];
  private lyricChangeListeners: ((index: number, text: string) => void)[] = [];
  private errorListeners: ((message: string) => void)[] = [];

  private constructor() {
    this.apiService = ApiService.getInstance();
    this.audioSessionService = AudioSessionService.getInstance();
    this.storageService = StorageService.getInstance();

    // 注册媒体控制回调，使实况窗/通知栏的控制按钮能操控播放器
    const mediaCallbacks: MediaCallbacks = {
      onPlay: (): void => { this.play(); },
      onPause: (): void => { this.pause(); },
      onNext: (): void => { this.playNext(); },
      onPrevious: (): void => { this.playPrevious(); },
      onSeek: (position: number): void => { this.seekTo(position); },
    };
    this.audioSessionService.setMediaCallbacks(mediaCallbacks);
  }

  public static getInstance(): PlayerService {
    if (!PlayerService.instance) {
      PlayerService.instance = new PlayerService();
    }
    return PlayerService.instance;
  }

  // 添加状态变化监听器
  addStateChangeListener(listener: (state: PlayerState) => void): void {
    this.stateChangeListeners.push(listener);
  }

  // 移除状态变化监听器
  removeStateChangeListener(listener: (state: PlayerState) => void): void {
    const index = this.stateChangeListeners.indexOf(listener);
    if (index > -1) {
      this.stateChangeListeners.splice(index, 1);
    }
  }

  // 添加歌曲变化监听器
  addSongChangeListener(listener: (song: Song | null) => void): void {
    this.songChangeListeners.push(listener);
  }

  // 移除歌曲变化监听器
  removeSongChangeListener(listener: (song: Song | null) => void): void {
    const index = this.songChangeListeners.indexOf(listener);
    if (index > -1) {
      this.songChangeListeners.splice(index, 1);
    }
  }

  // 添加进度变化监听器
  addProgressChangeListener(listener: (position: number, duration: number) => void): void {
    this.progressChangeListeners.push(listener);
  }

  // 移除进度变化监听器
  removeProgressChangeListener(listener: (position: number, duration: number) => void): void {
    const index = this.progressChangeListeners.indexOf(listener);
    if (index > -1) {
      this.progressChangeListeners.splice(index, 1);
    }
  }

  // 添加播放错误监听器
  addErrorListener(listener: (message: string) => void): void {
    this.errorListeners.push(listener);
  }

  removeErrorListener(listener: (message: string) => void): void {
    const index = this.errorListeners.indexOf(listener);
    if (index > -1) {
      this.errorListeners.splice(index, 1);
    }
  }

  private notifyError(message: string): void {
    for (const listener of this.errorListeners) {
      listener(message);
    }
  }

  setResourceManager(manager: resourceManager.ResourceManager): void {
    this.resManager = manager;
  }

  private async closeRawFd(): Promise<void> {
    if (this.resManager && this.rawFdPath) {
      try {
        await this.resManager.closeRawFd(this.rawFdPath);
      } catch (e) {
        console.error('Close raw fd error:', e);
      }
      this.rawFdPath = '';
    }
  }

  // 添加歌词变化监听器
  addLyricChangeListener(listener: (index: number, text: string) => void): void {
    this.lyricChangeListeners.push(listener);
  }

  // 移除歌词变化监听器
  removeLyricChangeListener(listener: (index: number, text: string) => void): void {
    const index = this.lyricChangeListeners.indexOf(listener);
    if (index > -1) {
      this.lyricChangeListeners.splice(index, 1);
    }
  }

  // 通知所有状态变化监听器
  private notifyStateChange(state: PlayerState): void {
    for (const listener of this.stateChangeListeners) {
      listener(state);
    }
  }

  // 通知所有歌曲变化监听器
  private notifySongChange(song: Song | null): void {
    for (const listener of this.songChangeListeners) {
      listener(song);
    }
  }

  // 通知所有进度变化监听器
  private notifyProgressChange(position: number, duration: number): void {
    for (const listener of this.progressChangeListeners) {
      listener(position, duration);
    }
  }

  // 通知所有歌词变化监听器
  private notifyLyricChange(index: number, text: string): void {
    for (const listener of this.lyricChangeListeners) {
      listener(index, text);
    }
  }

  // 保持向后兼容的方法
  setStateChangeCallback(callback: (state: PlayerState) => void) {
    this.stateChangeListeners = [callback];
  }

  setSongChangeCallback(callback: (song: Song | null) => void) {
    this.songChangeListeners = [callback];
  }

  setProgressChangeCallback(callback: (position: number, duration: number) => void) {
    this.progressChangeListeners = [callback];
  }

  setLyricChangeCallback(callback: (index: number, text: string) => void) {
    this.lyricChangeListeners = [callback];
  }

  private async initPlayer(): Promise<media.AVPlayer> {
    console.info('initPlayer() called');
    if (this.avPlayer) {
      console.info('Releasing existing player');
      const oldPlayer: media.AVPlayer = this.avPlayer;
      this.avPlayer = null;
      await oldPlayer.release();
    }
    await this.closeRawFd();

    console.info('Creating new AVPlayer');
    const player: media.AVPlayer = await media.createAVPlayer();
    this.avPlayer = player;
    console.info('AVPlayer created:', player !== null);

    player.on('stateChange', (state: string) => {
      if (this.avPlayer !== player) {
        return;
      }
      console.info('Player state changed:', state);
      switch (state) {
        case 'initialized':
          console.info('Player initialized, preparing...');
          this.avPlayer?.prepare();
          break;
        case 'prepared':
          console.info('Player prepared, starting playback');
          if (player.duration > 0) {
            this.duration = player.duration / 1000;
            this.notifyProgressChange(this.currentPosition, this.duration);
          }
          player.play();
          break;
        case 'playing':
          console.info('Player is now playing');
          this.playerState = PlayerState.PLAYING;
          this.recordHistoryIfNeeded();
          this.notifyStateChange(this.playerState);
          this.audioSessionService.updatePlaybackState(this.playerState, this.currentPosition, this.duration);
          break;
        case 'paused':
          console.info('Player paused');
          this.playerState = PlayerState.PAUSED;
          this.notifyStateChange(this.playerState);
          this.audioSessionService.updatePlaybackState(this.playerState, this.currentPosition, this.duration);
          break;
        case 'stopped':
          console.info('Player stopped');
          this.playerState = PlayerState.STOPPED;
          this.notifyStateChange(this.playerState);
          this.audioSessionService.updatePlaybackState(this.playerState, this.currentPosition, this.duration);
          break;
        case 'completed':
          console.info('Playback completed, playing next');
          this.playNext();
          break;
        case 'error':
          console.error('Player error occurred');
          this.playerState = PlayerState.STOPPED;
          this.notifyStateChange(this.playerState);
          this.notifyError('播放失败，请换一首歌重试');
          this.audioSessionService.updatePlaybackState(this.playerState, this.currentPosition, this.duration);
          break;
      }
    });

    player.on('timeUpdate', (timeMs: number) => {
      if (this.avPlayer !== player) {
        return;
      }
      this.currentPosition = timeMs / 1000;
      this.notifyProgressChange(this.currentPosition, this.duration);
      this.audioSessionService.updateProgress(this.currentPosition, this.duration);
      this.updateLyric();
    });

    console.info('initPlayer() completed');
    return player;
  }

  // 播放历史统一在这里记录，覆盖首页、歌单、搜索、播放页与上一首/下一首
  private async recordHistoryIfNeeded(): Promise<void> {
    if (this.historyRecorded || !this.currentSong) {
      return;
    }
    this.historyRecorded = true;
    await this.storageService.addPlayHistory(this.currentSong);
  }

  private updateLyric() {
    if (this.lyrics.length === 0) return;

    let newIndex = -1;
    for (let i = this.lyrics.length - 1; i >= 0; i--) {
      if (this.currentPosition >= this.lyrics[i].time) {
        newIndex = i;
        break;
      }
    }

    if (newIndex !== this.currentLyricIndex) {
      this.currentLyricIndex = newIndex;
      const text = newIndex >= 0 ? this.lyrics[newIndex].text : '';
      this.notifyLyricChange(newIndex, text);
    }
  }

  canPlay(song: Song): boolean {
    if (song.assetName) {
      return true;
    }
    return song.playable !== false;
  }

  private findPlayableIndex(start: number, step: number): number {
    const length: number = this.playlist.length;
    if (length === 0) {
      return -1;
    }
    for (let i = 0; i < length; i++) {
      let index: number = (start + i * step) % length;
      if (index < 0) {
        index += length;
      }
      if (this.canPlay(this.playlist[index])) {
        return index;
      }
    }
    return -1;
  }

  playSong(song: Song): Promise<void> {
    const epoch: number = this.playbackEpoch;
    const run: Promise<void> = this.playQueue.then(async () => {
      if (epoch !== this.playbackEpoch) {
        return;
      }
      await this.doPlaySong(song, epoch);
    });
    this.playQueue = run.catch((error: Error) => {
      console.error('Play queue error:', error);
    });
    return run;
  }

  private async doPlaySong(song: Song, epoch: number): Promise<void> {
    console.info('playSong() called for:', song.name, 'id:', song.id);
    if (!this.canPlay(song)) {
      this.currentSong = song;
      this.historyRecorded = false;
      this.currentPosition = 0;
      this.duration = song.duration > 0 ? song.duration / 1000 : 0;
      this.notifyProgressChange(0, this.duration);
      this.notifySongChange(song);
      this.playerState = PlayerState.STOPPED;
      this.notifyStateChange(this.playerState);
      this.notifyError('VIP/付费歌曲，演示环境无法在线播放，可换免费歌曲');
      return;
    }
    try {
      console.info('Initializing player...');
      const player: media.AVPlayer = await this.initPlayer();
      if (epoch !== this.playbackEpoch) {
        if (this.avPlayer === player) {
          this.avPlayer = null;
        }
        await player.release();
        return;
      }

      this.currentSong = song;
      this.historyRecorded = false;
      this.currentPosition = 0;
      this.duration = song.duration > 0 ? song.duration / 1000 : 0;
      this.notifyProgressChange(0, this.duration);
      this.notifySongChange(song);
      this.audioSessionService.updateMetadata(song);
      this.playerState = PlayerState.LOADING;
      this.notifyStateChange(this.playerState);
      this.audioSessionService.updatePlaybackState(this.playerState, 0, this.duration);

      // 项目内置示例音频走 rawfile fdSrc，不依赖网络
      if (song.assetName) {
        if (!this.resManager || !this.avPlayer) {
          this.playerState = PlayerState.STOPPED;
          this.notifyStateChange(this.playerState);
          this.notifyError('本地音频加载失败，请重试');
          return;
        }
        try {
          const rawFd: resourceManager.RawFileDescriptor = await this.resManager.getRawFd(song.assetName);
          if (epoch !== this.playbackEpoch || this.avPlayer !== player) {
            return;
          }
          this.rawFdPath = song.assetName;
          player.fdSrc = {
            fd: rawFd.fd,
            offset: rawFd.offset,
            length: rawFd.length
          };
          this.duration = song.duration / 1000;
          this.lyrics = [];
          this.currentLyricIndex = -1;
          this.notifyLyricChange(-1, '');
        } catch (e) {
          console.error('Load local audio error:', e);
          this.playerState = PlayerState.STOPPED;
          this.notifyStateChange(this.playerState);
          this.notifyError('本地音频加载失败，请重试');
        }
        return;
      }

      // 获取播放链接
      console.info('Getting song URL for id:', song.id, 'quality:', this.currentQuality);
      const url: string = await this.apiService.getSongUrl(song.id, this.currentQuality, song.maxBr ?? 0);
      if (epoch !== this.playbackEpoch || this.avPlayer !== player) {
        return;
      }
      console.info('Song URL result:', url);

      if (url) {
        this.currentSong.url = url;
        console.info('Setting avPlayer.url:', url);
        player.url = url;
        this.duration = song.duration / 1000;
        console.info('Duration set to:', this.duration);
      } else {
        console.error('No URL, url:', url);
        this.playerState = PlayerState.STOPPED;
        this.currentPosition = 0;
        this.duration = 0;
        this.notifyProgressChange(0, 0);
        this.notifyStateChange(this.playerState);
        this.notifyError('该歌曲暂无可用播放地址，请换一首歌');
        return;
      }

      // 获取歌词
      console.info('Getting lyrics...');
      const lyrics: LyricLine[] = await this.apiService.getLyric(song.id);
      if (epoch !== this.playbackEpoch || this.currentSong?.id !== song.id) {
        return;
      }
      this.lyrics = lyrics;
      this.currentLyricIndex = -1;
      console.info('playSong() completed');
    } catch (error) {
      console.error('Play song error:', error);
      if (epoch === this.playbackEpoch) {
        this.playerState = PlayerState.STOPPED;
        this.notifyStateChange(this.playerState);
        this.notifyError('播放失败，请稍后重试');
      }
    }
  }

  async play() {
    console.info('play() called, avPlayer:', this.avPlayer !== null, 'state:', this.playerState, 'currentSong:', this.currentSong ? this.currentSong.name : 'null');

    // 如果正在加载或播放中，不重复操作
    if (this.playerState === PlayerState.LOADING || this.playerState === PlayerState.PLAYING) {
      console.info('Already loading or playing, skipping');
      return;
    }

    if (this.avPlayer && this.playerState === PlayerState.PAUSED) {
      console.info('Resuming paused playback');
      this.avPlayer.play();
    } else if (this.currentSong) {
      if (!this.canPlay(this.currentSong)) {
        this.notifyError('VIP/付费歌曲，演示环境无法在线播放，可换免费歌曲');
        return;
      }
      console.info('Starting playback for:', this.currentSong.name);
      await this.playSong(this.currentSong);
    } else {
      console.warn('No current song to play');
    }
  }

  pause() {
    if (this.avPlayer && this.playerState === PlayerState.PLAYING) {
      this.avPlayer.pause();
    }
  }

  stop() {
    if (this.avPlayer) {
      this.avPlayer.stop();
    }
  }

  async playNext() {
    if (this.playlist.length === 0) return;

    let start: number;
    switch (this.playMode) {
      case PlayMode.RANDOM:
        start = Math.floor(Math.random() * this.playlist.length);
        break;
      case PlayMode.SINGLE:
        if (this.currentIndex >= 0 && this.canPlay(this.playlist[this.currentIndex])) {
          await this.playSong(this.playlist[this.currentIndex]);
        } else {
          this.notifyError('当前歌曲为 VIP/付费歌曲，无法在线播放');
        }
        return;
      default:
        start = this.currentIndex + 1;
    }

    const nextIndex: number = this.findPlayableIndex(start, 1);
    if (nextIndex < 0) {
      this.notifyError('当前列表没有可在线播放的歌曲');
      return;
    }
    this.currentIndex = nextIndex;
    await this.playSong(this.playlist[nextIndex]);
  }

  async playPrevious() {
    if (this.playlist.length === 0) return;

    let start: number;
    switch (this.playMode) {
      case PlayMode.RANDOM:
        start = Math.floor(Math.random() * this.playlist.length);
        break;
      default:
        start = this.currentIndex - 1;
    }

    const prevIndex: number = this.findPlayableIndex(start, -1);
    if (prevIndex < 0) {
      this.notifyError('当前列表没有可在线播放的歌曲');
      return;
    }
    this.currentIndex = prevIndex;
    await this.playSong(this.playlist[prevIndex]);
  }

  seekTo(position: number) {
    if (this.avPlayer) {
      this.avPlayer.seek(position * 1000);
    }
  }

  setPlayMode(mode: PlayMode) {
    this.playMode = mode;
  }

  setPlaylist(songs: Song[], startIndex: number = 0) {
    this.playlist = songs;
    this.currentIndex = startIndex;
  }

  async playAt(index: number): Promise<void> {
    if (index < 0 || index >= this.playlist.length) {
      return;
    }
    if (!this.canPlay(this.playlist[index])) {
      this.notifyError('VIP/付费歌曲，演示环境无法在线播放，可换免费歌曲');
      return;
    }
    this.currentIndex = index;
    await this.playSong(this.playlist[index]);
  }

  getCurrentSong(): Song | null {
    return this.currentSong;
  }

  getPlayerState(): PlayerState {
    return this.playerState;
  }

  getPlayMode(): PlayMode {
    return this.playMode;
  }

  getCurrentPosition(): number {
    return this.currentPosition;
  }

  getDuration(): number {
    return this.duration;
  }

  getPlaylist(): Song[] {
    return this.playlist;
  }

  getCurrentIndex(): number {
    return this.currentIndex;
  }

  getCurrentLyricIndex(): number {
    return this.currentLyricIndex;
  }

  getLyrics(): LyricLine[] {
    return this.lyrics;
  }

  getQuality(): AudioQuality {
    return this.currentQuality;
  }

  setQuality(quality: AudioQuality) {
    this.currentQuality = quality;
    // 如果当前有歌曲在播放，重新加载（本地示例不重新加载）
    if (this.currentSong && !this.currentSong.assetName &&
      (this.playerState === PlayerState.PLAYING || this.playerState === PlayerState.PAUSED)) {
      this.playSong(this.currentSong);
    }
  }

  getAvailableQualities(): SongQualityInfo[] {
    if (this.currentSong && this.currentSong.availableQualities) {
      return this.currentSong.availableQualities;
    }
    // 默认返回所有标准音质
    return [
      { level: AudioQuality.STANDARD, br: 128000, size: 0, sr: 44100 },
      { level: AudioQuality.HIGHER, br: 192000, size: 0, sr: 44100 },
      { level: AudioQuality.EXHIGH, br: 320000, size: 0, sr: 48000 },
      { level: AudioQuality.LOSSLESS, br: 999000, size: 0, sr: 48000 },
    ];
  }

  reset() {
    this.playbackEpoch++;
    this.playQueue = Promise.resolve();
    this.currentSong = null;
    this.playlist = [];
    this.currentIndex = -1;
    this.playerState = PlayerState.STOPPED;
    this.currentPosition = 0;
    this.duration = 0;
    this.lyrics = [];
    this.currentLyricIndex = -1;
    this.historyRecorded = false;
    this.notifyProgressChange(0, 0);
    this.notifySongChange(null);
    this.notifyStateChange(PlayerState.STOPPED);
    this.notifyLyricChange(-1, '');
  }

  async release() {
    this.playbackEpoch++;
    const player: media.AVPlayer | null = this.avPlayer;
    this.avPlayer = null;
    this.playQueue = Promise.resolve();
    if (player) {
      try {
        await player.release();
      } catch (e) {
        console.error('Release player error:', e);
      }
    }
    await this.closeRawFd();
  }
}
