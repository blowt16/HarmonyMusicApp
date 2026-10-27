import dataStorage from '@ohos.data.preferences';
import { validateCredentials, AuthValidationResult, DEMO_NICKNAME } from './AuthValidator';

/**
 * 文件：AuthService.ets
 * 职责：管理演示账号的登录状态。
 *
 * 重要约定：
 * - 登录校验是纯本地逻辑，不连接真实账号系统；
 * - 只持久化「是否登录」和昵称，绝不保存密码；
 * - 登录态单独放在 auth_storage，和业务数据 music_app_storage 分开，
 *   这样清理业务数据时不会误伤登录态。
 */
const AUTH_PREFS_NAME: string = 'auth_storage';
const IS_LOGGED_IN_KEY: string = 'is_logged_in';
const NICKNAME_KEY: string = 'nickname';

/**
 * 登录服务（单例）。
 * 页面通过 getInstance() 共享同一份 Preferences 句柄，避免重复打开文件。
 */
export class AuthService {
  private static instance: AuthService;
  private preferences: dataStorage.Preferences | null = null;
  private context: Context | null = null;

  private constructor() {}

  public static getInstance(): AuthService {
    if (!AuthService.instance) {
      AuthService.instance = new AuthService();
    }
    return AuthService.instance;
  }

  /**
   * Ability 启动时把上下文交给服务，Preferences 必须依赖 Context 才能打开。
   */
  setContext(context: Context) {
    this.context = context;
  }

  /**
   * 懒加载 Preferences：
   * 第一次真正读写时才打开文件，后续复用同一个实例，减少 IO。
   */
  private async getPreferences(): Promise<dataStorage.Preferences> {
    if (!this.preferences) {
      if (!this.context) {
        throw new Error('Context not set');
      }
      this.preferences = await dataStorage.getPreferences(this.context, AUTH_PREFS_NAME);
    }
    return this.preferences;
  }

  /**
   * 只做校验、不改变登录态，方便登录页在提交前单独调用。
   * 空账号、空密码、错误账号密码会返回不同的提示文案。
   */
  static validate(username: string, password: string): AuthValidationResult {
    return validateCredentials(username, password);
  }

  /**
   * 登录：先校验固定账号，成功后写入登录标记和昵称。
   * 密码只参与校验，不会写进 Preferences。
   */
  async login(username: string, password: string): Promise<AuthValidationResult> {
    const result: AuthValidationResult = validateCredentials(username, password);
    if (!result.success) {
      return result;
    }
    try {
      const prefs = await this.getPreferences();
      await prefs.put(IS_LOGGED_IN_KEY, true);
      await prefs.put(NICKNAME_KEY, DEMO_NICKNAME);
      await prefs.flush();
      return { success: true, message: '' };
    } catch (e) {
      console.error('Login error:', e);
      return { success: false, message: '登录状态保存失败，请重试' };
    }
  }

  /**
   * 读取登录态。读失败时按「未登录」处理，避免异常把入口卡死。
   */
  async isLoggedIn(): Promise<boolean> {
    try {
      const prefs = await this.getPreferences();
      return await prefs.get(IS_LOGGED_IN_KEY, false) as boolean;
    } catch (e) {
      console.error('Check login state error:', e);
      return false;
    }
  }

  /**
   * 读取昵称；没有保存过时回退到演示账号昵称。
   */
  async getNickname(): Promise<string> {
    try {
      const prefs = await this.getPreferences();
      return await prefs.get(NICKNAME_KEY, DEMO_NICKNAME) as string;
    } catch (e) {
      console.error('Get nickname error:', e);
      return DEMO_NICKNAME;
    }
  }

  /**
   * 退出登录：清掉登录标记和昵称。
   * 调用方还需要负责停止播放、释放播放器和 AVSession。
   */
  async logout(): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(IS_LOGGED_IN_KEY, false);
      await prefs.put(NICKNAME_KEY, '');
      await prefs.flush();
    } catch (e) {
      console.error('Logout error:', e);
    }
  }
}
