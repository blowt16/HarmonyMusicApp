# HarmonyMusicApp

HarmonyOS 课程项目：基于公开项目 wyyhm6 的在线音乐播放器二次开发。

> **状态：** 基线已导入，方案 v1.1 审核中，功能开发尚未开始。  
> **应用显示名：** 清听  
> **包名（计划）：** `com.example.harmonymusicapp`  
> **技术栈：** HarmonyOS · ArkTS · ArkUI · AVPlayer · AVSession · FormExtensionAbility

## 说明

本仓库用于课程结课作业。当前代码主要是 wyyhm6 基线，已移除原仓库写死的签名配置，便于在本机模拟器构建。后续会按方案补齐：

- 4 个 Tab：首页 / 搜索 / 收藏 / 我的
- 欢迎页与固定演示登录
- EntryAbility + MainAbility 双 Ability
- 动态 2×2 服务卡片
- 深色沉浸播放页
- 本地示例音频（断网演示）
- API 超时/失败兜底

方案与调研：

- [二次开发方案 v1.1](docs/二次开发方案.md)
- [UI 调研与风格选择](docs/UI调研与风格选择.html)
- [方案审阅报告](docs/方案审阅报告.md)

## 构建与运行

需要 DevEco Studio 与本机 HarmonyOS SDK。模拟器接受未签名 HAP；真机需要配置自己的调试签名。

```sh
export DEVECO_SDK_HOME="D:/DevEco Studio/sdk"
export MSYS_NO_PATHCONV=1
"D:/DevEco Studio/tools/hvigor/bin/hvigorw.bat" --mode module -p product=default assembleHap --no-daemon
```

产物：

```text
entry/build/default/outputs/default/entry-default-unsigned.hap
```

安装到模拟器：

```sh
hdc install -r entry-default-unsigned.hap
```

> 工程路径不要包含中文，否则 hvigor 会拒绝构建。

## 分支与提交

- `main`：基线与最终可提交版本
- `dev`：阶段开发分支
- 每个阶段完成并验收后提交、推送；提交信息见 `docs/二次开发方案.md` 的“GitHub 仓库与阶段提交”。

## 来源与署名

本项目基于 [wyyhm6](https://github.com/Hanmiao33/wyyhm6)，并参考 [HarmonyPulse](https://github.com/ASweetBite/HarmonyPulse) 的多 Ability 与工程化思路。原始项目未标注许可证，本仓库为课程用途的私有仓库；未经允许不要公开分发第三方代码或素材。

本仓库的 UI 调研截图仅用于课程设计比较，版权归原应用/媒体所有。

## 当前限制

- 未配置签名；模拟器使用未签名 HAP。
- 在线播放依赖第三方音乐接口，可能失效；方案中包含本地示例音频与兜底设计。
- 功能尚未实现，README 的“后续会补齐”是计划，不是当前能力。
