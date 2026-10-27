/**
 * 文件：AuthValidator.ets
 * 职责：课程演示用的固定账号校验。
 *
 * 这里刻意保持纯函数：不读 Preferences、不依赖 Context，
 * 因此可以直接在本地单元测试里覆盖空账号、空密码、错误密码等情况。
 */
export interface AuthValidationResult {
  success: boolean; // 是否通过校验
  message: string; // 失败时给用户看的提示；成功时为空字符串
}

// 演示账号写死在前端，仅用于课程演示，不具备真实安全性
const DEMO_USERNAME: string = 'demo';
const DEMO_PASSWORD: string = '123456';

/**
 * 校验账号密码。
 * 校验顺序：空账号 → 空密码 → 账号或密码不匹配 → 通过。
 * 这样登录页可以针对不同错误显示更具体的提示。
 */
export function validateCredentials(username: string, password: string): AuthValidationResult {
  if (!username || username.trim().length === 0) {
    return { success: false, message: '请输入账号' };
  }
  if (!password || password.length === 0) {
    return { success: false, message: '请输入密码' };
  }
  if (username.trim() !== DEMO_USERNAME || password !== DEMO_PASSWORD) {
    return { success: false, message: '账号或密码错误' };
  }
  return { success: true, message: '' };
}

// 导出给登录页做提示、给 AuthService 做默认昵称
export const DEMO_ACCOUNT_NAME: string = DEMO_USERNAME;
export const DEMO_ACCOUNT_PASSWORD: string = DEMO_PASSWORD;
export const DEMO_NICKNAME: string = DEMO_USERNAME;
