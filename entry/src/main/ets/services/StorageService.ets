import { Song, AudioQuality, EffectLevel } from '../models/MusicModel';
import dataStorage from '@ohos.data.preferences';

/**
 * 文件：StorageService.ets
 * 职责：统一封装业务数据的本地持久化，底层使用 Preferences。
 *
 * 存储约定：
 * - 列表类数据（收藏、历史）以 JSON 字符串保存，读取时再 parse；
 * - 简单配置（音质、透明度、效果档位）直接存数字或布尔值；
 * - 所有写操作都 flush，保证 App 被杀掉后数据仍在；
 * - 读失败时返回默认值，不让存储异常影响页面展示。
 *
 * 登录态不在这里，单独的 AuthService 使用 auth_storage 文件。
 */

// ===== Preferences 键名 =====
const SEARCH_HISTORY_KEY = 'search_history';
const PLAY_HISTORY_KEY = 'play_history';
const FAVORITES_KEY = 'favorites';
const AUDIO_QUALITY_KEY = 'audio_quality';
const THEME_DARK_KEY = 'theme_dark';
const EFFECT_LEVEL_KEY = 'effect_level';
const BACKGROUND_IMAGE_KEY = 'bg_image';
const BACKGROUND_OPACITY_KEY = 'bg_opacity';
// 容量上限：避免历史 / 收藏无限增长，也让 JSON 读写保持在可控大小
const MAX_HISTORY_SIZE = 50;
const MAX_FAVORITES_SIZE = 200;

/**
 * 本地存储服务（单例）。
 * 页面、PlayerService、Ability 都通过这个入口读写业务数据，
 * 保证「谁在存、存在哪、默认值是什么」只有一处定义。
 */
export class StorageService {
  private static instance: StorageService;
  private preferences: dataStorage.Preferences | null = null;
  private context: Context | null = null;

  private constructor() {}

  public static getInstance(): StorageService {
    if (!StorageService.instance) {
      StorageService.instance = new StorageService();
    }
    return StorageService.instance;
  }

  /**
   * Ability 启动时注入 Context，Preferences 的打开依赖它。
   */
  setContext(context: Context) {
    this.context = context;
  }

  /**
   * 懒加载 Preferences 实例。
   * 所有业务数据都放在 music_app_storage 这一个文件里，首次访问时打开。
   */
  private async getPreferences(): Promise<dataStorage.Preferences> {
    if (!this.preferences) {
      if (!this.context) {
        throw new Error('Context not set');
      }
      this.preferences = await dataStorage.getPreferences(this.context, 'music_app_storage');
    }
    return this.preferences;
  }

  // ===== 搜索历史 =====

  /**
   * 读取搜索历史，最新的关键词在前。
   */
  async getSearchHistory(): Promise<string[]> {
    try {
      const prefs = await this.getPreferences();
      const history = await prefs.get(SEARCH_HISTORY_KEY, '[]') as string;
      return JSON.parse(history) as string[];
    } catch (e) {
      console.error('Get search history error:', e);
      return [];
    }
  }

  /**
   * 新增搜索关键词：先去重，再插到最前，超过 50 条截断。
   * 这样重复搜索同一个词不会产生多条记录。
   */
  async addSearchHistory(keyword: string): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      let history = await this.getSearchHistory();

      // 移除重复项
      history = history.filter((item: string) => item !== keyword);

      // 添加到开头
      history.unshift(keyword);

      // 限制大小
      if (history.length > MAX_HISTORY_SIZE) {
        history = history.slice(0, MAX_HISTORY_SIZE);
      }

