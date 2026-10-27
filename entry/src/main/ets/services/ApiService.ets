import { Song, SearchResult, LyricLine, AudioQuality, SongQualityInfo, PlaylistInfo, PlaylistSearchResult, PlaylistDetail } from '../models/MusicModel';
import http from '@ohos.net.http';
import { CacheService } from './CacheService';

/**
 * 文件：ApiService.ets
 * 职责：封装所有网易云公开接口的请求、字段映射、缓存和错误兜底。
 *
 * 页面不直接发 HTTP，而是调用这里的方法拿项目自己的 Song / PlaylistInfo。
 * 每个接口基本遵循同一套路：
 * 1. 先拼缓存 key，命中 CacheService 就直接返回；
 * 2. 发请求，连接 / 读取各 10 秒超时；
 * 3. 同时检查 HTTP 200 和业务 code 200；
 * 4. 把接口字段映射成项目模型，并计算 playable / maxBr；
 * 5. 成功写缓存；失败返回空数组 / null，不把异常抛给页面。
 */

const API_ORIGIN: string = 'https://music.163.com';
const BASE_URL: string = `${API_ORIGIN}/api/cloudsearch/pc`;
const LYRIC_BASE: string = `${API_ORIGIN}/api/song/lyric`;

// ===== 搜索 / 歌曲接口的原始响应结构 =====
// 这些 interface 只描述接口字段，和页面使用的 Song 模型分开，避免页面被接口格式绑死

interface ArtistItem {
  id: number;
  name: string;
}

interface AlbumItem {
  id: number;
  name: string;
  picUrl: string;
}

interface QualityDetail {
  br: number;
  size: number;
  sr: number;
}

/**
 * 接口返回的版权 / 权限信息。
 * pl = 可播放的最高码率，0 通常表示不可播；
 * fee：0 免费、1 VIP、8 部分免费（项目里按“可播”处理）。
 */
interface SongPrivilege {
  pl?: number;
  dl?: number;
  st?: number;
  fee?: number;
  maxbr?: number;
}

interface SongItem {
  id: number;
  name: string;
  ar: ArtistItem[];
  al: AlbumItem;
  dt: number;
  l?: QualityDetail;
  m?: QualityDetail;
  h?: QualityDetail;
  sq?: QualityDetail;
  hr?: QualityDetail;
  fee?: number;
  privilege?: SongPrivilege;
}

interface SearchResultResult {
  songs: SongItem[];
  songCount: number;
}

interface SearchResultData {
  result: SearchResultResult;
  code: number;
}

interface LyricLrc {
  lyric: string;
}

interface LyricData {
  lrc: LyricLrc;
  code: number;
}

interface DetailArtistItem {
  id: number;
  name: string;
}

interface DetailAlbumItem {
  id: number;
  name: string;
  picUrl: string;
  picId: number;
}

interface DetailSongItem {
  id: number;
  name: string;
  artists: DetailArtistItem[];
  album: DetailAlbumItem;
  duration: number;
  fee?: number;
  l?: QualityDetail;
  m?: QualityDetail;
  h?: QualityDetail;
  sq?: QualityDetail;
}

interface SongDetailData {
  songs: DetailSongItem[];
}

interface SongUrlItem {
  id: number;
  url: string;
  br: number;
  level: string;
  type: string;
}

interface SongUrlData {
  code: number;
  data: SongUrlItem[];
}

// ===== 歌单 API 响应类型 =====

interface PlaylistSearchApiCreator {
  nickname: string;
}

interface PlaylistSearchApiItem {
  id: number;
  name: string;
  coverImgUrl: string;
  trackCount: number;
  playCount: number;
  creator: PlaylistSearchApiCreator;
}

interface PlaylistSearchApiResult {
  playlists: PlaylistSearchApiItem[];
  playlistCount: number;
}

interface PlaylistSearchApiResponse {
  code: number;
  result: PlaylistSearchApiResult;
}

interface PlaylistDetailApiCreator {
  nickname: string;
}

interface PlaylistDetailTrackArtist {
  id: number;
  name: string;
}

interface PlaylistDetailTrackAlbum {
  id: number;
  name: string;
  picUrl: string;
}

interface PlaylistDetailTrack {
  id: number;
  name: string;
  ar: PlaylistDetailTrackArtist[];
  al: PlaylistDetailTrackAlbum;
  dt: number;
  fee?: number;
  l?: QualityDetail;
  m?: QualityDetail;
  h?: QualityDetail;
  sq?: QualityDetail;
  hr?: QualityDetail;
}

