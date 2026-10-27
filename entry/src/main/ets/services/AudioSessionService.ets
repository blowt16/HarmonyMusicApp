import { avSession } from '@kit.AVSessionKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent, common } from '@kit.AbilityKit';
import type { WantAgent } from '@ohos.wantAgent';
import http from '@ohos.net.http';
import image from '@ohos.multimedia.image';
import fs from '@ohos.file.fs';
import { Song, PlayerState } from '../models/MusicModel';

const TAG: string = 'AudioSessionService';

/**
 * 文件：AudioSessionService.ets
 * 职责：App 与系统媒体能力之间的桥梁。
 *
 * 三件事：
 * 1. AVSession：把当前歌曲、封面、播放状态、进度告诉系统，
 *    让通知栏 / 锁屏 / 媒体面板能显示和控制；
 * 2. 后台长时任务：播放时申请 audioPlayback 后台任务，保证切到后台还能出声；
 * 3. 媒体按钮回调：系统事件转成 PlayerService 的方法调用。
 *
 * 注意：本服务不直接操作 AVPlayer，播放决定权仍在 PlayerService。
 */

/**
 * 媒体控制回调接口。
 * 由 PlayerService 在构造时注册，AudioSessionService 只负责转发系统事件。
 */
export interface MediaCallbacks {
  onPlay: () => void;
  onPause: () => void;
  onNext: () => void;
  onPrevious: () => void;
  onSeek: (position: number) => void;
}

/**
 * 媒体会话服务（单例）。
 * 一个 App 只需要一个 AVSession，所有播放状态都通过它同步给系统。
 */
export class AudioSessionService {
  private static instance: AudioSessionService;
  private context: common.UIAbilityContext | null = null;
  private session: avSession.AVSession | null = null;
  private isBackgroundTaskRunning: boolean = false;
  private lastProgressUpdateTime: number = 0; // 进度上报节流用
  private wantAgentInstance: WantAgent | null = null; // 通知栏点击后要拉起的 Ability

  // 封面缓存：同一首歌反复更新元数据时不重复下载 / 解码
  private cachedCoverUrl: string = '';
  private cachedCoverPixelMap: image.PixelMap | null = null;

  // 媒体控制回调（由 PlayerService 注册）
  private onPlayCallback: (() => void) | null = null;
  private onPauseCallback: (() => void) | null = null;
  private onNextCallback: (() => void) | null = null;
  private onPreviousCallback: (() => void) | null = null;
  private onSeekCallback: ((position: number) => void) | null = null;

  private constructor() {}

  public static getInstance(): AudioSessionService {
    if (!AudioSessionService.instance) {
      AudioSessionService.instance = new AudioSessionService();
    }
    return AudioSessionService.instance;
  }

  /**
   * 注册媒体控制回调。
   * 回调由 PlayerService 提供，系统按钮事件最终会调用到这里注册的方法。
   */
  setMediaCallbacks(callbacks: MediaCallbacks): void {
    this.onPlayCallback = callbacks.onPlay;
    this.onPauseCallback = callbacks.onPause;
    this.onNextCallback = callbacks.onNext;
    this.onPreviousCallback = callbacks.onPrevious;
    this.onSeekCallback = callbacks.onSeek;
  }

