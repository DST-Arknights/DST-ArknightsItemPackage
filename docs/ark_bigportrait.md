# 动态大立绘

`RegisterArkBigPortraitAnim(character, config)` 为角色注册动态大立绘，对应原版 `bigportraits` 素材的用途。同一份配置用于入服选人界面，以及游戏内查看玩家资料和玩家列表打开的资料卡。不包含小头像、图鉴和选人后的换装页面。

## 注册

在角色模组的 `modmain.lua` 或其 `modimport` 文件中调用。如果已有 `Assets = {...}` 声明，将注册放在最终声明之后；注册后不要重新覆盖 `Assets` 表。

```lua
RegisterArkBigPortraitAnim("my_character", {
  asset = "anim/my_character_bigportrait.zip",
  bank = "my_character_bigportrait",
  build = "my_character_bigportrait",
  anim = { "enter", "idle" },
  scale = 1,
  offset = { 0, 0 },
})
```

| 配置项 | 说明 | 默认值 |
| --- | --- | --- |
| `asset` | 相对于角色模组根目录的动画 ZIP 路径 | 必填 |
| `bank` | 动画 bank | 必填 |
| `build` | 动画 build | 必填 |
| `anim` | 动画名字符串或非空、连续的动画名数组 | 必填 |
| `scale` | 相对于原立绘局部缩放的倍率，须为正数 | `1` |
| `offset` | 相对于原立绘位置的偏移，使用其父 Widget 的 UI 坐标 | `{ 0, 0 }` |

接口自动向调用角色模组的 `Assets` 插入 `Asset("ANIM", asset)`，同一模组同一路径不重复插入；没有 `Assets` 表时自动创建。资源在角色模组中提供，无需再手动声明此动画的 `Asset`。同一个角色重复注册会报错。接口只能在模组初始化阶段调用。

## 播放

- `anim = "idle"`：循环播放 `idle`。
- `anim = { "enter", "idle" }`：`enter` 播放一次，随后循环 `idle`。
- `anim = { "enter", "transition", "idle" }`：前两个依次播放一次，随后循环最后一个。

切换到该角色、重新打开选人页面或玩家资料卡时从第一项开始。同角色重复刷新不重启动画；资料卡的定期皮肤和装备更新也不会重播入场动画。各界面实例独立播放。切换到未注册角色（包括默认随机项）时恢复静态立绘。

资料卡使用原版解析后的 `currentcharacter` 选取配置，保留未选角色 `notselected` 和缺失模组资源 `unknownmod` 的降级行为。动态动画仍按角色注册，皮肤变化复用同一段动画；原版静态皮肤立绘、装备槽和角色人偶继续更新。

## 与其他模组共存

原来的立绘 Image（选人页 `selectedportrait.portrait`、资料卡 `portrait`）、父级和纹理更新全部保留，动态立绘显示时仅隐藏原图。接入使用 `ArkHookFunction`，保留 `SetPortrait` / `UpdateData` 调用链，不替换原 Image，不改写全局立绘加载函数。

独立 `UIAnim` 添加到原 Image 的父 Widget 下，与原图互斥显示，位于现有兄弟节点下方，不重排已有元素，也不参与鼠标点击。资料卡的背景位于外层，动画保留在背景上方。原 Image 的位置、局部缩放、旋转、颜色和 `Show` / `Hide` 操作会同步到动画；`MoveTo`、`ScaleTo`、`RotateTo` 等补间以及 `SetFadeAlpha` 淡出也会同步。退出或重建页面时，动画随父 Widget 一起销毁。资料卡重新布局生成新 Image 时，自动绑定新图并清理本功能的旧动画。
