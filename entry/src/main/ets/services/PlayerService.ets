import media from '@ohos.multimedia.media';
import resourceManager from '@ohos.resourceManager';
import { Song, PlayMode, PlayerState, LyricLine, AudioQuality, SongQualityInfo } from '../models/MusicModel';
import { ApiService } from './ApiService';
import { AudioSessionService, MediaCallbacks } from './AudioSessionService';
import { StorageService } from './StorageService';

/**
 * 文件：PlayerService.ets
 * 职责：整个 App 唯一的播放入口，负责调度 AVPlayer、维护播放状态和歌词。
 *
 * 为什么要有这一层：
 * - 页面只调用 playSong / pause / playNext 等高层方法，不直接碰 AVPlayer；
 * - 播放历史、通知栏状态、歌词同步都集中在这里，避免每个页面各写一遍；
 * - 通过串行队列 + epoch 版本号解决快速切歌时状态互相覆盖的问题。
 *
 * 音源目前有两种：
 * - 本地示例：Song.assetName 指向 rawfile，走 fdSrc；
 * - 在线歌曲：调用 ApiService.getSongUrl 拿到 URL，走 player.url。
 */
export class PlayerService {
  private static instance: PlayerService;
  private avPlayer: media.AVPlayer | null = null;
  private apiService: ApiService;
  private audioSessionService: AudioSessionService;
  private storageService: StorageService;
  private resManager: resourceManager.ResourceManager | null = null;
  private rawFdPath: string = ''; // 当前占用的 rawfile 路径，释放时用它关闭 fd

  // ===== 播放状态 =====
  private currentSong: Song | null = null;
  private historyRecorded: boolean = false; // 本次播放是否已经写入历史，防止暂停/继续时重复写
  private playlist: Song[] = [];
  private currentIndex: number = -1;
  private playMode: PlayMode = PlayMode.SEQUENCE;
  private playerState: PlayerState = PlayerState.STOPPED;
  private currentPosition: number = 0; // 秒
  private duration: number = 0; // 秒
  private lyrics: LyricLine[] = [];
  private currentLyricIndex: number = -1;
  private currentQuality: AudioQuality = AudioQuality.EXHIGH;

  // 播放请求串行化与取消标记，避免快速切歌时两个 playSong 交叉写状态
  private playQueue: Promise<void> = Promise.resolve();
  private playbackEpoch: number = 0;

  // 使用数组支持多个监听器：页面可以同时监听同一类事件
  private stateChangeListeners: ((state: PlayerState) => void)[] = [];
  private songChangeListeners: ((song: Song | null) => void)[] = [];
  private progressChangeListeners: ((position: number, duration: number) => void)[] = [];
  private lyricChangeListeners: ((index: number, text: string) => void)[] = [];
  private errorListeners: ((message: string) => void)[] = [];

  /**
   * 私有构造：外部只能通过 getInstance() 拿到单例。
   * 构造时把通知栏 / 媒体面板的按钮回调注册到 AudioSessionService，
   * 这样系统媒体控制最终也走 PlayerService 的同一套方法。
   */
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

  /**
   * MainAbility 启动时注入 ResourceManager。
   * 播放 rawfile 示例音频需要用它打开 / 关闭 fd。
   */
  setResourceManager(manager: resourceManager.ResourceManager): void {
    this.resManager = manager;
  }

  /**
   * 关闭 rawfile fd。切歌、重置、释放播放器时都要调用，避免文件描述符泄漏。
   */
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

  /**
   * 创建并初始化一个新的 AVPlayer。
   *
   * 步骤：
   * 1. 先释放旧播放器和旧 rawfile fd，保证同一时间只有一个播放器；
   * 2. 注册 stateChange / timeUpdate 两类事件；
   * 3. 把 AVPlayer 自己的底层状态（initialized → prepared → playing）
   *    翻译成 App 统一的 PlayerState，再通知页面。
   *
   * 回调里反复检查 this.avPlayer !== player，是为了忽略旧播放器的迟到事件，
   * 避免快速切歌时旧事件把新歌曲的状态覆盖掉。
   */
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

