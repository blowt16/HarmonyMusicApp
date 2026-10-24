import dataStorage from '@ohos.data.preferences';
import { validateCredentials, AuthValidationResult, DEMO_NICKNAME } from './AuthValidator';

const AUTH_PREFS_NAME: string = 'auth_storage';
const IS_LOGGED_IN_KEY: string = 'is_logged_in';
const NICKNAME_KEY: string = 'nickname';

/**
 * 固定演示账号登录：只保存登录标记与昵称，不保存密码，不连接真实账号系统。
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

  setContext(context: Context) {
    this.context = context;
  }

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
   * 纯校验逻辑，空账号/空密码/错误账号/错误密码/正确账号分别返回明确结果。
   */
  static validate(username: string, password: string): AuthValidationResult {
    return validateCredentials(username, password);
  }

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

  async isLoggedIn(): Promise<boolean> {
    try {
      const prefs = await this.getPreferences();
      return await prefs.get(IS_LOGGED_IN_KEY, false) as boolean;
    } catch (e) {
      console.error('Check login state error:', e);
      return false;
    }
  }

  async getNickname(): Promise<string> {
    try {
      const prefs = await this.getPreferences();
      return await prefs.get(NICKNAME_KEY, DEMO_NICKNAME) as string;
    } catch (e) {
      console.error('Get nickname error:', e);
      return DEMO_NICKNAME;
    }
  }

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
