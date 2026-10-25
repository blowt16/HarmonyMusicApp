# HarmonyMusicApp（清听）

HarmonyOS 课程设计项目：在公开项目 [wyyhm6](https://github.com/Hanmiao33/wyyhm6) 基础上二次开发的在线音乐播放器。

| 项目 | 说明 |
| --- | --- |
| 应用名 | 清听 |
| 包名 | `com.example.harmonymusicapp` |
| 技术栈 | HarmonyOS 6.1.0(23) · ArkTS · ArkUI · AVPlayer · AVSession · Preferences · FormExtensionAbility |
| 开发环境 | DevEco Studio，`modelVersion 6.0.2` |
| 演示账号 | `demo / 123456`（本地校验，不连接真实账号系统） |
| 主要文档 | [二次开发方案](docs/二次开发方案.md) · [验收测试记录](docs/验收测试记录.md) · [背景图来源](docs/背景图来源.md) |

## 目录

- [功能概览](#功能概览)
- [背景设置](#背景设置)
- [构建与运行](#构建与运行)
- [本地单元测试](#本地单元测试)
- [服务卡片](#服务卡片)
- [在线播放与版权说明](#在线播放与版权说明)
- [导入自己合法持有的本地音乐](#导入自己合法持有的本地音乐)
- [本地示例音频版权](#本地示例音频版权)
- [工程结构](#工程结构)
- [文档导航](#文档导航)
- [分支与提交](#分支与提交)
- [来源与署名](#来源与署名)
- [已知限制](#已知限制)

## 功能概览

- **四个 Tab**：首页 / 搜索 / 收藏 / 我的；首页含搜索入口、16:9 精选歌单卡、横滑推荐歌单、三行翻页的“为你推荐”、本地精选和最近播放。
- **欢迎页 + 固定演示登录**：1.5 秒自动进入；登录态保存在 Preferences，杀进程后仍免登录；退出登录停播并回到登录页。
- **双 Ability**：`EntryAbility` 只负责欢迎/登录，`MainAbility` 负责主界面、播放与音频会话；`MainAbility` 带登录门禁。
- **收藏 / 最近播放**：收藏与历史持久化；所有播放入口统一由 `PlayerService` 记录历史；切换 Tab、从播放页返回时刷新。
- **歌单详情**：封面、歌单名、歌曲数、全部播放 / 随机播放；开启背景图后歌曲列表透明。
- **背景设置**：内置 7 张推荐背景（晨光、天蓝、薄荷、柔光、玻璃、现场、黑胶），横向滑动选择、点击即应用；也支持系统相册选图，并可调节遮罩透明度。
- **深色沉浸播放页**：固定深色 token，不污染浅色主界面；封面模糊背景、歌词高亮、音质弹层、播放列表弹层、状态栏切白。
- **动态 2×2 服务卡片**：读取本地最近播放，显示“继续听”或“发现好音乐”；App 内播放后立即更新，支持系统定点刷新，点击拉起 App。
- **本地示例音频**：`rawfile/demo_loop.wav`（项目自行生成的 24 秒无版权环境循环）；断网时仍可播放，歌词页提示“示例音频，无歌词”。
- **本地音乐导入**：我的 → 设置 → 本地音乐，可从系统文件选择器导入自己合法持有的 MP3 / FLAC / M4A / AAC / WAV / OGG；文件复制到应用私有目录，支持播放和删除，不上传、不提交仓库。
- **网络 API 与兜底**：搜索、推荐、歌单、歌词；请求带 10 秒连接/读取超时；搜索区分“无结果 / 网络失败”；首页失败时展示本地精选并可重试；搜索/歌单/收藏标记 VIP/付费歌曲，支持“只看可播放”，上一首/下一首自动跳过不可播放曲目。
- **品牌资源**：清听应用名、珊瑚渐变 + 声波分层图标、启动图、卡片名。

## 背景设置

1. 进入「我的 → 设置 → 背景设置」。
2. 点「选择背景图片」从系统相册选图，或在「推荐背景」横滑列表中点选内置图片。
3. 拖动「透明度」滑块调节遮罩强度（5%–60%），数值越高背景越淡、文字越清楚。
4. 点「恢复默认背景」清除设置。

背景会显示在主界面、搜索、收藏和歌单页；这些页面的歌曲列表会随背景透明化。所有背景统一按 `ImageFit.Cover` 裁切填充，不会拉伸；播放页固定深色沉浸，不受背景设置影响。

内置背景来自 [Pexels](https://www.pexels.com/)，按 [Pexels License](https://www.pexels.com/license/) 免费使用，文件与作者/来源对应关系见 [背景图来源](docs/背景图来源.md)。

## 构建与运行

环境要求：DevEco Studio、HarmonyOS SDK `6.1.0(23)`。模拟器接受未签名 HAP；真机需要配置自己的调试签名。

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

首次启动按欢迎页 → 登录页顺序进入，使用演示账号 `demo / 123456` 登录。

> 工程路径不要包含中文，否则 hvigor 会拒绝构建。

## 本地单元测试

```sh
export DEVECO_SDK_HOME="D:/DevEco Studio/sdk"
"D:/DevEco Studio/tools/hvigor/bin/hvigorw.bat" test --mode module -p module=entry@default -p product=default
```

结果查看 `entry/.test/default/intermediates/test/coverage_data/test_result.txt`（hvigor 在测试失败时也可能返回 0）。完整模拟器验收矩阵见 [模拟器验收测试记录](docs/验收测试记录.md)。

## 服务卡片

1. 回到桌面，长按空白区域 → “编辑桌面” → “卡片”。
2. 在卡片选择器搜索“清听”，选择“清听 · 最近播放” → “添加至桌面”。
3. 在 App 内播放任意歌曲，回到桌面可看到卡片更新为最近播放。
4. 点击卡片会拉起 `EntryAbility`：已登录进入主界面，未登录先到登录页。

## 在线播放与版权说明

很多歌显示“暂无可用播放地址”，这是网易云公开接口的**版权/会员限制**，不是 URL 拼接错误。实测同一批搜索接口返回的 `fee`/`privilege` 字段：

- 搜索 "jay" 前 30 首里，24 首 `fee:1`（VIP/付费），4 首 `fee:8`（免费），2 首免费；
- VIP 歌曲请求播放地址返回 `code:-110`、`url:null`、`privilege.pl:0`；
- 免费歌曲（如 JAY、屋顶）能正常返回 URL 并播放；
- 旧的 `song/media/outer/url` 外链对 VIP 会 302 到 404，不是可行的绕过方式；
- 用未登录的匿名请求，会员歌曲不会给地址。

本 App 的取舍是**不绕过会员/版权**，而是：

1. 在搜索、歌单、收藏里显示 **VIP / 付费** 标记；
2. 搜索页提供“只看可播放”筛选；
3. 点击 VIP 歌曲直接提示，不再进入播放页空等；
4. 上一首/下一首自动跳过 VIP/付费和无地址歌曲；
5. 按歌曲允许的最高码率请求，免费歌不会先请求 320k 再回退；
6. 自己的正版文件走“本地音乐导入”离线播放。

如果答辩需要这几位歌手的原唱，需要使用你自己已购买/已授权的普通音频文件导入，或使用官方会员服务播放；App 不提供、也不建议接入绕过会员的第三方音源。

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
HarmonyMusicApp/
├── AppScope/                         应用级配置与品牌资源
├── entry/src/main/
│   ├── ets/
│   │   ├── entryability/             EntryAbility：欢迎/登录窗口
│   │   ├── mainability/              MainAbility：主界面、音频、登录门禁
│   │   ├── formability/              2×2 服务卡片生命周期
│   │   ├── pages/                    Welcome/Login/Index/Play/Settings/SongList/LocalMusic
│   │   ├── pages/views/              FavoritesView / ProfileView
│   │   ├── pages/widget/             服务卡片 UI
│   │   ├── components/               PlayerControls / LyricView / SongItem / MiniPlayer / CachedImage
│   │   ├── services/                 Auth / Api / Player / Storage / Widget / ImageCache / LocalMusic 等
│   │   ├── models/                   MusicModel
│   │   └── utils/                    TimeUtils / ToastUtils / ImageUtils
│   └── resources/
│       ├── base/                     图标、启动图等品牌资源
│       └── rawfile/                  本地示例音频、内置背景图
├── docs/                             设计、验收、来源与课程文档
└── README.md
```

## 文档导航

| 文档 | 说明 |
| --- | --- |
| [二次开发方案（Markdown）](docs/二次开发方案.md) | 功能范围、技术方案、验收矩阵 |
| [二次开发方案（HTML）](docs/二次开发方案.html) | 排版版本，含方案审阅入口 |
| [方案审阅报告](docs/方案审阅报告.md) | 对二次开发方案的审查意见 |
| [UI 调研与风格选择](docs/UI调研与风格选择.html) | 四种视觉风格调研与选择 |
| [课程设计要求](docs/课程设计要求.txt) | 课程验收与提交要求 |
| [模拟器验收测试记录](docs/验收测试记录.md) | T01–T19 验收矩阵与增量验证 |
| [背景图来源](docs/背景图来源.md) | Pexels 来源、许可与文件对应关系 |
| [NOTICE](docs/NOTICE.md) | 上游项目与第三方素材署名 |

## 分支与提交

- `main`：基线与最终可提交版本
- `dev`：阶段开发分支；每个阶段完成并验收后提交、推送

## 来源与署名

本项目基于 [wyyhm6](https://github.com/Hanmiao33/wyyhm6)，并参考 [HarmonyPulse](https://github.com/ASweetBite/HarmonyPulse) 的多 Ability 与工程化思路。原始项目未标注许可证，本仓库为课程学习用途的公开仓库；第三方代码和素材的版权归原作者，若原作者要求删除会配合处理。完整说明见 [NOTICE](docs/NOTICE.md)。

内置推荐背景来自 Pexels，具体来源与许可见 [背景图来源](docs/背景图来源.md)；[UI 调研与风格选择](docs/UI调研与风格选择.html) 中的第三方界面截图仅用于课程设计比较，版权归原应用/媒体所有。

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
- 内置背景图按手机竖屏比例（1080×2400）准备；极端宽高比设备会裁切更多画面，但不会拉伸。
- 演示登录为固定账号本地校验，不是真实账号系统。
