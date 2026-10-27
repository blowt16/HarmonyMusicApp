import { ConfigurationConstant } from '@kit.AbilityKit';

/**
 * 文件：ThemeManager.ets
 * 职责：集中管理浅色 / 深色两套颜色 token，并同步到 AppStorage。
 *
 * 页面不直接写死颜色，而是通过 @StorageLink 绑定 token；
 * 切换主题时只改 AppStorage，所有绑定这些 key 的页面会自动刷新。
 * 注意：主界面目前固定浅色，播放页使用独立的 player* token，
 * 所以这里的深色配色主要作为预留能力。
 */
const THEME_MODE_KEY: string = 'theme_mode'; // 预留的主题持久化键，当前版本尚未使用

/**
 * 一套主题需要的颜色 token。
 * 命名按用途划分：背景、文字、强调色、边框、遮罩。
 */
export interface ThemeColors {
  bgPrimary: string;
  bgSecondary: string;
  bgSurface: string;
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  accent: string;
  accentLight: string;
  border: string;
  overlay: string;
}

// 浅色主题：暖白背景 + 珊瑚红强调色，用于主界面
const LIGHT_COLORS: ThemeColors = {
  bgPrimary: '#F7F6F2',
  bgSecondary: '#FFFFFF',
  bgSurface: '#FFFFFF',
  textPrimary: '#17181A',
  textSecondary: '#6B6F76',
  textTertiary: '#9A9EA5',
  accent: '#C8424C',
  accentLight: '#FDEBED',
  border: '#ECE8E0',
  overlay: '#00000066',
};

// 深色主题：深灰背景 + 更亮的红色强调色，预留给深色模式
const DARK_COLORS: ThemeColors = {
  bgPrimary: '#1A1A1A',
  bgSecondary: '#121212',
  bgSurface: '#2C2C2C',
  textPrimary: '#FFFFFF',
  textSecondary: '#CCCCCC',
  textTertiary: '#FFFFFF',
  accent: '#FF6B6B',
  accentLight: '#3A1A1A',
  border: '#3A3A3A',
  overlay: '#00000080',
};

/**
 * 主题管理器（单例）。
 * 负责保存当前主题、提供颜色 token，并在切换时通知监听者。
 */
export class ThemeManager {
  private static instance: ThemeManager;
  private isDark: boolean = false;
  private listeners: ((isDark: boolean) => void)[] = [];

  private constructor() {}

  public static getInstance(): ThemeManager {
    if (!ThemeManager.instance) {
      ThemeManager.instance = new ThemeManager();
    }
    return ThemeManager.instance;
  }

  /**
   * 初始化主题。项目目前在 Entry / Main 中都传 false，即固定浅色，
   * 但保留参数是为了以后接入深色模式时不需要改调用方。
   */
  init(isDark: boolean): void {
    this.isDark = isDark;
    this.syncToStorage();
  }

  /**
   * 切换浅色 / 深色，并通知所有监听者。
   */
  toggleTheme(): void {
    this.isDark = !this.isDark;
    this.syncToStorage();
    for (const listener of this.listeners) {
      listener(this.isDark);
    }
  }

  getIsDark(): boolean {
    return this.isDark;
  }

  /**
   * 返回当前主题的整套颜色 token。
   */
  getColors(): ThemeColors {
    return this.isDark ? DARK_COLORS : LIGHT_COLORS;
  }

  getStatusBarContentColor(): string {
    return this.isDark ? '#FFFFFF' : '#000000';
  }

  getNavigationBarContentColor(): string {
    return this.isDark ? '#FFFFFF' : '#000000';
  }

  getColorMode(): ConfigurationConstant.ColorMode {
    return this.isDark
      ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  }

  addListener(listener: (isDark: boolean) => void): void {
    this.listeners.push(listener);
  }

  removeListener(listener: (isDark: boolean) => void): void {
    const index: number = this.listeners.indexOf(listener);
    if (index > -1) {
      this.listeners.splice(index, 1);
    }
  }

  /**
   * 把当前主题的颜色写入 AppStorage。
   * 页面上的 @StorageLink('bgPrimary') 等会自动收到更新。
   */
  private syncToStorage(): void {
    AppStorage.setOrCreate<boolean>('isDark', this.isDark);
    const colors: ThemeColors = this.getColors();
    AppStorage.setOrCreate<string>('bgPrimary', colors.bgPrimary);
    AppStorage.setOrCreate<string>('bgSecondary', colors.bgSecondary);
    AppStorage.setOrCreate<string>('bgSurface', colors.bgSurface);
    AppStorage.setOrCreate<string>('textPrimary', colors.textPrimary);
    AppStorage.setOrCreate<string>('textSecondary', colors.textSecondary);
    AppStorage.setOrCreate<string>('textTertiary', colors.textTertiary);
    AppStorage.setOrCreate<string>('accent', colors.accent);
    AppStorage.setOrCreate<string>('accentLight', colors.accentLight);
    AppStorage.setOrCreate<string>('border', colors.border);
    AppStorage.setOrCreate<string>('overlay', colors.overlay);
  }
}
