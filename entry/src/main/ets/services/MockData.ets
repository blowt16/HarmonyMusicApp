import { Song } from '../models/MusicModel';

/**
 * 本地示例曲：项目自行生成的 24 秒无版权环境循环，断网时仍可播放。
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

export const LOCAL_FALLBACK_SONGS: Song[] = [LOCAL_DEMO_SONG];
