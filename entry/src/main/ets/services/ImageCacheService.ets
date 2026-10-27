import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

/**
 * 文件：ImageCacheService.ets
 * 职责：把网络封面下载到应用缓存目录，减少重复下载和解码。
 *
 * 缓存策略：
 * - 文件名由 URL 的哈希 + 扩展名生成，同一 URL 稳定命中同一文件；
 * - memoryIndex 只记录「文件名 → 本地路径」，启动时扫描目录重建；
 * - pendingDownloads 保存正在进行的下载 Promise，避免同一 URL 并发下载多次；
 * - 文件数超过上限时，按内存索引的插入顺序淘汰最早加入的条目。
 */
export class ImageCacheService {
  private static instance: ImageCacheService;
  private context: Context | null = null;
  private memoryIndex: Map<string, string> = new Map(); // 文件名 → 本地绝对路径
  private pendingDownloads: Map<string, Promise<string>> = new Map(); // URL → 正在进行的下载任务
  private initialized: boolean = false;
  private readonly maxCacheFiles: number = 100; // 最多缓存 100 张封面
  private readonly cacheSubDir: string = 'cover_cache'; // 缓存子目录名

  private constructor() {}

  public static getInstance(): ImageCacheService {
    if (!ImageCacheService.instance) {
      ImageCacheService.instance = new ImageCacheService();
    }
    return ImageCacheService.instance;
  }

  /**
   * 初始化服务，需要在 Ability.onCreate 中调用。
   * 创建缓存目录，并扫描已有文件重建内存索引，保证重启后仍能命中旧缓存。
   */
  async init(context: Context): Promise<void> {
    this.context = context;
    const cacheDir = this.getCacheDir();
    try {
      if (!fs.accessSync(cacheDir)) {
        fs.mkdirSync(cacheDir);
      }
    } catch (e) {
      // 目录已存在或创建失败都不阻塞启动，后续下载会再尝试
    }
    await this.rebuildIndex();
    this.initialized = true;
  }

  private getCacheDir(): string {
    if (!this.context) {
      return '';
    }
    return `${this.context.cacheDir}/${this.cacheSubDir}`;
  }

  /**
   * 从 URL 生成稳定文件名。
   * 这里用 32 位滚动哈希而不是 MD5，避免为一个小功能引入加密库；
   * 哈希碰撞概率对课程项目的数据量可以接受。
   */
  private urlToFileName(url: string): string {
    // 简单哈希：逐字符累积，结果截断为 32 位整数
    let hash = 0;
    for (let i = 0; i < url.length; i++) {
      const ch = url.charCodeAt(i);
      hash = ((hash << 5) - hash) + ch;
      hash = hash & hash; // 转 32 位整数
    }
    // 提取 URL 中的扩展名，默认 .jpg
    let ext = '.jpg';
    const dotIndex = url.lastIndexOf('.');
    const slashIndex = url.lastIndexOf('/');
    if (dotIndex > slashIndex && dotIndex > 0) {
      const candidate = url.substring(dotIndex, dotIndex + 5).split('?')[0];
      if (candidate.length <= 5) {
        ext = candidate;
      }
    }
    return `img_${Math.abs(hash).toString(16)}${ext}`;
  }

  /**
   * 启动时扫描缓存目录，重建「文件名 → 路径」索引。
   * 应用重启后内存索引会丢失，但磁盘文件还在，这一步让缓存继续可用。
   */
  private async rebuildIndex(): Promise<void> {
    const cacheDir = this.getCacheDir();
    try {
      const files = fs.listFileSync(cacheDir);
      for (const file of files) {
        const fullPath = `${cacheDir}/${file}`;
        this.memoryIndex.set(file, fullPath);
      }
    } catch (e) {
      console.error('ImageCacheService rebuildIndex error:', e);
    }
  }

