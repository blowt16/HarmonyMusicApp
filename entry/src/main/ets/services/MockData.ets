import { Song } from '../models/MusicModel';

/**
 * 文件：MockData.ets
 * 职责：提供不依赖网络的本地示例数据，保证断网时页面仍有内容可演示。
 *
 * 示例音频放在 resources/rawfile/demo_loop.wav，
 * 播放时由 PlayerService 通过 assetName 走 rawfile fdSrc 分支。
 */

/**
 * 本地示例曲：项目自行生成的 24 秒无版权环境循环，断网时仍可播放。
 * id 用 -1，和在线歌曲的正数 id 区分开。
 */
export const LOCAL_DEMO_SONG: Song = {
  id: -1,
  name: '清听 · 示例曲',
  artist: '清听',
  album: '本地示例',
  albumId: 0,
  duration: 24000,
  url: '',
  coverUrl: '',
  lyric: '',
  assetName: 'demo_loop.wav'
};

// 首页 / 搜索失败时使用的兜底列表；目前只有一首示例曲
export const LOCAL_FALLBACK_SONGS: Song[] = [LOCAL_DEMO_SONG];
