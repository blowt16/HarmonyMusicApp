import { describe, it, expect } from '@ohos/hypium';
import { validateCredentials, AuthValidationResult } from '../main/ets/services/AuthValidator';

/**
 * 固定演示账号校验。AuthService.validate 直接委托给 validateCredentials，
 * 这里测试纯逻辑，避免本地单元测试依赖设备 Preferences。
 */
export default function authServiceTest() {
  describe('AuthService', () => {
    it('empty_username', 0, () => {
      const result: AuthValidationResult = validateCredentials('', '123456');
      expect(result.success).assertEqual(false);
      expect(result.message).assertEqual('请输入账号');
    });

    it('empty_password', 0, () => {
      const result: AuthValidationResult = validateCredentials('demo', '');
      expect(result.success).assertEqual(false);
      expect(result.message).assertEqual('请输入密码');
    });

    it('wrong_username', 0, () => {
      const result: AuthValidationResult = validateCredentials('admin', '123456');
      expect(result.success).assertEqual(false);
      expect(result.message).assertEqual('账号或密码错误');
    });

    it('wrong_password', 0, () => {
      const result: AuthValidationResult = validateCredentials('demo', '000000');
      expect(result.success).assertEqual(false);
      expect(result.message).assertEqual('账号或密码错误');
    });

    it('correct_demo_account', 0, () => {
      const result: AuthValidationResult = validateCredentials('demo', '123456');
      expect(result.success).assertEqual(true);
      expect(result.message).assertEqual('');
    });
  });
}
