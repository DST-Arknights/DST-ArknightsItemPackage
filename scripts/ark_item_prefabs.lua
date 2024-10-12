return {
  {
    prefab = 'ark_item_gold',
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
  -- 合成途径, 有多种
  recipe = {
    {{
      prefab = 'goldnugget',
      count = 1,
    }, {
      prefab = 'goldnugget',
      count = 1,
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