  /**
   * 获取封面本地路径。
   * 流程：内存索引命中 → 检查磁盘文件是否还在 → 未命中则下载。
   * 如果服务尚未初始化或 URL 为空，直接把原始 URL 还给调用方，
   * 让 Image 组件按网络图片处理。
   *
   * @param url 网络图片 URL
   * @returns 本地文件路径；下载失败时返回原始 URL
   */
  async getCachedPath(url: string): Promise<string> {
    if (!url || !this.initialized) {
      return url;
    }

    const fileName = this.urlToFileName(url);
    const localPath = `${this.getCacheDir()}/${fileName}`;

    // 1. 内存索引命中：再确认磁盘文件没被系统清理
    if (this.memoryIndex.has(fileName)) {
      try {
        if (fs.accessSync(localPath)) {
          // 打开一次文件，尽量让文件系统更新访问时间
          fs.openSync(localPath, fs.OpenMode.READ_ONLY);
          return localPath;
        }
      } catch (e) {
        // 文件已被系统清理，删除索引后走下载流程
        this.memoryIndex.delete(fileName);
      }
    }

    // 2. 同一 URL 已有下载任务时复用 Promise，避免并发重复下载
    const existing = this.pendingDownloads.get(url);
    if (existing) {
      return existing;
    }

    // 3. 发起下载，并把 Promise 放进 pendingDownloads 供其他调用复用
    const downloadPromise = this.downloadAndCache(url, localPath, fileName);
    this.pendingDownloads.set(url, downloadPromise);

    try {
      const result = await downloadPromise;
      return result;
    } finally {
      // 无论成功失败都要移除，避免后续请求永远拿到旧 Promise
      this.pendingDownloads.delete(url);
    }
  }

  /**
   * 下载图片并写入缓存目录。
   * 请求用 ARRAY_BUFFER 直接拿二进制，避免先转 base64 再解码。
   * 下载或写文件失败时不抛异常，而是返回原始 URL，让 UI 仍有机会显示网络图。
   */
  private async downloadAndCache(url: string, localPath: string, fileName: string): Promise<string> {
    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Referer': 'https://music.163.com',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      httpRequest.destroy();

      if (response.responseCode === 200) {
        // 写入缓存目录；文件名由 URL 哈希决定，重复下载会覆盖同一文件
        const file = fs.openSync(localPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
        fs.writeSync(file.fd, response.result as ArrayBuffer);
        fs.closeSync(file);

        this.memoryIndex.set(fileName, localPath);

        // 新增文件后检查是否超过上限
        await this.evictIfNeeded();

        return localPath;
      }
    } catch (e) {
      console.error('ImageCacheService download error:', url, e);
    }

    // 下载失败时返回原始 URL，让 Image 组件自己尝试
    return url;
  }

  /**
   * 缓存文件超出上限时，按内存索引的插入顺序淘汰最早加入的条目。
   * 注意：这里不是严格按访问时间排序的 LRU，只是控制缓存总量的近似策略。
   */
  private async evictIfNeeded(): Promise<void> {
    if (this.memoryIndex.size <= this.maxCacheFiles) {
      return;
    }

    const excess: number = this.memoryIndex.size - this.maxCacheFiles;
    const keysToDelete: string[] = [];
    // 将 Map 的键转为数组，避免使用 MapIterator
    const allKeys: string[] = Array.from(this.memoryIndex.keys());
    for (let i = 0; i < excess && i < allKeys.length; i++) {
      keysToDelete.push(allKeys[i]);
    }
    for (let i = 0; i < keysToDelete.length; i++) {
      const path: string | undefined = this.memoryIndex.get(keysToDelete[i]);
      if (path) {
        try {
          fs.unlinkSync(path);
        } catch (e) {
          // ignore
        }
      }
      this.memoryIndex.delete(keysToDelete[i]);
    }
  }

  /**
   * 清空全部图片缓存：删除目录内文件并清空内存索引。
   * 单个文件删除失败不影响其他文件，最后统一清空索引。
   */
  async clearAll(): Promise<void> {
    const cacheDir = this.getCacheDir();
    try {
      const files = fs.listFileSync(cacheDir);
      for (const file of files) {
        try {
          fs.unlinkSync(`${cacheDir}/${file}`);
        } catch (e) {
          // ignore
        }
      }
    } catch (e) {
      console.error('ImageCacheService clearAll error:', e);
    }
    this.memoryIndex.clear();
  }

  /**
   * 缓存文件数量
   */
  get cacheSize(): number {
    return this.memoryIndex.size;
  }
}
