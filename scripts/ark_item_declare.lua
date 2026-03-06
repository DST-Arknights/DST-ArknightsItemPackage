return {{
  prefab = 'ark_gold', -- 龙门币
  disablePutInPack = true,
  template = {
    componentArkCurrentItem = {
      currencyType = 'ark_gold',
      value = 1
    }
  }
}, {
  prefab = 'ark_item_gold1', -- 一张龙门币
  -- 不放入ark_backpack
  disablePutInPack = true,
  template = {
    componentArkCurrentItem = {
      currencyType = 'ark_gold',
      value = 1
    }
  }
}, {
  prefab = 'ark_item_gold2', -- 一叠龙门币
  -- 不放入ark_backpack
  disablePutInPack = true,
  template = {
    componentArkCurrentItem = {
      currencyType = 'ark_gold',
      value = 10000
    }
  },
  recipe = {{{
    prefab = 'ark_gold',
    count = 10000
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 50
  }}}
}, {
  prefab = 'ark_item_gold3', -- 一箱龙门币
  -- 不放入ark_backpack
  disablePutInPack = true,
  template = {
    componentArkCurrentItem = {
      currencyType = 'ark_gold',
      value = 100000
    }
  },
  recipe = {{{
    prefab = 'ark_gold',
    count = 100000
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 100
  }}}
}, {
  prefab = 'ark_item_mtl_sl_shj', -- 烧结核凝晶
  recipe = {{{
    prefab = 'ark_item_mtl_sl_zyk',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_plcf',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_rs',
    count = 2
  }, {
    prefab = 'ark_gold',
    count = 400
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 200
  }}}
}, {
  prefab = 'ark_item_mtl_sl_oeu', -- 晶体电子单元
  recipe = {{{
    prefab = 'ark_item_mtl_sl_oc4',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_pgel4',
    count = 2
  }, {
    prefab = 'ark_item_mtl_sl_iam4',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 400
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 200
  }}}
}, {
  prefab = 'ark_item_mtl_sl_ds', -- D32钢
  recipe = {{{
    prefab = 'ark_item_mtl_sl_manganese2',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_pg2',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_rma7024',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 400
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 200
  }}}
}, {
  prefab = 'ark_item_mtl_sl_bn', -- 双极纳米片
  recipe = {{{
    prefab = 'ark_item_mtl_sl_boss4',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_alcohol2',
    count = 2
  }, {
    prefab = 'ark_gold',
    count = 400
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 200
  }}}
}, {
  prefab = 'ark_item_mtl_sl_pp', -- 聚合剂
  recipe = {{{
    prefab = 'ark_item_mtl_sl_g4',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_iron4',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_ketone4',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 400
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 200
  }}}
}, {
  prefab = 'ark_item_mtl_sl_zyk', -- 转质盐聚块
  recipe = {{{
    prefab = 'ark_item_mtl_sl_zy',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_ss',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_strg3',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 400
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 200
  }}}
}, {
  prefab = 'ark_item_mtl_sl_htt', -- 环烃预制体
  recipe = {{{
    prefab = 'ark_item_mtl_sl_ht',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_xw',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_zy',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}}
}, {
  prefab = 'ark_item_mtl_sl_zy', -- 转质盐组
  template = {
    componentPreservative = {
      percent_increase = TUNING.SALTROCK_PRESERVE_PERCENT_ADD
    },
    componentEdible = {
      foodtype = FOODTYPE.ELEMENTAL,
      healthvalue = TUNING.HEALING_TINY,
      hungervalue = TUNING.CALORIES_SMALL
    }
  },
  drop = {{
    prefab = 'hound',
    adapter = 'AddChanceLoot',
    value = 0.3
  }, {
    prefab = 'icehound',
    adapter = 'AddLoot',
    value = 1
  }, {
    prefab = 'firehound',
    adapter = 'AddLoot',
    value = 1
  }}
}, {
  prefab = 'ark_item_mtl_sl_ht', -- 环烃聚质
  drop = {{
    prefab = 'tentacle',
    adapter = 'AddLoot',
    value = 1
  }, {
    prefab = 'merm',
    adapter = 'AddChanceLoot',
    value = 0.3
  }}
}, {
  prefab = 'ark_item_mtl_sl_plcf', -- 切削原液
  recipe = {{{
    prefab = 'ark_item_mtl_sl_ccf',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_oc3',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_rma7012',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}}
}, {
  prefab = 'ark_item_mtl_sl_xwb', -- 固化纤维板
  recipe = {{{
    prefab = 'ark_item_mtl_sl_xw',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_rush3',
    count = 2
  }, {
    prefab = 'ark_item_mtl_sl_g3',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}}
}, {
  prefab = 'ark_item_mtl_sl_ccf', -- 化合切削液
  drop = {{
    prefab = 'knight',
    adapter = 'AddChanceLoot',
    value = 0.5
  }, {
    prefab = 'bishop',
    adapter = 'AddChanceLoot',
    value = 0.5
  }, {
    prefab = 'rook',
    adapter = 'AddChanceLoot',
    value = 0.5
  }}
}, {
  prefab = 'ark_item_mtl_sl_xw', -- 褐素纤维
  drop = {{
    prefab = 'worm',
    adapter = 'AddLoot',
    value = 1
  }, {
    prefab = 'spider_dropper',
    adapter = 'AddLoot',
    value = 1
  }}
}, {
  prefab = 'ark_item_mtl_sl_rs', -- 精炼溶剂
  recipe = {{{
    prefab = 'ark_item_mtl_sl_ss',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_ccf',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_pgel3',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}}
}, {
  prefab = 'ark_item_mtl_sl_ss', -- 半自然溶剂
  drop = {{
    prefab = 'slurper',
    adapter = 'AddLoot',
    value = 1
  }, {
    prefab = 'batilisk',
    adapter = 'AddChanceLoot',
    value = 0.3
  }}
}, {
  prefab = 'ark_item_mtl_sl_oc4', -- 晶体电路
  recipe = {{{
    prefab = 'ark_item_mtl_sl_oc3',
    count = 2
  }, {
    prefab = 'ark_item_mtl_sl_pgel3',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_iam3',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}}
}, {
  prefab = 'ark_item_mtl_sl_oc3', -- 晶体元件
  drop = {{
    prefab = 'slurtle',
    adapter = 'AddLoot',
    value = 1
  }, {
    prefab = 'snurtle',
    adapter = 'AddLoot',
    value = 1
  }}
}, {
  prefab = 'ark_item_mtl_sl_iam4', -- 炽合金块
  recipe = {{{
    prefab = 'ark_item_mtl_sl_boss3',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_pg1',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_iam3',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}}
}, {
  prefab = 'ark_item_mtl_sl_iam3', -- 炽合金
  drop = {{
    prefab = 'firehound',
    adapter = 'AddLoot',
    value = 1
  }, {
    prefab = 'spat',
    adapter = 'AddChanceLoot',
    value = 0.3
  }}
}, {
  prefab = 'ark_item_mtl_sl_pgel4', -- 聚合凝胶
  recipe = {{{
    prefab = 'ark_item_mtl_sl_iron3',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_pgel3',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_iam3',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}}
}, {
  prefab = 'ark_item_mtl_sl_pgel3', -- 凝胶
  drop = {{
    prefab = 'frog',
    adapter = 'AddChanceLoot',
    value = 0.3
  }, {
    prefab = 'mosquito',
    adapter = 'AddChanceLoot',
    value = 0.3
  }, {
    prefab = 'snurtle',
    adapter = 'AddChanceLoot',
    value = 0.5
  }}
}, {
  prefab = 'ark_item_mtl_sl_alcohol2', -- 白马醇
  recipe = {{{
    prefab = 'ark_item_mtl_sl_alcohol1',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_strg3',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_rma7012',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}}
}, {
  prefab = 'ark_item_mtl_sl_alcohol1', -- 扭转醇
  drop = {{
    prefab = 'merm',
    adapter = 'AddChanceLoot',
    value = 0.5
  }, {
    prefab = 'frog',
    adapter = 'AddChanceLoot',
    value = 0.3
  }}
}, {
  prefab = 'ark_item_mtl_sl_manganese2', -- 三水锰矿
  recipe = {{{
    prefab = 'ark_item_mtl_sl_manganese1',
    count = 2
  }, {
    prefab = 'ark_item_mtl_sl_rush3',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_alcohol1',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}}
}, {
  prefab = 'ark_item_mtl_sl_manganese1', -- 轻锰矿
  drop = {{
    prefab = 'rock2',
    adapter = 'AddChanceLoot',
    value = 0.2
  }, {
    prefab = 'rock1',
    adapter = 'AddChanceLoot',
    value = 0.1
  }}
}, {
  prefab = 'ark_item_mtl_sl_pg2', -- 五水研磨石
  recipe = {{{
    prefab = 'ark_item_mtl_sl_pg1',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_iron3',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_boss3',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}}
}, {
  prefab = 'ark_item_mtl_sl_pg1', -- 研磨石
  drop = {{
    prefab = 'rock1',
    adapter = 'AddChanceLoot',
    value = 0.15
  }, {
    prefab = 'rock_flintless',
    adapter = 'AddChanceLoot',
    value = 0.2
  }}
}, {
  prefab = 'ark_item_mtl_sl_rma7024', -- RMA70-24
  recipe = {{{
    prefab = 'ark_item_mtl_sl_rma7012',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_g3',
    count = 2
  }, {
    prefab = 'ark_item_mtl_sl_ketone3',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}}
}, {
  prefab = 'ark_item_mtl_sl_rma7012', -- RMA70-12
  drop = {{
    prefab = 'crawlinghorror',
    adapter = 'AddLoot',
    value = 1
  }, {
    prefab = 'terrorbeak',
    adapter = 'AddLoot',
    value = 1
  }}
}, {
  prefab = 'ark_item_mtl_sl_g4', -- 提纯源岩
  recipe = {{{
    prefab = 'ark_item_mtl_sl_g3',
    count = 4
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}}
}, {
  prefab = 'ark_item_mtl_sl_g3', -- 固源岩组
  recipe = {{{
    prefab = 'ark_item_mtl_sl_g2',
    count = 5
  }, {
    prefab = 'ark_gold',
    count = 200
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 10
  }}}
}, {
  prefab = 'ark_item_mtl_sl_g2', -- 固源岩
  recipe = {{{
    prefab = 'ark_item_mtl_sl_g1',
    count = 3
  }, {
    prefab = 'ark_gold',
    count = 100
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 5
  }}}
}, {
  prefab = 'ark_item_mtl_sl_g1', -- 源岩
  drop = {{
    prefab = 'rock1',
    adapter = 'AddLoot',
    value = 2
  }, {
    prefab = 'rock1',
    adapter = 'AddChanceLoot',
    value = 0.1
  }, {
    prefab = 'rock2',
    adapter = 'AddChanceLoot',
    value = 0.1
  }, {
    prefab = 'rock_flintless',
    adapter = 'AddLoot',
    value = 4
  }, {
    prefab = 'rock_flintless_med',
    adapter = 'AddLoot',
    value = 2
  }, {
    prefab = 'rock_flintless_low',
    adapter = 'AddLoot',
    value = 1
  }, {
    prefab = 'cavein_boulder',
    adapter = 'AddLoot',
    value = 2
  }}
}, {
  prefab = 'ark_item_mtl_sl_boss4', -- 改量装置
  recipe = {{{
    prefab = 'ark_item_mtl_sl_boss3',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_g3',
    count = 2
  }, {
    prefab = 'ark_item_mtl_sl_pg1',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}}
}, {
  prefab = 'ark_item_mtl_sl_boss3', -- 全新装置
  recipe = {{{
    prefab = 'ark_item_mtl_sl_boss2',
    count = 4
  }, {
    prefab = 'ark_gold',
    count = 200
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 10
  }}}
}, {
  prefab = 'ark_item_mtl_sl_boss2', -- 装置
  recipe = {{{
    prefab = 'ark_item_mtl_sl_boss1',
    count = 3
  }, {
    prefab = 'ark_gold',
    count = 100
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 5
  }}}
}, {
  prefab = 'ark_item_mtl_sl_boss1', -- 破损装置
  drop = {{
    prefab = 'knight',
    adapter = 'AddLoot',
    value = 1
  }, {
    prefab = 'bishop',
    adapter = 'AddLoot',
    value = 1
  }, {
    prefab = 'rook',
    adapter = 'AddLoot',
    value = 2
  }}
}, {
  prefab = 'ark_item_mtl_sl_rush4', -- 聚酸酯块
  recipe = {{{
    prefab = 'ark_item_mtl_sl_rush3',
    count = 2
  }, {
    prefab = 'ark_item_mtl_sl_ketone3',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_alcohol1',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}},
  template = {
    MakeSmallBurnable = {
      time = 20
    },
    ComponentFuel = {
      fuelvalue = TUNING.HUGE_FUEL
    }
  }
}, {
  prefab = 'ark_item_mtl_sl_rush3', -- 聚酸酯组
  recipe = {{{
    prefab = 'ark_item_mtl_sl_rush2',
    count = 4
  }, {
    prefab = 'ark_gold',
    count = 200
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 10
  }}},
  drop = {{
    prefab = 'spider',
    adapter = 'AddChanceLoot',
    value = 0.1
  }, {
    prefab = 'spider_warrior',
    adapter = 'AddChanceLoot',
    value = 0.2
  }, {
    prefab = 'lureplant',
    adapter = 'AddLoot',
    value = 1
  }},
  template = {
    MakeSmallBurnable = {
      time = 10
    },
    ComponentFuel = {
      fuelvalue = TUNING.LARGE_FUEL
    }
  }
}, {
  prefab = 'ark_item_mtl_sl_rush2', -- 聚酸酯
  recipe = {{{
    prefab = 'ark_item_mtl_sl_rush1',
    count = 3
  }, {
    prefab = 'ark_gold',
    count = 100
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 5
  }}},
  template = {
    MakeSmallBurnable = {
      time = 10
    },
    ComponentFuel = {
      fuelvalue = TUNING.MED_FUEL
    }
  }
}, {
  prefab = 'ark_item_mtl_sl_rush1', -- 酯原料
  template = {
    ComponentFuel = {
      fuelvalue = TUNING.TINY_FUEL
    },
    MakeSmallBurnable = {
      time = 5
    }
  },
  drop = {{
    prefab = 'spider',
    adapter = 'AddChanceLoot',
    value = 0.3
  }, {
    prefab = 'spider_warrior',
    adapter = 'AddChanceLoot',
    value = 0.5
  }, {
    prefab = 'lureplant',
    adapter = 'AddLoot',
    value = 2
  }}
}, {
  prefab = 'ark_item_mtl_sl_strg4', -- 糖聚块
  recipe = {{{
    prefab = 'ark_item_mtl_sl_strg3',
    count = 2
  }, {
    prefab = 'ark_item_mtl_sl_iron3',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_manganese1',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}},
  template = {
    componentEdible = {
      foodtype = FOODTYPE.GENERIC,
      hungervalue = TUNING.CALORIES_SMALL,
      healthvalue = TUNING.HEALING_LARGE,
      sanityvalue = -TUNING.SANITY_LARGE,
      oneatenbuffs = {'healthregenbuff'}
    },
    componentCookable = {}
  }
}, {
  prefab = 'ark_item_mtl_sl_strg3', -- 糖组
  recipe = {{{
    prefab = 'ark_item_mtl_sl_strg2',
    count = 4
  }, {
    prefab = 'ark_gold',
    count = 200
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 10
  }}},
  template = {
    componentEdible = {
      foodtype = FOODTYPE.GENERIC,
      hungervalue = TUNING.CALORIES_SMALL,
      healthvalue = TUNING.HEALING_LARGE,
      sanityvalue = TUNING.SANITY_MED
    },
    componentCookable = {}
  }
}, {
  prefab = 'ark_item_mtl_sl_strg2', -- 糖
  recipe = {{{
    prefab = 'ark_item_mtl_sl_strg1',
    count = 3
  }, {
    prefab = 'ark_gold',
    count = 100
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 5
  }}},
  template = {
    componentEdible = {
      foodtype = FOODTYPE.GENERIC,
      hungervalue = TUNING.CALORIES_SMALL,
      healthvalue = TUNING.HEALING_MED,
      sanityvalue = TUNING.SANITY_MED
    },
    componentCookable = {}
  }
}, {
  prefab = 'ark_item_mtl_sl_strg1', -- 代糖
  template = {
    componentEdible = {
      foodtype = FOODTYPE.GENERIC,
      hungervalue = TUNING.CALORIES_TINY,
      healthvalue = TUNING.HEALING_SMALL
    },
    componentCookable = {}
  },
  drop = {{
    prefab = 'bee',
    adapter = 'AddLoot',
    value = 1
  }}
}, {
  prefab = 'ark_item_mtl_sl_iron4', -- 异铁块
  recipe = {{{
    prefab = 'ark_item_mtl_sl_iron3',
    count = 2
  }, {
    prefab = 'ark_item_mtl_sl_boss3',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_rush3',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}},
  drop = {{
    prefab = 'rock_moon_shell',
    adapter = 'AddChanceLoot',
    value = 0.5
  }}
}, {
  prefab = 'ark_item_mtl_sl_iron3', -- 异铁组
  recipe = {{{
    prefab = 'ark_item_mtl_sl_iron2',
    count = 4
  }, {
    prefab = 'ark_gold',
    count = 200
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 10
  }}},
  drop = {{
    prefab = 'rock_moon',
    adapter = 'AddChanceLoot',
    value = 0.5
  }, {
    prefab = 'rock_moon_shell',
    adapter = 'AddLoot',
    value = 1
  }}
}, {
  prefab = 'ark_item_mtl_sl_iron2', -- 异铁
  recipe = {{{
    prefab = 'ark_item_mtl_sl_iron1',
    count = 3
  }, {
    prefab = 'ark_gold',
    count = 100
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 5
  }}},
  drop = {{
    prefab = 'rock2',
    adapter = 'AddChanceLoot',
    value = 0.15
  }, {
    prefab = 'rock1',
    adapter = 'AddChanceLoot',
    value = 0.35
  }, {
    prefab = 'rock_moon',
    adapter = 'AddChanceLoot',
    value = 0.7
  }, {
    prefab = 'rock_moon_shell',
    adapter = 'AddLoot',
    value = 1
  }}
}, {
  prefab = 'ark_item_mtl_sl_iron1', -- 异铁碎片
  drop = {{
    prefab = 'rock2',
    adapter = 'AddChanceLoot',
    value = 0.25
  }, {
    prefab = 'rock1',
    adapter = 'AddChanceLoot',
    value = 0.5
  }, {
    prefab = 'rock_moon',
    adapter = 'AddChanceLoot',
    value = 0.5
  }, {
    prefab = 'rock_moon_shell',
    adapter = 'AddLoot',
    value = 1
  }}
}, {
  prefab = 'ark_item_mtl_sl_ketone4', -- 酮阵列
  recipe = {{{
    prefab = 'ark_item_mtl_sl_ketone3',
    count = 2
  }, {
    prefab = 'ark_item_mtl_sl_strg3',
    count = 1
  }, {
    prefab = 'ark_item_mtl_sl_manganese1',
    count = 1
  }, {
    prefab = 'ark_gold',
    count = 300
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 20
  }}},
  template = {
    componentFuelExplosive = {}
  },
  drop = {{
    prefab = 'bearger',
    adapter = 'AddChanceLoot',
    value = 0.2
  },{
    prefab = 'dragonfly',
    adapter = 'AddChanceLoot',
    value = 0.2
  },{
    prefab = 'deerclops',
    adapter = 'AddChanceLoot',
    value = 0.2
  },{
    prefab = 'moose',
    adapter = 'AddChanceLoot',
    value = 0.2
  }}
}, {
  prefab = 'ark_item_mtl_sl_ketone3', -- 酮凝集组
  recipe = {{{
    prefab = 'ark_item_mtl_sl_ketone2',
    count = 4
  }, {
    prefab = 'ark_gold',
    count = 200
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 10
  }}},
  ingredientValues = {
    tags = {
      meat = 4
    },
  },
  template = {
    componentFuelExplosive = {},
  },
  drop = {{
    prefab = 'beefalo',
    adapter = 'AddChanceLoot',
    value = 0.4
  },{
    prefab = 'spat',
    adapter = 'AddChanceLoot',
    value = 0.4
  },{
    prefab = 'crabking',
    adapter = 'AddChanceLoot',
    value = 0.4
  },{
    prefab = 'koalefant_summer',
    adapter = 'AddChanceLoot',
    value = 0.4
  },{
    prefab = 'koalefant_winter',
    adapter = 'AddChanceLoot',
    value = 0.4
  },{
    prefab = 'bearger',
    adapter = 'AddChanceLoot',
    value = 0.4
  },{
    prefab = 'dragonfly',
    adapter = 'AddChanceLoot',
    value = 0.4
  },{
    prefab = 'deerclops',
    adapter = 'AddChanceLoot',
    value = 0.4
  },{
    prefab = 'moose',
    adapter = 'AddChanceLoot',
    value = 0.4
  }}
}, {
  prefab = 'ark_item_mtl_sl_ketone2', -- 酮凝集
  recipe = {{{
    prefab = 'ark_item_mtl_sl_ketone1',
    count = 3
  }, {
    prefab = 'ark_gold',
    count = 100
  }, {
    prefab = CHARACTER_INGREDIENT.SANITY,
    count = 5
  }}},
  template = {
    componentEdible = {
      foodtype = FOODTYPE.GENERIC,
      hungervalue = TUNING.CALORIES_MEDSMALL,
      healthvalue = -TUNING.HEALING_MEDLARGE,
      sanityvalue = -TUNING.SANITY_MEDLARGE
    },
    ComponentFuel = {
      fuelvalue = TUNING.HUGE_FUEL
    },
    MakeLargeBurnable = {
      time = 10
    }
  },
  drop = {{
    prefab = 'pigman',
    adapter = 'AddLoot',
    value = 1
  },{
    prefab = 'pigguard',
    adapter = 'AddLoot',
    value = 1
  },{
    prefab = 'bunnyman',
    adapter = 'AddLoot',
    value = 1
  },{
    prefab = 'walrus',
    adapter = 'AddLoot',
    value = 1
  },{
    prefab = 'little_walrus',
    adapter = 'AddLoot',
    value = 1
  },{
    prefab = 'tallbird',
    adapter = 'AddLoot',
    value = 1
  },{
    prefab = 'babybeefalo',
    adapter = 'AddLoot',
    value = 1
  },{
    prefab = 'beefalo',
    adapter = 'AddLoot',
    value = 3
  },{
    prefab = 'spat',
    adapter = 'AddLoot',
    value = 3
  },{
    prefab = 'crabking',
    adapter = 'AddLoot',
    value = 3
  },{
    prefab = 'koalefant_summer',
    adapter = 'AddLoot',
    value = 4
  },{
    prefab = 'koalefant_summer',
    adapter = 'AddChanceLoot',
    value = 0.4
  },{
    prefab = 'koalefant_winter',
    adapter = 'AddLoot',
    value = 4
  },{
    prefab = 'koalefant_winter',
    adapter = 'AddChanceLoot',
    value = 0.4
  },{
    prefab = 'bearger',
    adapter = 'AddLoot',
    value = 4
  },{
    prefab = 'bearger',
    adapter = 'AddChanceLoot',
    value = 0.4
  },{
    prefab = 'dragonfly',
    adapter = 'AddLoot',
    value = 4
  },{
    prefab = 'dragonfly',
    adapter = 'AddChanceLoot',
    value = 0.4
  },{
    prefab = 'deerclops',
    adapter = 'AddLoot',
    value = 4
  },{
    prefab = 'deerclops',
    adapter = 'AddChanceLoot',
    value = 0.4
  },{
    prefab = 'moose',
    adapter = 'AddLoot',
    value = 4
  },{
    prefab = 'moose',
    adapter = 'AddChanceLoot',
    value = 0.4
  }},
  ingredientValues = {
    tags = {
      meat = 4
    },
  }
}, {
  prefab = 'ark_item_mtl_sl_ketone1', -- 双酮
  template = {
    componentEdible = {
      foodtype = FOODTYPE.GENERIC,
      hungervalue = TUNING.CALORIES_TINY,
      healthvalue = -TUNING.HEALING_MEDSMALL,
      sanityvalue = -TUNING.SANITY_TINY
    },
    ComponentFuel = {
      fuelvalue = TUNING.SMALL_FUEL
    },
    MakeSmallBurnable = {
      time = 5
    },
  },
  drop = {{
    prefab = 'rabbit',
    adapter = 'AddChanceLoot',
    value = 0.5
  },{
    prefab = 'mole',
    adapter = 'AddChanceLoot',
    value = 0.5
  },{
    prefab = 'monkey',
    adapter = 'AddChanceLoot',
    value = 0.5
  },{
    prefab = 'penguin',
    adapter = 'AddChanceLoot',
    value = 0.5
  }}
}, {
  prefab = 'ark_item_mtl_skill1', -- 技巧概要·卷1
  disablePutInPack = true
}, {
  prefab = 'ark_item_mtl_skill2', -- 技巧概要·卷2
  disablePutInPack = true
}, {
  prefab = 'ark_item_mtl_skill3', -- 技巧概要·卷3
  disablePutInPack = true
}}
