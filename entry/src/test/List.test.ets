import localUnitTest from './LocalUnit.test';
import authServiceTest from './AuthService.test';

export default function testsuite() {
  localUnitTest();
  authServiceTest();
}