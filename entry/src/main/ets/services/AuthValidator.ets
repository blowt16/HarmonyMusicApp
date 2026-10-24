/**
 * 课程演示用的固定账号校验。
 * 纯函数实现，不依赖设备能力，便于本地单元测试。
 */
export interface AuthValidationResult {
  success: boolean;
  message: string;
}

const DEMO_USERNAME: string = 'demo';
const DEMO_PASSWORD: string = '123456';

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

export const DEMO_ACCOUNT_NAME: string = DEMO_USERNAME;
export const DEMO_ACCOUNT_PASSWORD: string = DEMO_PASSWORD;
export const DEMO_NICKNAME: string = DEMO_USERNAME;