interface PlaylistDetailTrackId {
  id: number;
}

interface PlaylistDetailApiData {
  id: number;
  name: string;
  coverImgUrl: string;
  trackCount: number;
  playCount: number;
  creator: PlaylistDetailApiCreator;
  tracks: PlaylistDetailTrack[];
  trackIds: PlaylistDetailTrackId[];
}

interface PlaylistDetailApiResponse {
  code: number;
  playlist: PlaylistDetailApiData;
}

// ===== 个性化推荐 / 新歌接口的响应结构 =====

interface PersonalizedPlaylistItem {
  id: number;
  name: string;
  picUrl: string;
  trackCount: number;
  playCount: number;
}

interface PersonalizedApiResponse {
  code: number;
  result: PersonalizedPlaylistItem[];
}

interface PersonalizedNewSongArtist {
  name: string;
}

interface PersonalizedNewSongAlbum {
  id: number;
  name: string;
  picUrl: string;
}

interface PersonalizedNewSongMusic {
  br: number;
  size: number;
  sr: number;
}

interface PersonalizedNewSongPrivilege {
  pl?: number;
}

interface PersonalizedNewSongDetail {
  id: number;
  name: string;
  duration: number;
  fee?: number;
  artists: PersonalizedNewSongArtist[];
  album: PersonalizedNewSongAlbum;
  lMusic?: PersonalizedNewSongMusic | null;
  mMusic?: PersonalizedNewSongMusic | null;
  hMusic?: PersonalizedNewSongMusic | null;
  sqMusic?: PersonalizedNewSongMusic | null;
  privilege?: PersonalizedNewSongPrivilege;
}

interface PersonalizedNewSongItem {
  id: number;
  name: string;
  picUrl: string;
  song: PersonalizedNewSongDetail;
}

interface PersonalizedNewSongResponse {
  code: number;
  result: PersonalizedNewSongItem[];
}

// ===== 专辑推荐 API =====

interface NewAlbumArtist {
  id: number;
  name: string;
}

interface NewAlbumItem {
  id: number;
  name: string;
  picUrl: string;
  artistName: string;
  artists: NewAlbumArtist[];
}

interface NewAlbumApiResponse {
  code: number;
  result: NewAlbumItem[];
}

/**
 * 网络数据服务（单例）。
 * 所有接口共享一个 HttpRequest 实例和一份内存缓存。
 */
export class ApiService {
  private static instance: ApiService;
  private httpRequest: http.HttpRequest;
  private cache: CacheService = CacheService.getInstance();

  // 不同数据的缓存时长：变化越快，TTL 越短
  private static readonly TTL_SEARCH = 3 * 60 * 1000;      // 搜索结果 3 分钟
  private static readonly TTL_LYRIC = 30 * 60 * 1000;       // 歌词 30 分钟
  private static readonly TTL_SONG_DETAIL = 15 * 60 * 1000;  // 歌曲详情 15 分钟
  private static readonly TTL_SONG_URL = 5 * 60 * 1000;      // 播放链接 5 分钟
  private static readonly TTL_PLAYLIST = 10 * 60 * 1000;     // 歌单详情 10 分钟
  private static readonly TTL_PLAYLIST_SEARCH = 5 * 60 * 1000; // 歌单搜索 5 分钟
  private static readonly TTL_TOP_PLAYLIST = 10 * 60 * 1000; // 热门歌单 10 分钟

  // 网络超时，避免断网时一直等待
  private static readonly CONNECT_TIMEOUT = 10000;
  private static readonly READ_TIMEOUT = 10000;

  private constructor() {
    this.httpRequest = http.createHttp();
  }

  public static getInstance(): ApiService {
    if (!ApiService.instance) {
      ApiService.instance = new ApiService();
    }
    return ApiService.instance;
  }