      await prefs.put(SEARCH_HISTORY_KEY, JSON.stringify(history));
      await prefs.flush();
    } catch (e) {
      console.error('Add search history error:', e);
    }
  }

  /**
   * 清空搜索历史，写入空数组而不是删除键，读取逻辑更统一。
   */
  async clearSearchHistory(): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(SEARCH_HISTORY_KEY, '[]');
      await prefs.flush();
    } catch (e) {
      console.error('Clear search history error:', e);
    }
  }

  // ===== 播放历史 =====

  /**
   * 读取最近播放列表，最新的歌曲在前。
   * Song 对象整体存 JSON，页面直接用，不需要再请求接口。
   */
  async getPlayHistory(): Promise<Song[]> {
    try {
      const prefs = await this.getPreferences();
      const history = await prefs.get(PLAY_HISTORY_KEY, '[]') as string;
      return JSON.parse(history) as Song[];
    } catch (e) {
      console.error('Get play history error:', e);
      return [];
    }
  }

  /**
   * 记录一次播放：按歌曲 id 去重，插到最前，最多保留 50 首。
   * PlayerService 在 AVPlayer 真正进入 playing 状态时调用，保证只记一次。
   */
  async addPlayHistory(song: Song): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      let history = await this.getPlayHistory();

      // 移除重复项
      history = history.filter((item: Song) => item.id !== song.id);

      // 添加到开头
      history.unshift(song);

      // 限制大小
      if (history.length > MAX_HISTORY_SIZE) {
        history = history.slice(0, MAX_HISTORY_SIZE);
      }

      await prefs.put(PLAY_HISTORY_KEY, JSON.stringify(history));
      await prefs.flush();
    } catch (e) {
      console.error('Add play history error:', e);
    }
  }

  /**
   * 清空播放历史。页面清空后会重新读取，保证列表和计数同步刷新。
   */
  async clearPlayHistory(): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(PLAY_HISTORY_KEY, '[]');
      await prefs.flush();
    } catch (e) {
      console.error('Clear play history error:', e);
    }
  }

  // ===== 收藏 =====

  /**
   * 读取收藏列表，最近收藏的歌曲在前。
   */
  async getFavorites(): Promise<Song[]> {
    try {
      const prefs = await this.getPreferences();
      const favorites = await prefs.get(FAVORITES_KEY, '[]') as string;
      return JSON.parse(favorites) as Song[];
    } catch (e) {
      console.error('Get favorites error:', e);
      return [];
    }
  }

  /**
   * 添加收藏：已存在则直接返回，否则插到最前，最多 200 首。
   */
  async addFavorite(song: Song): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      let favorites = await this.getFavorites();

      // 检查是否已收藏
      const exists = favorites.some((item: Song) => item.id === song.id);
      if (exists) {
        return;
      }

      // 添加到开头
      favorites.unshift(song);

      // 限制大小
      if (favorites.length > MAX_FAVORITES_SIZE) {
        favorites = favorites.slice(0, MAX_FAVORITES_SIZE);
      }

      await prefs.put(FAVORITES_KEY, JSON.stringify(favorites));
      await prefs.flush();
    } catch (e) {
      console.error('Add favorite error:', e);
    }
  }

  /**
   * 取消收藏：按歌曲 id 过滤掉对应条目。
   */
  async removeFavorite(songId: number): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      let favorites = await this.getFavorites();

      // 移除指定歌曲
      favorites = favorites.filter((item: Song) => item.id !== songId);

      await prefs.put(FAVORITES_KEY, JSON.stringify(favorites));
      await prefs.flush();
    } catch (e) {
      console.error('Remove favorite error:', e);
    }
  }

  /**
   * 判断某首歌是否已收藏，收藏按钮用它决定红心状态。
   */
  async isFavorite(songId: number): Promise<boolean> {
    try {
      const favorites = await this.getFavorites();
      return favorites.some((item: Song) => item.id === songId);
    } catch (e) {
      console.error('Check favorite error:', e);
      return false;
    }
  }

  /**
   * 切换收藏状态：已收藏就取消，未收藏就添加。
   * @returns 切换后的状态，true 表示现在是收藏状态。
   */
  async toggleFavorite(song: Song): Promise<boolean> {
    try {
      const isFav = await this.isFavorite(song.id);
      if (isFav) {
        await this.removeFavorite(song.id);
        return false;
      } else {
        await this.addFavorite(song);
        return true;
      }
    } catch (e) {
      console.error('Toggle favorite error:', e);
      return false;
    }
  }

  // ===== 播放与外观设置 =====

  /**
   * 读取用户选择的音质，默认「极高」。
   */
  async getAudioQuality(): Promise<AudioQuality> {
    try {
      const prefs = await this.getPreferences();
      const quality = await prefs.get(AUDIO_QUALITY_KEY, AudioQuality.EXHIGH) as number;
      return quality as AudioQuality;
    } catch (e) {
      console.error('Get audio quality error:', e);
      return AudioQuality.EXHIGH;
    }
  }

  /**
   * 保存音质偏好，下次播放时读取。
   */
  async setAudioQuality(quality: AudioQuality): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(AUDIO_QUALITY_KEY, quality);
      await prefs.flush();
    } catch (e) {
      console.error('Set audio quality error:', e);
    }
  }

  /**
   * 读取深色主题偏好。
   * 当前主界面固定浅色，这个键作为后续接入深色模式的预留。
   */
  async getThemeDark(): Promise<boolean> {
    try {
      const prefs = await this.getPreferences();
      return await prefs.get(THEME_DARK_KEY, false) as boolean;
    } catch (e) {
      console.error('Get theme dark error:', e);
      return false;
    }
  }

  /**
   * 保存深色主题偏好。
   */
  async setThemeDark(isDark: boolean): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(THEME_DARK_KEY, isDark);
      await prefs.flush();
    } catch (e) {
      console.error('Set theme dark error:', e);
    }
  }

  /**
   * 读取沉浸光感效果档位，默认「中」。
   */
  async getEffectLevel(): Promise<EffectLevel> {
    try {
      const prefs = await this.getPreferences();
      const level = await prefs.get(EFFECT_LEVEL_KEY, EffectLevel.MEDIUM) as number;
      return level as EffectLevel;
    } catch (e) {
      console.error('Get effect level error:', e);
      return EffectLevel.MEDIUM;
    }
  }

  /**
   * 保存光感效果档位。设置页切换档位后，主界面通过 AppStorage 立即看到变化。
   */
  async setEffectLevel(level: EffectLevel): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(EFFECT_LEVEL_KEY, level);
      await prefs.flush();
    } catch (e) {
      console.error('Set effect level error:', e);
    }
  }

  // ===== 背景图 =====

  /**
   * 读取背景图 URI。
   * 内置背景保存的是 file:// 路径，相册选图保存的是系统返回的 URI。
   */
  async getBgImage(): Promise<string> {
    try {
      const prefs = await this.getPreferences();
      return await prefs.get(BACKGROUND_IMAGE_KEY, '') as string;
    } catch (e) {
      console.error('Get background image error:', e);
      return '';
    }
  }

  /**
   * 保存背景图 URI；传空字符串表示恢复默认背景。
   */
  async setBgImage(uri: string): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(BACKGROUND_IMAGE_KEY, uri);
      await prefs.flush();
    } catch (e) {
      console.error('Set background image error:', e);
    }
  }

  /**
   * 读取背景遮罩透明度，默认 0.15（背景比较明显）。
   */
  async getBgOpacity(): Promise<number> {
    try {
      const prefs = await this.getPreferences();
      return await prefs.get(BACKGROUND_OPACITY_KEY, 0.15) as number;
    } catch (e) {
      console.error('Get background opacity error:', e);
      return 0.15;
    }
  }

  /**
   * 保存背景遮罩透明度，设置页滑块拖动后调用。
   */
  async setBgOpacity(opacity: number): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(BACKGROUND_OPACITY_KEY, opacity);
      await prefs.flush();
    } catch (e) {
      console.error('Set background opacity error:', e);
    }
  }
}