  /**
   * 初始化：创建 WantAgent 和 AVSession。
   * 在 MainAbility.onCreate 的已登录分支调用。
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    try {
      await this.createWantAgent();
      await this.createAVSession();
      console.info(TAG, 'AudioSessionService initialized');
    } catch (err) {
      console.error(TAG, 'Failed to init AudioSessionService:', JSON.stringify(err));
    }
  }

  /**
   * 创建 WantAgent，用于点击通知栏 / 媒体面板时回到应用。
   * 固定指向 MainAbility；MainAbility 自己有登录门禁，未登录会被送回登录页。
   */
  private async createWantAgent(): Promise<void> {
    if (!this.context) {
      return;
    }

    try {
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: this.context.applicationInfo.name,
            abilityName: 'MainAbility',
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
      };
      this.wantAgentInstance = await wantAgent.getWantAgent(wantAgentInfo);
      console.info(TAG, 'WantAgent created');
    } catch (err) {
      console.error(TAG, 'Failed to create WantAgent:', JSON.stringify(err));
    }
  }

  /**
   * 创建 AVSession 并注册系统媒体按钮事件。
   * 每个事件都只做一件事：转发给 PlayerService 注册的回调。
   * 这样系统控制和 App 内控制最终走同一套播放逻辑。
   */
  private async createAVSession(): Promise<void> {
    if (!this.context) {
      return;
    }

    // 创建 AVSession
    this.session = await avSession.createAVSession(this.context, 'MusicPlayer', 'audio');
    console.info(TAG, 'AVSession created');

    // 注册媒体控制回调
    this.session.on('play', (): void => {
      console.info(TAG, 'AVSession play event');
      if (this.onPlayCallback) {
        this.onPlayCallback();
      }
    });

    this.session.on('pause', (): void => {
      console.info(TAG, 'AVSession pause event');
      if (this.onPauseCallback) {
        this.onPauseCallback();
      }
    });

    this.session.on('playNext', (): void => {
      console.info(TAG, 'AVSession playNext event');
      if (this.onNextCallback) {
        this.onNextCallback();
      }
    });

    this.session.on('playPrevious', (): void => {
      console.info(TAG, 'AVSession playPrevious event');
      if (this.onPreviousCallback) {
        this.onPreviousCallback();
      }
    });

    this.session.on('seek', (position: number): void => {
      console.info(TAG, 'AVSession seek event:', position);
      if (this.onSeekCallback) {
        this.onSeekCallback(position / 1000); // AVSession 传入的是毫秒，转换为秒
      }
    });

    // 激活会话，系统媒体面板才会显示当前 App 的播放信息
    await this.session.activate();
    console.info(TAG, 'AVSession activated');
  }

  /**
   * 启动后台长时任务。
   * 只有 AVSession 激活且申请到 audioPlayback 后台任务，切后台才能继续播放。
   * 用 isBackgroundTaskRunning 防止重复申请。
   */
  async startBackgroundTask(): Promise<void> {
    if (!this.context || this.isBackgroundTaskRunning) {
      return;
    }

    if (!this.wantAgentInstance) {
      console.error(TAG, 'WantAgent not initialized, cannot start background task');
      return;
    }

    try {
      await backgroundTaskManager.startBackgroundRunning(
        this.context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
        this.wantAgentInstance
      );
      this.isBackgroundTaskRunning = true;
      console.info(TAG, 'Background task started');
    } catch (err) {
      console.error(TAG, 'Failed to start background task:', JSON.stringify(err));
    }
  }

  /**
   * 停止后台长时任务
   */
  async stopBackgroundTask(): Promise<void> {
    if (!this.context || !this.isBackgroundTaskRunning) {
      return;
    }

    try {
      await backgroundTaskManager.stopBackgroundRunning(this.context);
      this.isBackgroundTaskRunning = false;
      console.info(TAG, 'Background task stopped');
    } catch (err) {
      console.error(TAG, 'Failed to stop background task:', JSON.stringify(err));
    }
  }

  /**
   * 下载封面并转换成 PixelMap，供 AVSession 元数据使用。
   *
   * 流程：去掉缩略图参数 → HTTP 下载二进制 → 写临时文件 →
   * ImageSource 解码成 PixelMap → 删除临时文件 → 更新内存缓存。
   * 任何一步失败都返回 null，通知栏只是没有封面，不影响播放。
   */
  private async fetchCoverPixelMap(coverUrl: string): Promise<image.PixelMap | null> {
    if (!coverUrl) {
      console.error(TAG, 'Cover URL is empty');
      return null;
    }

    // 使用缓存
    if (coverUrl === this.cachedCoverUrl && this.cachedCoverPixelMap) {
      console.info(TAG, 'Using cached cover PixelMap');
      return this.cachedCoverPixelMap;
    }

    // 去掉 ?param= 缩略图参数，使用原图
    const originalUrl: string = coverUrl.split('?')[0];
    const tempPath: string = (this.context?.cacheDir || '') + '/cover_temp.jpg';

    try {
      console.info(TAG, 'Downloading cover from:', originalUrl);
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(originalUrl, {
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 15000,
        header: {
          'Referer': 'https://music.163.com',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        }
      });

      if (response.responseCode !== http.ResponseCode.OK || !response.result) {
        console.error(TAG, 'Failed to download cover, status:', response.responseCode);
        httpRequest.destroy();
        return null;
      }

      const imageData: ArrayBuffer = response.result as ArrayBuffer;
      httpRequest.destroy();
      console.info(TAG, 'Cover downloaded, size:', imageData.byteLength);

      // 写入临时文件
      const file = fs.openSync(tempPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(file.fd, imageData);
      fs.closeSync(file);

      // 从文件创建 ImageSource（使用 file:// URI）
      const imageSource: image.ImageSource = image.createImageSource('file://' + tempPath);
      const pixelMap: image.PixelMap = await imageSource.createPixelMap();
      imageSource.release();

      // 清理临时文件
      try {
        fs.unlinkSync(tempPath);
      } catch (e) {
        // 忽略
      }

      // 更新缓存
      this.cachedCoverUrl = coverUrl;
      if (this.cachedCoverPixelMap) {
        this.cachedCoverPixelMap.release();
      }
      this.cachedCoverPixelMap = pixelMap;

      console.info(TAG, 'Cover PixelMap created successfully');
      return pixelMap;
    } catch (err) {
      console.error(TAG, 'Failed to fetch cover PixelMap:', JSON.stringify(err));
      try {
        fs.unlinkSync(tempPath);
      } catch (e) {
        // 忽略
      }
      return null;
    }
  }

  /**
   * 更新系统媒体面板显示的歌曲信息（标题、歌手、专辑、时长、封面）。
   * 封面下载失败时仍然设置文字元数据。
   */
  async updateMetadata(song: Song): Promise<void> {
    if (!this.session) {
      return;
    }

    try {
      // 获取封面 PixelMap
      const coverPixelMap: image.PixelMap | null = await this.fetchCoverPixelMap(song.coverUrl);

      const metadata: avSession.AVMetadata = {
        assetId: song.id.toString(),
        title: song.name,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
      };

      if (coverPixelMap) {
        metadata.mediaImage = coverPixelMap;
      }

      await this.session.setAVMetadata(metadata);
      console.info(TAG, 'Metadata updated:', song.name, coverPixelMap ? 'with cover' : 'no cover');
    } catch (err) {
      console.error(TAG, 'Failed to update metadata:', JSON.stringify(err));
    }
  }

  /**
   * 把 App 自己的 PlayerState 映射成系统 AVSession 的播放状态。
   * LOADING 对应 PREPARE，让系统面板知道当前在准备而不是暂停。
   */
  private mapPlayerState(state: PlayerState): avSession.PlaybackState {
    switch (state) {
      case PlayerState.PLAYING:
        return avSession.PlaybackState.PLAYBACK_STATE_PLAY;
      case PlayerState.PAUSED:
        return avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
      case PlayerState.LOADING:
        return avSession.PlaybackState.PLAYBACK_STATE_PREPARE;
      default:
        return avSession.PlaybackState.PLAYBACK_STATE_STOP;
    }
  }

  /**
   * 更新系统播放状态，并根据状态启停后台长时任务。
   * PLAYING 时申请后台任务，STOPPED 时释放；PAUSED / LOADING 保持现状。
   */
  async updatePlaybackState(state: PlayerState, position: number, duration: number): Promise<void> {
    if (!this.session) {
      return;
    }

    // 根据播放状态决定是否启停后台任务
    if (state === PlayerState.PLAYING) {
      await this.startBackgroundTask();
    } else if (state === PlayerState.STOPPED) {
      await this.stopBackgroundTask();
    }

    try {
      const playbackState: avSession.AVPlaybackState = {
        state: this.mapPlayerState(state),
        position: {
          elapsedTime: position * 1000,
          updateTime: Date.now(),
        },
        speed: 1.0,
      };
      await this.session.setAVPlaybackState(playbackState);
    } catch (err) {
      console.error(TAG, 'Failed to update playback state:', JSON.stringify(err));
    }
  }

  /**
   * 更新系统进度。
   * AVPlayer 的 timeUpdate 频率很高，这里做 1 秒节流，
   * 避免每秒几十次跨进程调用导致通知栏刷屏和额外开销。
   */
  async updateProgress(position: number, duration: number): Promise<void> {
    if (!this.session) {
      return;
    }

    const now: number = Date.now();
    if (now - this.lastProgressUpdateTime < 1000) {
      return;
    }
    this.lastProgressUpdateTime = now;

    try {
      const playbackState: avSession.AVPlaybackState = {
        state: avSession.PlaybackState.PLAYBACK_STATE_PLAY,
        position: {
          elapsedTime: position * 1000,
          updateTime: now,
        },
        speed: 1.0,
      };
      await this.session.setAVPlaybackState(playbackState);
    } catch (err) {
      // 进度更新失败静默处理，避免刷屏
    }
  }

  /**
   * 销毁服务：按「后台任务 → 封面缓存 → AVSession → 引用」的顺序清理。
   * 先停后台任务，避免会话销毁后系统仍认为 App 在后台播放。
   */
  async destroy(): Promise<void> {
    await this.stopBackgroundTask();

    // 释放封面缓存，PixelMap 需要显式 release
    if (this.cachedCoverPixelMap) {
      this.cachedCoverPixelMap.release();
      this.cachedCoverPixelMap = null;
      this.cachedCoverUrl = '';
    }

    if (this.session) {
      try {
        await this.session.deactivate();
        await this.session.destroy();
        this.session = null;
        console.info(TAG, 'AVSession destroyed');
      } catch (err) {
        console.error(TAG, 'Failed to destroy AVSession:', JSON.stringify(err));
      }
    }

    // 清空引用，防止 Ability 销毁后仍被单例持有
    this.wantAgentInstance = null;
    this.context = null;
  }
}