  // 构建通用请求头 — 模拟浏览器行为，避免被 WAF 拦截
  private buildCommonHeaders(): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Referer'] = 'https://music.163.com';
    headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    headers['Accept'] = 'application/json, text/plain, */*';
    headers['Accept-Language'] = 'zh-CN,zh;q=0.9';
    headers['Cookie'] = 'appver=2.0.2';
    return headers;
  }

  private maxQualityBr(qualities: SongQualityInfo[]): number {
    let maxBr: number = 0;
    for (const q of qualities) {
      if (q.br > maxBr) {
        maxBr = q.br;
      }
    }
    return maxBr;
  }

  /**
   * 搜索歌曲。
   * 使用 POST 表单请求 cloudsearch 接口，返回结果会先按关键词 / 页码 / 条数缓存。
   * 失败时返回 error: true 的空结果，让搜索页区分「无结果」和「网络失败」。
   *
   * @param keyword 搜索关键词
   * @param page 页码，从 1 开始
   * @param limit 每页条数
   */
  async searchMusic(keyword: string, page: number = 1, limit: number = 20): Promise<SearchResult> {
    // 缓存 key 带上全部参数，不同分页 / 条数不会互相覆盖
    const cacheKey = `search:${keyword}:p${page}:l${limit}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as SearchResult;
    }

    try {
      const url: string = BASE_URL;
      const offset: number = (page - 1) * limit;
      // 网易云搜索接口用表单编码，type=1 表示搜索单曲
      const body: string = `s=${encodeURIComponent(keyword)}&type=1&limit=${limit}&offset=${offset}`;

      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.POST,
        connectTimeout: ApiService.CONNECT_TIMEOUT,
        readTimeout: ApiService.READ_TIMEOUT,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': 'https://music.163.com',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9',
          'Cookie': 'appver=2.0.2'
        },
        extraData: body
      });

      // 双重校验：HTTP 200 只代表请求成功，业务 code 200 才代表接口真的返回了数据
      if (response.responseCode === 200) {
        const data: SearchResultData = JSON.parse(response.result as string) as SearchResultData;
        if (data.code === 200 && data.result && data.result.songs) {
          const songs: Song[] = data.result.songs.map((item: SongItem): Song => {
            const artistNames: string = item.ar ? item.ar.map((a: ArtistItem): string => a.name).join('/') : '未知';
            const albumName: string = item.al ? item.al.name : '未知';
            const coverUrl: string = (item.al && item.al.picUrl) ? item.al.picUrl.replace('http://', 'https://') : '';

            // 接口用 l / m / h / sq 四组字段表示四档音质，按存在与否收集
            const qualities: SongQualityInfo[] = [];
            if (item.l) {
              qualities.push({ level: AudioQuality.STANDARD, br: item.l.br, size: item.l.size, sr: item.l.sr });
            }
            if (item.m) {
              qualities.push({ level: AudioQuality.HIGHER, br: item.m.br, size: item.m.size, sr: item.m.sr });
            }
            if (item.h) {
              qualities.push({ level: AudioQuality.EXHIGH, br: item.h.br, size: item.h.size, sr: item.h.sr });
            }
            if (item.sq) {
              qualities.push({ level: AudioQuality.LOSSLESS, br: item.sq.br, size: item.sq.size, sr: item.sq.sr });
            }

            // 可播放判定：有可播码率，或免费（0），或部分免费（8）
            const playMaxBr: number = item.privilege && item.privilege.pl ? item.privilege.pl : 0;
            const fee: number = item.fee !== undefined ? item.fee : 0;
            const playable: boolean = playMaxBr > 0 || fee === 0 || fee === 8;

            return {
              id: item.id,
              name: item.name,
              artist: artistNames,
              album: albumName,
              albumId: item.al ? item.al.id : 0,
              duration: item.dt || 0,
              url: '',
              coverUrl: coverUrl,
              lyric: '',
              availableQualities: qualities,
              fee,
              playable,
              maxBr: playMaxBr > 0 ? playMaxBr : this.maxQualityBr(qualities)
            };
          });

          const result: SearchResult = { songs, total: data.result.songCount || 0, page };
          this.cache.set(cacheKey, result, ApiService.TTL_SEARCH);
          return result;
        }
      }
      // 业务失败 / 空响应：标记 error，搜索页会显示“网络连接失败”而不是“无结果”
      return { songs: [], total: 0, page, error: true };
    } catch (error) {
      console.error('Search music error:', error);
      return { songs: [], total: 0, page, error: true };
    }
  }

  /**
   * 获取歌曲播放地址。
   * 先按用户选择的音质请求；如果歌曲最高码率更低，就把请求码率压到 maxBr，
   * 避免先请求 320k 再回退。高音质拿不到 URL 时自动回退标准音质。
   *
   * @param songId 歌曲 id
   * @param quality 目标音质
   * @param maxBr 歌曲允许的最高码率，0 表示不限制
   * @returns 播放 URL；失败返回空字符串
   */
  async getSongUrl(songId: number, quality: AudioQuality = AudioQuality.EXHIGH, maxBr: number = 0): Promise<string> {
    let effectiveQuality: number = quality;
    if (maxBr > 0 && effectiveQuality > maxBr) {
      effectiveQuality = maxBr;
    }
    const cacheKey = `songurl:${songId}:${effectiveQuality}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as string;
    }

    try {
      const url: string = `${API_ORIGIN}/api/song/enhance/player/url?id=${songId}&ids=[${songId}]&br=${effectiveQuality}`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: ApiService.CONNECT_TIMEOUT,
        readTimeout: ApiService.READ_TIMEOUT,
        header: this.buildCommonHeaders()
      });

      if (response.responseCode === 200) {
        const data: SongUrlData = JSON.parse(response.result as string) as SongUrlData;
        if (data.code === 200 && data.data && data.data.length > 0) {
          const songData: SongUrlItem = data.data[0];
          if (songData.url) {
            const songUrl: string = songData.url;
            const finalUrl: string = songUrl.replace('http://', 'https://');
            console.info('Got song url, br:', songData.br, 'level:', songData.level, 'type:', songData.type);
            this.cache.set(cacheKey, finalUrl, ApiService.TTL_SONG_URL);
            return finalUrl;
          }
        }
      }

      // 高音质失败时，尝试标准音质；标准音质也失败才返回空字符串
      if (effectiveQuality !== AudioQuality.STANDARD) {
        console.error('Failed to get high quality url, trying standard quality');
        return this.getSongUrl(songId, AudioQuality.STANDARD);
      }

      console.error('Failed to get song url for id:', songId);
      return '';
    } catch (error) {
      console.error('Get song url error:', error);
      return '';
    }
  }

  /**
   * 获取并解析歌词。
   * 接口返回的是 LRC 文本，parseLyric 会把它转成带时间戳的数组。
   * 没有歌词 / 请求失败都返回空数组，页面显示“暂无歌词”。
   */
  async getLyric(songId: number): Promise<LyricLine[]> {
    const cacheKey = `lyric:${songId}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as LyricLine[];
    }

    try {
      const url: string = `${LYRIC_BASE}?id=${songId}&lv=1&kv=1&tv=-1`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: ApiService.CONNECT_TIMEOUT,
        readTimeout: ApiService.READ_TIMEOUT,
        header: this.buildCommonHeaders()
      });

      if (response.responseCode === 200) {
        const data: LyricData = JSON.parse(response.result as string) as LyricData;
        if (data.code === 200 && data.lrc && data.lrc.lyric) {
          const lyrics = this.parseLyric(data.lrc.lyric);
          this.cache.set(cacheKey, lyrics, ApiService.TTL_LYRIC);
          return lyrics;
        }
      }
      return [];
    } catch (error) {
      console.error('Get lyric error:', error);
      return [];
    }
  }

  /**
   * 解析逐行 LRC 歌词。
   * 只处理 `[分:秒.毫秒]歌词` 这种格式；空行和没有时间戳的行会被忽略。
   * 返回前按时间升序排序，PlayerService 才能从后往前快速找当前行。
   */
  private parseLyric(lyricStr: string): LyricLine[] {
    const lines: LyricLine[] = [];
    const lyricLines: string[] = lyricStr.split('\n');

    for (const line of lyricLines) {
      const match: RegExpMatchArray | null = line.match(/\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)/);
      if (match) {
        const minutes: number = parseInt(match[1]);
        const seconds: number = parseInt(match[2]);
        const milliseconds: number = parseInt(match[3]);
        const time: number = minutes * 60 + seconds + milliseconds / 1000;
        const text: string = match[4].trim();
        if (text) {
          lines.push({ time, text });
        }
      }
    }

    return lines.sort((a: LyricLine, b: LyricLine): number => a.time - b.time);
  }

  /**
   * 获取单曲详情（歌名、歌手、专辑、时长、版权标记）。
   * 歌单批量补歌时也会复用类似的字段映射逻辑。
   */
  async getSongDetail(songId: number): Promise<Song | null> {
    const cacheKey = `detail:${songId}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as Song;
    }

    try {
      const url: string = `${API_ORIGIN}/api/song/detail?id=${songId}&ids=[${songId}]`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: ApiService.CONNECT_TIMEOUT,
        readTimeout: ApiService.READ_TIMEOUT,
        header: this.buildCommonHeaders()
      });

      if (response.responseCode === 200) {
        const data: SongDetailData = JSON.parse(response.result as string) as SongDetailData;
        if (data && data.songs && data.songs.length > 0) {
          const songData: DetailSongItem = data.songs[0];
          const artistNames: string = songData.artists ? songData.artists.map((a: DetailArtistItem): string => a.name).join('/') : '未知';
          const albumName: string = songData.album ? songData.album.name : '未知';
          const coverUrl: string = songData.album ? (songData.album.picUrl || '') : '';

          const fee: number = songData.fee !== undefined ? songData.fee : 0;
          const song: Song = {
            id: songData.id,
            name: songData.name,
            artist: artistNames,
            album: albumName,
            albumId: songData.album ? songData.album.id : 0,
            duration: songData.duration || 0,
            url: '',
            coverUrl: coverUrl,
            lyric: '',
            fee,
            playable: fee === 0 || fee === 8
          };
          this.cache.set(cacheKey, song, ApiService.TTL_SONG_DETAIL);
          return song;
        }
      }
      return null;
    } catch (error) {
      console.error('Get song detail error:', error);
      return null;
    }
  }

  // ===== 歌单相关 API =====

  /**
   * 搜索歌单（type=1000），用于搜索页的歌单结果。
   */
  async searchPlaylists(keyword: string, limit: number = 10): Promise<PlaylistSearchResult> {
    const cacheKey = `plsearch:${keyword}:l${limit}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as PlaylistSearchResult;
    }

    try {
      const url: string = BASE_URL;
      const body: string = `s=${encodeURIComponent(keyword)}&type=1000&limit=${limit}&offset=0`;

      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.POST,
        connectTimeout: ApiService.CONNECT_TIMEOUT,
        readTimeout: ApiService.READ_TIMEOUT,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': 'https://music.163.com',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9',
          'Cookie': 'appver=2.0.2'
        },
        extraData: body
      });

      if (response.responseCode === 200) {
        const data: PlaylistSearchApiResponse = JSON.parse(response.result as string) as PlaylistSearchApiResponse;
        if (data.code === 200 && data.result && data.result.playlists) {
          const playlists: PlaylistInfo[] = data.result.playlists.map((item: PlaylistSearchApiItem): PlaylistInfo => {
            return {
              id: item.id,
              name: item.name,
              coverUrl: (item.coverImgUrl || '').replace('http://', 'https://'),
              songCount: item.trackCount || 0,
              playCount: item.playCount || 0,
              creator: item.creator ? item.creator.nickname : '未知'
            };
          });
          const result: PlaylistSearchResult = { playlists, total: data.result.playlistCount || 0 };
          this.cache.set(cacheKey, result, ApiService.TTL_PLAYLIST_SEARCH);
          return result;
        }
      }
      return { playlists: [], total: 0 };
    } catch (error) {
      console.error('Search playlists error:', error);
      return { playlists: [], total: 0 };
    }
  }

  /**
   * 获取歌单详情和完整歌曲列表。
   *
   * 接口的 tracks 通常只有前 10 首，但 trackIds 包含完整 id 列表。
   * 所以先映射 tracks，再用 trackIds 找出缺失的 id，每 100 首一批补全，
   * 这样歌单页才能显示全部歌曲。
   */
  async getPlaylistDetail(playlistId: number): Promise<PlaylistDetail | null> {
    const cacheKey = `pldetail:${playlistId}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as PlaylistDetail;
    }

    try {
      const url: string = `${API_ORIGIN}/api/v3/playlist/detail`;
      const body: string = `id=${playlistId}&n=1000&s=0`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.POST,
        connectTimeout: ApiService.CONNECT_TIMEOUT,
        readTimeout: ApiService.READ_TIMEOUT,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': 'https://music.163.com',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9',
          'Cookie': 'appver=2.0.2'
        },
        extraData: body
      });

      if (response.responseCode === 200) {
        const data: PlaylistDetailApiResponse = JSON.parse(response.result as string) as PlaylistDetailApiResponse;
        if (data.code === 200 && data.playlist) {
          const pl: PlaylistDetailApiData = data.playlist;

          // 第一步：先映射接口直接返回的 tracks（通常只有前 10 首）
          let songs: Song[] = pl.tracks.map((track: PlaylistDetailTrack): Song => {
            const artistNames: string =
            track.ar && track.ar.length > 0 ? track.ar.map((a: PlaylistDetailTrackArtist): string => a.name).join('/') :
              '未知';
            const albumName: string = track.al ? track.al.name : '未知';
            const coverUrl: string = track.al ? (track.al.picUrl || '').replace('http://', 'https://') : '';

            const qualities: SongQualityInfo[] = [];
            if (track.l) {
              qualities.push({ level: AudioQuality.STANDARD, br: track.l.br, size: track.l.size, sr: track.l.sr });
            }
            if (track.m) {
              qualities.push({ level: AudioQuality.HIGHER, br: track.m.br, size: track.m.size, sr: track.m.sr });
            }
            if (track.h) {
              qualities.push({ level: AudioQuality.EXHIGH, br: track.h.br, size: track.h.size, sr: track.h.sr });
            }
            if (track.sq) {
              qualities.push({ level: AudioQuality.LOSSLESS, br: track.sq.br, size: track.sq.size, sr: track.sq.sr });
            }
            const fee: number = track.fee !== undefined ? track.fee : 0;
            const playable: boolean = fee === 0 || fee === 8;

            return {
              id: track.id,
              name: track.name,
              artist: artistNames,
              album: albumName,
              albumId: track.al ? track.al.id : 0,
              duration: track.dt || 0,
              url: '',
              coverUrl: coverUrl,
              lyric: '',
              availableQualities: qualities,
              fee,
              playable,
              maxBr: this.maxQualityBr(qualities)
            };
          });

          // 第二步：tracks 不完整时，用 trackIds 找出缺失 id 并分批补全
          const totalCount: number = pl.trackCount || 0;
          if (songs.length < totalCount && pl.trackIds && pl.trackIds.length > 0) {
            const existingIds: Set<number> = new Set();
            for (const s of songs) {
              existingIds.add(s.id);
            }
            // 收集缺失的 trackId
            const missingIds: number[] = [];
            for (const tid of pl.trackIds) {
              if (!existingIds.has(tid.id)) {
                missingIds.push(tid.id);
              }
            }
            // 分批请求（每批最多 100 首）
            const batchSize: number = 100;
            for (let i = 0; i < missingIds.length; i += batchSize) {
              const batch: number[] = missingIds.slice(i, i + batchSize);
              const batchSongs: Song[] = await this.batchGetSongDetails(batch);
              songs = songs.concat(batchSongs);
            }
          }

          const result: PlaylistDetail = {
            info: {
              id: pl.id,
              name: pl.name,
              coverUrl: (pl.coverImgUrl || '').replace('http://', 'https://'),
              songCount: totalCount,
              playCount: pl.playCount || 0,
              creator: pl.creator ? pl.creator.nickname : '未知'
            },
            songs
          };
          this.cache.set(cacheKey, result, ApiService.TTL_PLAYLIST);
          return result;
        }
      }
      return null;
    } catch (error) {
      console.error('Get playlist detail error:', error);
      return null;
    }
  }

  /**
   * 批量获取歌曲详情。
   * 调用方负责把 id 按 100 首分批传入；失败返回空数组，不阻塞其他批次。
   */
  private async batchGetSongDetails(ids: number[]): Promise<Song[]> {
    try {
      const idsStr: string = JSON.stringify(ids);
      const url: string = `${API_ORIGIN}/api/song/detail`;
      const body: string = `ids=${encodeURIComponent(idsStr)}`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.POST,
        connectTimeout: ApiService.CONNECT_TIMEOUT,
        readTimeout: ApiService.READ_TIMEOUT,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': 'https://music.163.com',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9',
          'Cookie': 'appver=2.0.2'
        },
        extraData: body
      });

      if (response.responseCode === 200) {
        const data: SongDetailData = JSON.parse(response.result as string) as SongDetailData;
        if (data && data.songs) {
          return data.songs.map((item: DetailSongItem): Song => {
            const artistNames: string = item.artists ? item.artists.map((a: DetailArtistItem): string => a.name).join('/') : '未知';
            const albumName: string = item.album ? item.album.name : '未知';
            const coverUrl: string = item.album ? (item.album.picUrl || '').replace('http://', 'https://') : '';
            const qualities: SongQualityInfo[] = [];
            if (item.l) {
              qualities.push({ level: AudioQuality.STANDARD, br: item.l.br, size: item.l.size, sr: item.l.sr });
            }
            if (item.m) {
              qualities.push({ level: AudioQuality.HIGHER, br: item.m.br, size: item.m.size, sr: item.m.sr });
            }
            if (item.h) {
              qualities.push({ level: AudioQuality.EXHIGH, br: item.h.br, size: item.h.size, sr: item.h.sr });
            }
            if (item.sq) {
              qualities.push({ level: AudioQuality.LOSSLESS, br: item.sq.br, size: item.sq.size, sr: item.sq.sr });
            }
            const fee: number = item.fee !== undefined ? item.fee : 0;
            return {
              id: item.id,
              name: item.name,
              artist: artistNames,
              album: albumName,
              albumId: item.album ? item.album.id : 0,
              duration: item.duration || 0,
              url: '',
              coverUrl: coverUrl,
              lyric: '',
              availableQualities: qualities,
              fee,
              playable: fee === 0 || fee === 8,
              maxBr: this.maxQualityBr(qualities)
            };
          });
        }
      }
      return [];
    } catch (error) {
      console.error('Batch get song details error:', error);
      return [];
    }
  }

  /**
   * 获取首页推荐歌单（个性化歌单接口）。
   * 结果缓存 10 分钟，避免每次回首页都重新请求。
   */
  async getPersonalizedPlaylists(limit: number = 10): Promise<PlaylistInfo[]> {
    const cacheKey = `personalized:l${limit}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as PlaylistInfo[];
    }

    try {
      const url: string = `${API_ORIGIN}/api/personalized/playlist?limit=${limit}`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: ApiService.CONNECT_TIMEOUT,
        readTimeout: ApiService.READ_TIMEOUT,
        header: {
          'Referer': 'https://music.163.com'
        }
      });

      if (response.responseCode === 200) {
        const data: PersonalizedApiResponse = JSON.parse(response.result as string) as PersonalizedApiResponse;
        if (data.code === 200 && data.result) {
          const playlists = data.result.map((item: PersonalizedPlaylistItem): PlaylistInfo => {
            return {
              id: item.id,
              name: item.name,
              coverUrl: (item.picUrl || '').replace('http://', 'https://'),
              songCount: item.trackCount || 0,
              playCount: item.playCount || 0,
              creator: ''
            };
          });
          this.cache.set(cacheKey, playlists, ApiService.TTL_TOP_PLAYLIST);
          return playlists;
        }
      }
      return [];
    } catch (error) {
      console.error('Get personalized playlists error:', error);
      return [];
    }
  }

  /**
   * 获取首页「为你推荐」歌曲。
   * 新歌接口返回的字段和搜索接口不同（lMusic/mMusic/hMusic/sqMusic），
   * 这里单独映射一次。该接口目前不写缓存，保证每次刷新能看到新推荐。
   */
  async getRecommendedSongs(limit: number = 12): Promise<Song[]> {
    try {
      const url: string = `${API_ORIGIN}/api/personalized/newsong?limit=${limit}`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: ApiService.CONNECT_TIMEOUT,
        readTimeout: ApiService.READ_TIMEOUT,
        header: {
          'Referer': 'https://music.163.com'
        }
      });

      if (response.responseCode === 200) {
        const data: PersonalizedNewSongResponse = JSON.parse(response.result as string) as PersonalizedNewSongResponse;
        if (data.code === 200 && data.result) {
          const songs: Song[] = [];
          for (const item of data.result) {
            const detail: PersonalizedNewSongDetail = item.song;
            if (!detail) {
              continue;
            }
            const artistNames: string = detail.artists ? detail.artists.map((a: PersonalizedNewSongArtist): string => a.name).join('/') : '未知';
            const albumName: string = detail.album ? detail.album.name : '未知';
            const coverUrl: string = ((detail.album && detail.album.picUrl) || item.picUrl || '').replace('http://', 'https://');

            const qualities: SongQualityInfo[] = [];
            if (detail.lMusic) {
              qualities.push({ level: AudioQuality.STANDARD, br: detail.lMusic.br, size: detail.lMusic.size, sr: detail.lMusic.sr });
            }
            if (detail.mMusic) {
              qualities.push({ level: AudioQuality.HIGHER, br: detail.mMusic.br, size: detail.mMusic.size, sr: detail.mMusic.sr });
            }
            if (detail.hMusic) {
              qualities.push({ level: AudioQuality.EXHIGH, br: detail.hMusic.br, size: detail.hMusic.size, sr: detail.hMusic.sr });
            }
            if (detail.sqMusic) {
              qualities.push({ level: AudioQuality.LOSSLESS, br: detail.sqMusic.br, size: detail.sqMusic.size, sr: detail.sqMusic.sr });
            }

            const playMaxBr: number = detail.privilege && detail.privilege.pl ? detail.privilege.pl : 0;
            const fee: number = detail.fee !== undefined ? detail.fee : 0;
            const playable: boolean = playMaxBr > 0 || fee === 0 || fee === 8;

            songs.push({
              id: detail.id,
              name: detail.name,
              artist: artistNames,
              album: albumName,
              albumId: detail.album ? detail.album.id : 0,
              duration: detail.duration || 0,
              url: '',
              coverUrl: coverUrl,
              lyric: '',
              availableQualities: qualities,
              fee,
              playable,
              maxBr: playMaxBr > 0 ? playMaxBr : this.maxQualityBr(qualities)
            });
          }
          return songs;
        }
      }
      return [];
    } catch (error) {
      console.error('Get recommended songs error:', error);
      return [];
    }
  }

  /**
   * 获取专辑详情。
   *
   * 专辑详情接口需要登录，这里改走公开的搜索接口：
   * 用「专辑名 + 歌手名」搜索，再按专辑名 / 歌手名过滤；
   * 如果过滤后为空，退回搜索结果前 10 首，保证页面有内容。
   */
  async getAlbumDetail(albumId: number, albumName: string, artistName: string, coverUrl: string): Promise<PlaylistDetail | null> {
    const cacheKey = `album:${albumId}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as PlaylistDetail;
    }

    try {
      // 用专辑名+歌手名搜索歌曲
      const keyword: string = `${albumName} ${artistName}`;
      const searchResult = await this.searchMusic(keyword, 1, 30);

      if (searchResult.songs.length > 0) {
        // 过滤：只保留专辑名或歌手名匹配的歌曲
        const filtered: Song[] = searchResult.songs.filter((song: Song): boolean => {
          const artistMatch: boolean = song.artist.includes(artistName) || artistName.includes(song.artist);
          const albumMatch: boolean = song.album.includes(albumName) || albumName.includes(song.album);
          return artistMatch || albumMatch;
        });

        // 过滤后没有结果时不要返回空页，退回搜索结果前 10 首作为近似专辑
        const songs: Song[] = filtered.length > 0 ? filtered : searchResult.songs.slice(0, 10);

        const result: PlaylistDetail = {
          info: {
            id: albumId,
            name: albumName,
            coverUrl: coverUrl,
            songCount: songs.length,
            playCount: 0,
            creator: artistName
          },
          songs
        };
        this.cache.set(cacheKey, result, 10 * 60 * 1000);
        return result;
      }
      return null;
    } catch (error) {
      console.error('Get album detail error:', error);
      return null;
    }
  }

  /**
   * 获取首页新专辑推荐。
   * 返回的是 PlaylistInfo，isAlbum = true，歌单详情页据此走 getAlbumDetail。
   */
  async getNewAlbums(limit: number = 8): Promise<PlaylistInfo[]> {
    const cacheKey = `newalbums:l${limit}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as PlaylistInfo[];
    }

    try {
      const url: string = `${API_ORIGIN}/api/personalized/newalbum?limit=${limit}`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: ApiService.CONNECT_TIMEOUT,
        readTimeout: ApiService.READ_TIMEOUT,
        header: {
          'Referer': 'https://music.163.com'
        }
      });

      if (response.responseCode === 200) {
        const data: NewAlbumApiResponse = JSON.parse(response.result as string) as NewAlbumApiResponse;
        if (data.code === 200 && data.result) {
          const albums: PlaylistInfo[] = data.result.map((item: NewAlbumItem): PlaylistInfo => {
            return {
              id: item.id,
              name: item.name,
              coverUrl: (item.picUrl || '').replace('http://', 'https://'),
              songCount: 0,
              playCount: 0,
              creator: item.artistName || '未知',
              isAlbum: true
            };
          });
          this.cache.set(cacheKey, albums, 10 * 60 * 1000);
          return albums;
        }
      }
      return [];
    } catch (error) {
      console.error('Get new albums error:', error);
      return [];
    }
  }
}
