/**
 * 文件：MusicModel.ets
 * 职责：定义页面、服务和接口之间共享的数据结构。
 *
 * 这里的 Song 是「项目自己的歌曲模型」，不是网易云接口的原始结构；
 * ApiService 负责把接口字段映射成这个模型，页面只认这里定义的类型。
 */

/**
 * 歌曲。
 * 同时兼容在线歌曲和本地示例音频：
 * - 在线歌曲：id 为正数，url / coverUrl / availableQualities 来自接口；
 * - 本地示例：id 为 -1，assetName 指向 rawfile 中的音频。
 */
export interface Song {
  id: number; // 歌曲 id，本地示例用 -1
  name: string;
  artist: string; // 多个歌手用 / 拼接
  album: string;
  albumId: number;
  duration: number; // 毫秒
  url: string; // 在线播放地址，播放前由 ApiService 填充
  coverUrl: string;
  lyric: string;
  availableQualities?: SongQualityInfo[]; // 接口返回的可用音质列表
  assetName?: string; // rawfile 资源名，例如 demo_loop.wav；有值表示本地示例
  fee?: number; // 0 免费、1 VIP、8 部分免费
  playable?: boolean; // 接口侧计算的可播放标记，VIP/付费通常为 false
  maxBr?: number; // 可播放的最高码率，用于把音质请求压到合理范围
}

/**
 * 歌单（包含完整歌曲列表），主要用于详情页。
 */
export interface Playlist {
  id: number;
  name: string;
  coverUrl: string;
  songCount: number;
  songs: Song[];
}

/**
 * 歌单摘要信息，用于列表 / 推荐位，不携带歌曲列表。
 */
export interface PlaylistInfo {
  id: number;
  name: string;
  coverUrl: string;
  songCount: number;
  playCount: number;
  creator: string;
  isAlbum?: boolean; // true 表示这是专辑，详情走 getAlbumDetail
}

/**
 * 歌单搜索结果。
 */
export interface PlaylistSearchResult {
  playlists: PlaylistInfo[];
  total: number;
}

/**
 * 歌单详情：摘要 + 完整歌曲列表。
 */
export interface PlaylistDetail {
  info: PlaylistInfo;
  songs: Song[];
}

/**
 * 歌曲搜索结果。
 * error 用来区分「没有搜到」和「网络/接口失败」，搜索页据此显示不同空态。
 */
export interface SearchResult {
  songs: Song[];
  total: number;
  page: number;
  error?: boolean;
}

/**
 * 一行歌词：时间（秒）+ 文本。
 */
export interface LyricLine {
  time: number;
  text: string;
}

/**
 * 播放模式。
 * 注意：当前实现中 SEQUENCE 和 LOOP 的行为相同，都会首尾环绕。
 */
export enum PlayMode {
  SEQUENCE = 'sequence',
  LOOP = 'loop',
  RANDOM = 'random',
  SINGLE = 'single'
}

/**
 * App 统一对外暴露的播放状态，屏蔽 AVPlayer 自己的底层状态机。
 */
export enum PlayerState {
  PLAYING = 'playing',
  PAUSED = 'paused',
  STOPPED = 'stopped',
  LOADING = 'loading'
}

/**
 * 音质档位，枚举值直接使用码率（bps），方便接口请求和比较。
 */
export enum AudioQuality {
  STANDARD = 128000,   // 标准
  HIGHER = 192000,     // 较高
  EXHIGH = 320000,     // 极高
  LOSSLESS = 999000,   // 无损
}

/**
 * 某一档音质的详细信息。
 */
export interface SongQualityInfo {
  level: AudioQuality;
  br: number; // 码率
  size: number; // 文件大小，接口可能为 0
  sr: number; // 采样率
}

/**
 * 沉浸光感效果档位，数值越大光效越强。
 */
export enum EffectLevel {
  OFF = 0,
  LOW = 1,
  MEDIUM = 2,
  HIGH = 3
}