    // AVPlayer 底层状态机：initialized 后 prepare，prepared 后 play
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
          // 真正起播时才记录历史，避免加载失败也写进最近播放
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
          // 播完自动切下一首；具体下一首由 playMode 决定
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

    // timeUpdate 是播放进度的主驱动：同时更新页面进度、通知栏进度和歌词
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

  /**
   * 播放历史统一在这里记录。
   * 所有入口（首页、歌单、搜索、播放页、上一首/下一首）最终都会走 PlayerService，
   * 所以只需要在真正起播时写一次；historyRecorded 防止暂停/继续时重复写。
   */
  private async recordHistoryIfNeeded(): Promise<void> {
    if (this.historyRecorded || !this.currentSong) {
      return;
    }
    this.historyRecorded = true;
    await this.storageService.addPlayHistory(this.currentSong);
  }

  /**
   * 根据当前播放进度计算歌词高亮行。
   * 从后往前找第一个「时间 ≤ 当前进度」的行；只有索引变化才通知 UI，
   * 避免 timeUpdate 每次都触发重绘。
   */
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

  /**
   * 判断一首歌是否允许播放。
   * 本地示例音频永远可播；在线歌曲看接口返回的 playable 标记，
   * VIP / 付费歌曲在接口层会被标记为 false。
   */
  canPlay(song: Song): boolean {
    if (song.assetName) {
      return true;
    }
    return song.playable !== false;
  }

  /**
   * 从 start 开始沿 step 方向找下一首可播放的歌。
   * 用 % length 实现首尾环绕；找不到（整张列表都不可播）时返回 -1。
   */
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

  /**
   * 播放请求的统一入口。
   *
   * 两层保护：
   * 1. playQueue 把所有请求串成 Promise 链，避免两个 playSong 同时操作 AVPlayer；
   * 2. playbackEpoch 是「代次」标记，reset/release 时递增；旧任务发现代次变了就直接退出，
   *    不再继续写当前歌曲、状态和歌词。
   */
  playSong(song: Song): Promise<void> {
    const epoch: number = this.playbackEpoch;
    const run: Promise<void> = this.playQueue.then(async () => {
      if (epoch !== this.playbackEpoch) {
        return;
      }
      await this.doPlaySong(song, epoch);
    });
    // 队列里某个任务失败不能阻断后续播放，所以把错误吞掉后继续链式等待
    this.playQueue = run.catch((error: Error) => {
      console.error('Play queue error:', error);
    });
    return run;
  }

