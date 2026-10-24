# HarmonyMusicApp（清听）

HarmonyOS 课程项目：基于公开项目 wyyhm6 的在线音乐播放器二次开发。

> **应用显示名：** 清听  
> **包名：** `com.example.harmonymusicapp`  
> **技术栈：** HarmonyOS · ArkTS · ArkUI · AVPlayer · AVSession · Preferences · FormExtensionAbility  
> **演示账号：** `demo / 123456`（本地校验，不连接真实账号系统）

## 已实现功能

- **四个 Tab**：首页 / 搜索 / 收藏 / 我的；首页含问候、搜索入口、16:9 精选卡、本地精选、最近播放、推荐与精选歌单。
- **欢迎页 + 固定演示登录**：1.5 秒自动进入；登录态保存在 Preferences，杀进程后仍免登录；退出登录停播并回到登录页。
- **双 Ability**：`EntryAbility` 只负责欢迎/登录，`MainAbility` 负责主界面、播放与音频会话；`MainAbility` 带登录门禁。
- **收藏 / 最近播放**：收藏与历史持久化；所有播放入口统一由 `PlayerService` 记录历史；切换 Tab、从播放页返回时刷新。
- **歌单详情**：封面、歌单名、歌曲数、全部播放 / 随机播放。
- **深色沉浸播放页**：固定深色 token，不污染浅色主界面；封面模糊背景、歌词高亮、音质弹层、播放列表弹层、状态栏切白。
- **动态 2×2 服务卡片**：读取本地最近播放，显示“继续听”或“发现好音乐”；App 内播放后立即更新，支持系统定点刷新，点击拉起 App。
- **本地示例音频**：`rawfile/demo_loop.wav`（项目自行生成的 24 秒无版权环境循环）；断网时仍可播放，歌词页提示“示例音频，无歌词”。
- **本地音乐导入**：我的 → 设置 → 本地音乐，可从系统文件选择器导入自己合法持有的 MP3 / FLAC / M4A / AAC / WAV / OGG；文件复制到应用私有目录，支持播放和删除，不上传、不提交仓库。
- **网络 API 与兜底**：搜索、推荐、歌单、歌词；请求带 10 秒连接/读取超时；搜索区分“无结果 / 网络失败”；首页失败时展示本地精选并可重试。
- **品牌资源**：清听应用名、珊瑚渐变 + 声波分层图标、启动图、卡片名。

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

安装到模拟器（先 `cd` 到产物目录，使用相对路径）：

```sh
hdc install -r entry-default-unsigned.hap
hdc shell aa start -a EntryAbility -b com.example.harmonymusicapp
```

> 工程路径不要包含中文，否则 hvigor 会拒绝构建。

本地单元测试：

```sh
export DEVECO_SDK_HOME="D:/DevEco Studio/sdk"
"D:/DevEco Studio/tools/hvigor/bin/hvigorw.bat" test --mode module -p module=entry@default -p product=default
```

结果查看 `entry/.test/default/intermediates/test/coverage_data/test_result.txt`（hvigor 在测试失败时也可能返回 0）。

## 服务卡片

1. 回到桌面，长按空白区域 → “编辑桌面” → “卡片”。
2. 在卡片选择器搜索“清听”，选择“清听 · 最近播放” → “添加至桌面”。
3. 在 App 内播放任意歌曲，回到桌面可看到卡片更新为最近播放。
4. 点击卡片会拉起 `EntryAbility`：已登录进入主界面，未登录先到登录页。

## 导入自己合法持有的本地音乐

1. 把音频文件放到手机/模拟器的“下载”等用户目录（或直接用文件管理器选择）。
2. App 内进入“我的 → 设置 → 本地音乐 → 导入音频”。
3. 在系统文件选择器里选中音频文件，确认后 App 会复制到应用私有目录，并读取标题、歌手、专辑和时长；读取失败时用文件名和“本地导入”兜底。
4. 点击列表项播放，点“删除”会连同私有目录里的副本一起删除。

说明：本功能只是播放用户自己选择的文件，不提供任何音乐下载源，也不会把音频上传或打包进仓库。受 DRM 保护的音乐（如部分流媒体平台的离线缓存）无法导入播放。

## 本地示例音频版权

`entry/src/main/resources/rawfile/demo_loop.wav` 由本项目用脚本生成（正弦和弦 + 琶音 + 低音的环境循环，24 秒、44.1kHz、单声道 16-bit），不包含任何第三方音乐或录音，可随课程作业分发。

## 工程结构

```text
entry/src/main/ets/
  entryability/EntryAbility.ets     欢迎/登录窗口
  mainability/MainAbility.ets       主界面、音频、登录门禁
  formability/MusicFormAbility.ets  2×2 服务卡片生命周期
  pages/                            Welcome/Login/Index/Play/Settings/SongList
  pages/views/                      FavoritesView / ProfileView
  pages/widget/MusicWidgetCard.ets  卡片 UI
  services/                         Auth / Api / Player / Storage / Widget / MockData 等
  components/                       PlayerControls / LyricView / SongItem
```

## 分支与提交

- `main`：基线与最终可提交版本
- `dev`：阶段开发分支；每个阶段完成并验收后提交、推送

## 来源与署名

本项目基于 [wyyhm6](https://github.com/Hanmiao33/wyyhm6)，并参考 [HarmonyPulse](https://github.com/ASweetBite/HarmonyPulse) 的多 Ability 与工程化思路。原始项目未标注许可证，本仓库为课程学习用途的公开仓库；第三方代码和素材的版权归原作者，若原作者要求删除会配合处理。

本仓库的 UI 调研截图仅用于课程设计比较，版权归原应用/媒体所有。

## 已知限制

- 未配置签名；模拟器使用未签名 HAP，真机需配置调试签名。
- 在线播放依赖第三方公开音乐接口，部分歌曲可能无播放地址或接口失效；此时页面会 toast 提示，并提供本地示例兜底。
- 服务卡片采用系统定点刷新（`scheduledUpdateTime: 22:15`），App 内播放后的立即刷新是主路径；系统刷新受设备调度影响。
- 服务卡片的 `FormExtensionAbility` 与主应用共用 Preferences 文件；已验证串行的添加/刷新/移除，但两端同时写入时理论上存在文件竞争风险。课程演示数据量很小，若后续产品化建议拆分为独立存储或 DataShare。
- 首页/搜索把“网络失败”和“服务返回异常”合并为同一错误文案；空结果、网络失败与无播放地址已分别处理。
- 切换音质会从 0 秒重新加载当前歌曲，这是当前实现的已知行为；暂停状态下切换音质会开始播放。
- 服务卡片首次添加时会先返回通用文案，随后异步读取最近播放并刷新，通常小于 1 秒。
- 模拟器联网走 QEMU 虚拟以太网，无法在不修改宿主网络的情况下真正断网；断网兜底通过“API 指向不可达地址”验证了同一代码路径，本地示例本身的播放不依赖网络。
- 本地导入只支持普通音频文件；受 DRM 保护的平台离线缓存不能播放。系统文件选择器在模拟器上一次通常只返回一个选中文件，真机可能支持多选。
- 演示登录为固定账号本地校验，不是真实账号系统。
