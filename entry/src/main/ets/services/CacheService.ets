/**
 * 文件：CacheService.ets
 * 职责：为 ApiService 提供进程内的通用 LRU 内存缓存。
 *
 * 设计说明：
 * - ArkTS 不支持把 unknown/any 直接断言成任意泛型，所以统一先 JSON.stringify
 *   存成字符串，读取时由调用方 JSON.parse 回具体类型；
 * - 缓存只在内存中，App 进程退出后自动清空，不会读到跨启动的过期数据；
 * - 每个 key 单独记录过期时间，读取到过期条目时顺手删除，避免缓存无限膨胀。
 */
export class CacheService {
  private static instance: CacheService;
  private cache: Map<string, string> = new Map(); // key → JSON 字符串
  private expiry: Map<string, number> = new Map(); // key → 过期时间戳（毫秒）
  private order: string[] = []; // 访问顺序，尾部是最新访问的 key
  private readonly maxSize: number = 200; // 最多保留 200 条，超出淘汰队首

  private constructor() {}

  public static getInstance(): CacheService {
    if (!CacheService.instance) {
      CacheService.instance = new CacheService();
    }
    return CacheService.instance;
  }

  /**
   * 写入缓存。
   * 先把对象序列化成 JSON，同时记录「当前时间 + ttl」作为过期时间。
   * 如果 key 已存在，会先把它从旧位置移除，再放到队尾，保持 LRU 顺序。
   *
   * @param key 缓存键，通常由接口名 + 参数拼成
   * @param data 要缓存的对象，必须能被 JSON 序列化
   * @param ttlMs 有效期，默认 5 分钟
   */
  set(key: string, data: Object, ttlMs: number = 5 * 60 * 1000): void {
    // 容量已满时，淘汰最久未使用的条目（order 数组的队首）
    if (this.cache.size >= this.maxSize) {
      const oldest: string | undefined = this.order.shift();
      if (oldest !== undefined) {
        this.cache.delete(oldest);
        this.expiry.delete(oldest);
      }
    }
    this.cache.set(key, JSON.stringify(data));
    this.expiry.set(key, Date.now() + ttlMs);
    // 同 key 覆盖写入时先移除旧位置，避免 order 里出现重复 key
    const idx: number = this.order.indexOf(key);
    if (idx >= 0) {
      this.order.splice(idx, 1);
    }
    this.order.push(key);
  }

  /**
   * 读取缓存，返回 JSON 字符串，调用方自行 JSON.parse。
   * 过期条目会被立即删除；命中后把 key 移到队尾，表示「最近使用过」。
   */
  get(key: string): string | null {
    const expireAt: number | undefined = this.expiry.get(key);
    if (expireAt === undefined) {
      return null;
    }
    if (Date.now() > expireAt) {
      // 惰性删除：读取时才发现过期，顺手清理，避免定时器开销
      this.delete(key);
      return null;
    }
    const json: string | undefined = this.cache.get(key);
    if (json === undefined) {
      return null;
    }
    // LRU：命中后移到 order 队尾
    const idx: number = this.order.indexOf(key);
    if (idx >= 0) {
      this.order.splice(idx, 1);
    }
    this.order.push(key);
    return json;
  }

  /**
   * 检查缓存是否存在且未过期。
   * 注意：内部调用 get，因此同样会刷新 LRU 顺序。
   */
  has(key: string): boolean {
    return this.get(key) !== null;
  }

  /**
   * 删除指定键
   */
  delete(key: string): void {
    this.cache.delete(key);
    this.expiry.delete(key);
    const idx: number = this.order.indexOf(key);
    if (idx >= 0) {
      this.order.splice(idx, 1);
    }
  }

  /**
   * 按前缀批量清除，例如清空某个接口的所有缓存。
   * 先收集要删的 key，再统一删除，避免边遍历边修改 order 数组。
   */
  clearByPrefix(prefix: string): void {
    const keysToDelete: string[] = [];
    // 遍历所有键，收集匹配前缀的
    const allKeys: string[] = this.order.slice();
    for (let i = 0; i < allKeys.length; i++) {
      if (allKeys[i].startsWith(prefix)) {
        keysToDelete.push(allKeys[i]);
      }
    }
    for (let i = 0; i < keysToDelete.length; i++) {
      this.delete(keysToDelete[i]);
    }
  }

  /**
   * 清空全部缓存
   */
  clear(): void {
    this.cache.clear();
    this.expiry.clear();
    this.order = [];
  }

  /**
   * 当前缓存条目数
   */
  get size(): number {
    return this.cache.size;
  }
}