  /**
   * 真正执行一次播放。
   *
   * 流程：
   * 1. 不可播放的歌曲（VIP/付费）直接把 UI 置为 STOPPED 并提示；
   * 2. 创建新 AVPlayer，并检查代次，防止旧任务继续执行；
   * 3. 先把当前歌曲、进度、时长通知 UI，状态置为 LOADING；
   * 4. 按音源分支加载：assetName 走 rawfile fdSrc，否则走在线 URL；
   * 5. 在线歌曲拿到 URL 后再请求歌词；后续由 AVPlayer 事件推进状态。
   */
  private async doPlaySong(song: Song, epoch: number): Promise<void> {
    console.info('playSong() called for:', song.name, 'id:', song.id);
    if (!this.canPlay(song)) {
      // 不可播放也要把歌曲信息推给 UI，让页面能显示「哪首歌不能播」
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
      // initPlayer 是异步的，期间可能又来了新的播放请求；代次不一致就丢弃这次结果
      if (epoch !== this.playbackEpoch) {
        if (this.avPlayer === player) {
          this.avPlayer = null;
        }
        await player.release();
        return;
      }

      // 统一更新「当前歌曲」相关状态，并通知页面和通知栏
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
          // rawfile 通过 ResourceManager 拿到 fd，再交给 AVPlayer，完全不经过网络
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
          // 本地示例没有歌词，清空歌词并通知歌词组件回到空态
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

      // 在线歌曲：先请求播放地址，再设置 player.url
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
        // 拿不到地址通常是版权 / 会员限制，直接回 STOPPED，别让页面一直转圈
        console.error('No URL, url:', url);
        this.playerState = PlayerState.STOPPED;
        this.currentPosition = 0;
        this.duration = 0;
        this.notifyProgressChange(0, 0);
        this.notifyStateChange(this.playerState);
        this.notifyError('该歌曲暂无可用播放地址，请换一首歌');
        return;
      }

      // 歌词是锦上添花：请求失败只返回空数组，不影响播放
      console.info('Getting lyrics...');
      const lyrics: LyricLine[] = await this.apiService.getLyric(song.id);
      // 请求歌词期间可能又切歌了，确认当前歌曲没变再写入
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

  /**
   * 继续播放：
   * - 正在加载 / 播放时直接忽略，避免重复触发；
   * - 暂停状态直接从 AVPlayer 继续，不重新加载；
   * - 其他情况用当前歌曲重新走 playSong。
   */
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

  /**
   * 暂停播放。只有正在播放时才调用底层 pause，
   * 状态变化由 AVPlayer 的 paused 事件统一回写。
   */
  pause() {
    if (this.avPlayer && this.playerState === PlayerState.PLAYING) {
      this.avPlayer.pause();
    }
  }

  /**
   * 停止播放；状态同样通过 AVPlayer 的 stopped 事件回写。
   */
  stop() {
    if (this.avPlayer) {
      this.avPlayer.stop();
    }
  }

  /**
   * 下一首。
   * 随机模式随机选起点；单曲模式重播当前歌；
   * 其余模式从当前索引 +1 开始找可播放歌曲，找不到就提示。
   */
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

  /**
   * 上一首。
   * 随机模式同样随机选起点；其余模式从当前索引 -1 开始找可播放歌曲。
   */
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

  /**
   * 拖动进度：UI 传秒，AVPlayer 需要毫秒。
   */
  seekTo(position: number) {
    if (this.avPlayer) {
      this.avPlayer.seek(position * 1000);
    }
  }

  /**
   * 切换播放模式（顺序 / 循环 / 随机 / 单曲）。
   */
  setPlayMode(mode: PlayMode) {
    this.playMode = mode;
  }

  /**
   * 设置当前播放列表，并记录起始索引。
   * 播放列表只保存在内存里，不持久化。
   */
  setPlaylist(songs: Song[], startIndex: number = 0) {
    this.playlist = songs;
    this.currentIndex = startIndex;
  }

  /**
   * 播放列表中指定位置的歌曲。
   * 越界或不可播放时直接返回 / 提示，不改变当前歌曲。
   */
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

  // ===== 状态读取 =====
  // 页面通过这些 getter 读取播放状态，不直接访问私有字段

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

  /**
   * 切换音质。
   * 如果当前正在播放 / 暂停一首在线歌曲，需要用新码率重新加载；
   * 本地示例没有码率概念，不需要重新加载。
   * 注意：当前实现会从 0 秒重新开始播放，这是已知行为。
   */
  setQuality(quality: AudioQuality) {
    this.currentQuality = quality;
    // 如果当前有歌曲在播放，重新加载（本地示例不重新加载）
    if (this.currentSong && !this.currentSong.assetName &&
      (this.playerState === PlayerState.PLAYING || this.playerState === PlayerState.PAUSED)) {
      this.playSong(this.currentSong);
    }
  }

  /**
   * 返回当前歌曲可用的音质列表。
   * 接口没给 availableQualities 时，回退到项目预置的四档标准音质。
   */
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

  /**
   * 重置播放状态（退出登录 / 停止播放时使用）。
   * 递增 epoch 让旧任务作废，清空歌曲、列表、进度和歌词，
   * 最后通知 UI 回到 STOPPED 空态。
   * 注意：reset 不释放 AVPlayer，释放由 release 负责。
   */
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

  /**
   * 释放播放器资源。
   * 递增 epoch 让排队中的旧任务作废，释放 AVPlayer，并关闭 rawfile fd。
   * 通常在 Ability.onDestroy 或退出登录时调用。
   */
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
