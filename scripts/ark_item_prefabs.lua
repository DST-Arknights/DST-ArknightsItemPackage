return {
  {
    prefab = 'ark_item_gold',
    group = 'base1',
    recipe = {
      {{
        prefab = 'ark_gold',
        count = 100,
      }},
    },
    i18n = {
      ['zh'] = {
        name = '一小捆龙门币',
        description = '使用可以增加一小捆龙门币',
      },
    }
  },
  {
  -- 物品名称
  prefab = 'ark_item_xpzj',
  group = 'base2',
  -- 合成途径, 有多种
  recipe = {
    {{
      prefab = 'goldnugget',
      count = 3,
    }},
  },
  -- 掉落生物
  drop = {
    {
      prefab = 'spider',
      adapter = 'AddRandomLoot',
      args = { 0.7 },
    }
  },
  i18n = {
    ['zh'] = {
      name = '芯片助剂',
      description = '这是一块芯片助剂',
    },
  }
}}