# DST-ArknightsItemPackage

## 说明

本项目是游戏《饥荒》的 关于《明日方舟》模组的材料扩展包。

## 支持功能

* 基础材料的获取与合成系统
* 货币系统

### 基础材料

* 当前版本设定基础材料由生物死亡时掉落, 掉落生物与概率根据配置决定。
* 建筑 "罗德岛加工站" 用于材料的合成。
* 仓库 "罗德岛仓库" 用于存储材料。
* 背包 "罗德岛背包" 用于携带材料。
#### 基础材料配置示例

添加材料时, 需要准备三样东西
* 在 `exported/ark_item/ark_item.scml` 中添加材料的动画
* 在 `images/ark_item/[prefab].png` 中添加材料的物品栏图片
* 在 `scripts/ark_item_prefabs.lua` 中添加材料的配置

其中, scml里的动画名称需要与配置文件中的prefab一致, 且图片名称也需要与prefab一致

配置文件位于 `srripts/ark_item_prefabs.lua` 中, 以下是一个示例配置
```lua
return {{ -- 返回数组结构
  prefab = 'xpzj', -- 物品唯一标识符
  recipe = { -- 合成配方
    {{
      prefab = 'goldnugget', -- 合成需要的物品代码
      count = 1, -- 合成需要的物品数量
    }, {
      prefab = 'slime',
      count = 1,
    }},
  },
  -- 掉落生物
  drop = {
    {
      prefab = 'spider', -- 从这个生物身上掉落
      adapter = 'AddRandomLoot', -- 掉落适配器, 不填默认AddRandomLoot 随机掉落
      args = { 0.7 }, -- 掉落参数
    }
  },
  i18n = { -- 多语言配置
    ['en'] = {
      name = 'Chip Aid',
      description = 'This is a chip aid',
      STRINGS = {
      }
    },
    ['zh'] = {
      name = '芯片助剂', -- 名称
      description = '这是一块芯片助剂', -- 检查描述
      STRINGS = { -- 可合并STRINGS表
      }
    },
  }
}}
```


### 货币系统
* 当前只暂时先支持龙门币系统
* 击杀生物时,击杀玩家获得生物血量数量的龙门币
* 允许玩家交易龙门币

## 打包与运行

放到游戏的mod文件夹下, 使用官方的自动打包工具打包即可