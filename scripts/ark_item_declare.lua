return {
  {
  --   prefab = 'ark_item_gold1',
  --   -- 不放入ark_item_pack
  --   disablePutInPack = true,
  --   recipe = {{{
  --     prefab='ark_gold', count=1
  --   }, {
  --     prefab=CHARACTER_INGREDIENT.SANITY, count=5
  --   }}},
  --   i18n = {
  --     ['zh'] = {
  --       name = '一张龙门币',
  --       description = '由龙门发行的货币，用途广泛。使用后获得1龙门币',
  --       recipeDescription = '把这个送给朋友',
  --     }
  --   }
  -- }, {
    prefab = 'ark_item_gold2',
    -- 不放入ark_item_pack
    disablePutInPack = true,
    recipe = {{{
      prefab='ark_gold', count=10000
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=50
    }}},
    i18n = {
      ['zh'] = {
        name = '一叠龙门币',
        description = '由龙门发行的货币，用途广泛。使用后获得一万龙门币',
        recipeDescription = '把这个送给朋友',
      }
    }
  }, {
    prefab = 'ark_item_gold3',
    -- 不放入ark_item_pack
    disablePutInPack = true,
    recipe = {{{
      prefab='ark_gold', count=100000
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=100
    }}},
    i18n = {
      ['zh'] = {
        name = '一箱龙门币',
        description = '由龙门发行的货币，用途广泛。使用后获得十万龙门币',
        recipeDescription = '你是不是觉得自己暴富了？',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_shj',
    recipe = {{{
      prefab='ark_item_mtl_sl_zyk', count=1
    }, {
      prefab='ark_item_mtl_sl_plcf', count=1
    }, {
      prefab='ark_item_mtl_sl_rs', count=2
    }, {
      prefab='ark_gold', count=400
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=200
    }}},
    i18n = {
      ['zh'] = {
        name = '烧结核凝晶',
        description = '对工艺要求极高的现代科技产物。用于高级强化场合。',
        recipeDescription = '特定高温环境下具有分子识别能力的材料。作为助剂能选择性地吸附源石，为精密加工源石材料、降低源石器件耗能提供新可能。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_oeu',
    recipe = {{{
      prefab='ark_item_mtl_sl_oc4', count=1
    }, {
      prefab='ark_item_mtl_sl_pgel4', count=2
    }, {
      prefab='ark_item_mtl_sl_iam4', count=1
    }, {
      prefab='ark_gold', count=400
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=200
    }}},
    i18n = {
      ['zh'] = {
        name = '晶体电子单元',
        description = '昂贵的源石工业产品，用于重要的强化场合。',
        recipeDescription = '泰拉源石科技的结晶，泰拉工业现代化的代表。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_ds',
    recipe = {{{
      prefab='ark_item_mtl_sl_manganese2', count=1
    }, {
      prefab='ark_item_mtl_sl_pg2', count=1
    }, {
      prefab='ark_item_mtl_sl_rma7024', count=1
    }, {
      prefab='ark_gold', count=400
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=200
    }}},
    i18n = {
      ['zh'] = {
        name = 'D32钢',
        description = '自然界中不应存在的人造金属材料，呈固态。用于高级强化场合。',
        recipeDescription = '强度超群，无法击穿。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_bn',
    recipe = {{{
      prefab='ark_item_mtl_sl_boss4', count=1
    }, {
      prefab='ark_item_mtl_sl_alcohol2', count=2
    }, {
      prefab='ark_gold', count=400
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=200
    }}},
    i18n = {
      ['zh'] = {
        name = '双极纳米片',
        description = '现代工业的创造力结晶。用于高级强化场合。',
        recipeDescription = '对范围内源石敏感的装置。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_pp',
    recipe = {{{
      prefab='ark_item_mtl_sl_g4', count=1
    }, {
      prefab='ark_item_mtl_sl_iron4', count=1
    }, {
      prefab='ark_item_mtl_sl_ketone4', count=1
    }, {
      prefab='ark_gold', count=400
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=200
    }}},
    i18n = {
      ['zh'] = {
        name = '聚合剂',
        description = '复杂的液态工业产物。用于高级强化场合。',
        recipeDescription = '精密穿戴着装中常用的材料。强大的聚合粘接效果足以阻断源石的挥发。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_zyk',
    recipe = {{{
      prefab='ark_item_mtl_sl_zy', count=1
    }, {
      prefab='ark_item_mtl_sl_ss', count=1
    }, {
      prefab='ark_item_mtl_sl_strg3', count=1
    }, {
      prefab='ark_gold', count=400
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=200
    }}},
    i18n = {
      ['zh'] = {
        name = '转质盐聚块',
        description = '经过精炼处理的化合物结晶块。用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '稳定的结晶体，可为材料提供多种功能。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_htt',
    recipe = {{{
      prefab='ark_item_mtl_sl_ht', count=1
    }, {
      prefab='ark_item_mtl_sl_xw', count=1
    }, {
      prefab='ark_item_mtl_sl_zy', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '环烃预制体',
        description = '由多种优良材料预加工而成的工业用材。可用于多种强化场合。',
        recipeDescription = '在合成流程中加入多种优良材料而得到的工业产品。在防护领域具有广阔应用前景。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_zy',
    i18n = {
      ['zh'] = {
        name = '转质盐组',
        description = '经过粗炼处理的化合物结晶。可用于多种强化场合。',
        recipeDescription = '注意为工业用盐，绝对不可以食用。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_ht',
    i18n = {
      ['zh'] = {
        name = '环烃聚质',
        description = '一种耐热性、耐化学性俱优的工业材料。可用于多种强化场合。',
        recipeDescription = '在实验室内诞生的新型透明材料，将成为许多传统材料的优质替代品。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_plcf',
    recipe = {{{
      prefab='ark_item_mtl_sl_ccf', count=1
    }, {
      prefab='ark_item_mtl_sl_oc3', count=1
    }, {
      prefab='ark_item_mtl_sl_rma7012', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '切削原液',
        description = '由多种活性溶剂配置而成的原液。用于高级强化场合。',
        recipeDescription = '一种生物性稳定良好的原液。储存时需要注意避免其他杂质的混入。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_xwb',
    recipe = {{{
      prefab='ark_item_mtl_sl_xw', count=1
    }, {
      prefab='ark_item_mtl_sl_rush3', count=2
    }, {
      prefab='ark_item_mtl_sl_g3', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '固化纤维板',
        description = '经过塑形固化处理的特种纤维板。可用于多种强化场合。',
        recipeDescription = '用特殊工艺制作的复合纤维板。在许多工业流程中不可替代。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_ccf',
    i18n = {
      ['zh'] = {
        name = '化合切削液',
        description = '一种金属加工时必备的工业试剂。可用于多种强化场合。',
        recipeDescription = '在加工过程中起到润滑吸热效用，可提高金属制品的成品合格率。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_xw',
    i18n = {
      ['zh'] = {
        name = '褐素纤维',
        description = '具备高强度与高模量的特种纤维束。可用于多种强化场合。',
        recipeDescription = '源石工业的衍生产物，因其优异的性能在工业领域被广泛应用。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_rs',
    recipe = {{{
      prefab='ark_item_mtl_sl_ss', count=1
    }, {
      prefab='ark_item_mtl_sl_ccf', count=1
    }, {
      prefab='ark_item_mtl_sl_pgel3', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '精炼溶剂',
        description = '经特殊工艺制作而成特殊涂料。用于高级强化场合。',
        recipeDescription = '由高分子聚合物支撑的涂料。除了基础防护功能外，还兼有某些特性。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_ss',
    i18n = {
      ['zh'] = {
        name = '半自然溶剂',
        description = '一种物理性能优异，耐酸碱性良好的活性溶剂。可用于多种强化场合。',
        recipeDescription = '在对传统溶剂制品进行现代化加工后，该溶剂呈现出了优良性质。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_oc4',
    recipe = {{{
      prefab='ark_item_mtl_sl_oc3', count=2
    }, {
      prefab='ark_item_mtl_sl_pgel3', count=1
    }, {
      prefab='ark_item_mtl_sl_iam3', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '晶体电路',
        description = '重要的源石工业材料，可用于多种强化场合，是制作源石晶体单元的基础元件。',
        recipeDescription = '现代源石电子产业的核心产品。晶体电路的大量使用也是泰拉工业现代化的体现。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_oc3',
    i18n = {
      ['zh'] = {
        name = '晶体元件',
        description = '重要的源石工业材料，可用于多种强化场合，可以制作与合成更高级的源石电子元件。',
        recipeDescription = '用源石晶体外壳制作的工业原材料。现代源石电子工业的基础产品。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_iam4',
    recipe = {{{
      prefab='ark_item_mtl_sl_boss3', count=1
    }, {
      prefab='ark_item_mtl_sl_pg1', count=1
    }, {
      prefab='ark_item_mtl_sl_iam3', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '炽合金块',
        description = '产量稀少的电子工业用特殊高熔点合金。可用于多种强化场合。',
        recipeDescription = '由炽合金进一步加工得到的合金材料。有着无可替代的作用。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_iam3',
    i18n = {
      ['zh'] = {
        name = '炽合金',
        description = '电子工业用特殊高熔点合金。可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '由数种稀有泰拉金属熔炼成的合金材料。是不可或缺的材料。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_pgel4',
    recipe = {{{
      prefab='ark_item_mtl_sl_iron3', count=1
    }, {
      prefab='ark_item_mtl_sl_pgel3', count=1
    }, {
      prefab='ark_item_mtl_sl_iam3', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '聚合凝胶',
        description = '一种具备极高强度的可塑性材料。可用于多种强化场合。',
        recipeDescription = '以凝胶为源材料，历经大量实验与反复测试诞生的人工材料。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_pgel3',
    i18n = {
      ['zh'] = {
        name = '凝胶',
        description = '一种高强度的可塑性材料。可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '于实验室中意外诞生的人工材料。广泛运用于高新项目。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_alcohol2',
    recipe = {{{
      prefab='ark_item_mtl_sl_alcohol1', count=1
    }, {
      prefab='ark_item_mtl_sl_strg3', count=1
    }, {
      prefab='ark_item_mtl_sl_rma7012', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '白马醇',
        description = '片状有机化合物。可用于多种强化场合，也常作为制作双极纳米片的原料之一。',
        recipeDescription = '扭转醇精加工后的产物，名字来自发现其产出方式的厂家。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_alcohol1',
    i18n = {
      ['zh'] = {
        name = '扭转醇',
        description = '片状有机化合物。可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '优秀的化工中介体，常在两种形状间转换以储存和放出传导物质。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_manganese2',
    recipe = {{{
      prefab='ark_item_mtl_sl_manganese1', count=2
    }, {
      prefab='ark_item_mtl_sl_rush3', count=1
    }, {
      prefab='ark_item_mtl_sl_alcohol1', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '三水锰矿',
        description = '用于提炼冶炼用的金属矿物。可用于多种强化场合，也常作为制作D32钢的原料之一。',
        recipeDescription = '少有厂家愿意用于生产工业催化剂的珍贵金属矿物。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_manganese1',
    i18n = {
      ['zh'] = {
        name = '轻锰矿',
        description = '用于提炼冶炼用的金属矿物。可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '用以产出极为泛用的工业催化剂的金属矿物。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_pg2',
    recipe = {{{
      prefab='ark_item_mtl_sl_pg1', count=1
    }, {
      prefab='ark_item_mtl_sl_iron3', count=1
    }, {
      prefab='ark_item_mtl_sl_boss3', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '五水研磨石',
        description = '用于精加工武器零件的高级研磨石。可用于多种强化场合，也常作为制作D32钢的原料之一。',
        recipeDescription = '相较普通研磨石，物质结构更加稳定的工具材料。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_pg1',
    i18n = {
      ['zh'] = {
        name = '研磨石',
        description = '用于加工武器零件的研磨石。可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '不起爆、不粉化、不开裂。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_rma7024',
    recipe = {{{
      prefab='ark_item_mtl_sl_rma7012', count=1
    }, {
      prefab='ark_item_mtl_sl_g3', count=2
    }, {
      prefab='ark_item_mtl_sl_ketone3', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = 'RMA70-24',
        description = '一种十分敏感且有优秀传导效果的矿物。可用于多种强化场合，也常作为制作D32钢的原料之一。',
        recipeDescription = '自然态呈复杂多面体的矿物。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_rma7012',
    i18n = {
      ['zh'] = {
        name = 'RMA70-12',
        description = '一种敏感且有良好传导效果的矿物。可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '在被发现其现代工业价值之前，就已经被发现了其在**施展中的价值。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_g4',
    recipe = {{{
      prefab='ark_item_mtl_sl_g3', count=4
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '提纯源岩',
        description = '从地表开采出的岩石固块组提纯出的物质，可用于多种强化场合，也常作为制作聚合剂的原料之一。',
        recipeDescription = '无论是谁，看着规则的切割面都会不禁发出感慨吧。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_g3',
    recipe = {{{
      prefab='ark_item_mtl_sl_g2', count=5
    }, {
      prefab='ark_gold', count=200
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=10
    }}},
    i18n = {
      ['zh'] = {
        name = '固源岩组',
        description = '从地表开采出的岩石固块组，可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '固源岩的压缩定型产物，可自然形成。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_g2',
    recipe = {{{
      prefab='ark_item_mtl_sl_g1', count=3
    }, {
      prefab='ark_gold', count=100
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=5
    }}},
    i18n = {
      ['zh'] = {
        name = '固源岩',
        description = '从地表开采出的岩石固块，可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '内含有密集的微孔，常作为源石气体分解物的吸附剂。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_g1',
    i18n = {
      ['zh'] = {
        name = '源岩',
        description = '从地表开采出的岩石，可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '富含有机物，常见于源石挥发殆尽后的地区。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_boss4',
    recipe = {{{
      prefab='ark_item_mtl_sl_boss3', count=1
    }, {
      prefab='ark_item_mtl_sl_g3', count=2
    }, {
      prefab='ark_item_mtl_sl_pg1', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '改量装置',
        description = '收缴来的高等机械装置，可用于多种强化场合，也常作为制作双极纳米片的原料之一。',
        recipeDescription = '从中能感受到制作者所投入的狂热与执着……',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_boss3',
    recipe = {{{
      prefab='ark_item_mtl_sl_boss2', count=4
    }, {
      prefab='ark_gold', count=200
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=10
    }}},
    i18n = {
      ['zh'] = {
        name = '全新装置',
        description = '收缴来的全新机械装置，可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '一套全新装配而成的装置。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_boss2',
    recipe = {{{
      prefab='ark_item_mtl_sl_boss1', count=3
    }, {
      prefab='ark_gold', count=100
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=5
    }}},
    i18n = {
      ['zh'] = {
        name = '装置',
        description = '收缴来的常规机械装置，可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '一套相对完整的装置，含有大量密集的可用电子元件。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_boss1',
    i18n = {
      ['zh'] = {
        name = '破损装置',
        description = '收缴来的破损机械装置，可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '经历了激烈的战斗后已经损坏，不过其内部元件依旧具备一定的使用价值。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_rush4',
    recipe = {{{
      prefab='ark_item_mtl_sl_rush3', count=2
    }, {
      prefab='ark_item_mtl_sl_ketone3', count=1
    }, {
      prefab='ark_item_mtl_sl_alcohol1', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '聚酸酯块',
        description = '工业制造所需的成块聚酸酯，可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '精炼提纯后的材料。也许会成为新一代材料的试金石也说不定哦。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_rush3',
    recipe = {{{
      prefab='ark_item_mtl_sl_rush2', count=4
    }, {
      prefab='ark_gold', count=200
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=10
    }}},
    i18n = {
      ['zh'] = {
        name = '聚酸酯组',
        description = '工业制造所需的一组聚酸酯，可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '进一步加工后的材料，可以用于加工一些特殊材料。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_rush2',
    recipe = {{{
      prefab='ark_item_mtl_sl_rush1', count=3
    }, {
      prefab='ark_gold', count=100
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=5
    }}},
    i18n = {
      ['zh'] = {
        name = '聚酸酯',
        description = '工业制造所需的零散聚酸酯，可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '用来制作所需要的部分基础物件。是一些缓释药物中的常用成分。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_rush1',
    i18n = {
      ['zh'] = {
        name = '酯原料',
        description = '工业制造所需的酯原料，可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '这只是原料，几乎派不上什么大用场。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_strg4',
    recipe = {{{
      prefab='ark_item_mtl_sl_strg3', count=2
    }, {
      prefab='ark_item_mtl_sl_iron3', count=1
    }, {
      prefab='ark_item_mtl_sl_manganese1', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '糖聚块',
        description = '机械化制作的大量糖块，可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '严禁在加工前偷吃！这不是食品，也不会作为食品售卖！不会！',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_strg3',
    recipe = {{{
      prefab='ark_item_mtl_sl_strg2', count=4
    }, {
      prefab='ark_gold', count=200
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=10
    }}},
    i18n = {
      ['zh'] = {
        name = '糖组',
        description = '机械化制作的中等量糖块，可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '广受欢迎的糖块组合包。在被加工成材料之前，份量总是有所减少。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_strg2',
    recipe = {{{
      prefab='ark_item_mtl_sl_strg1', count=3
    }, {
      prefab='ark_gold', count=100
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=5
    }}},
    i18n = {
      ['zh'] = {
        name = '糖',
        description = '机械化制作的少量糖块，可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '啊啊，这个味道……会带来不错的好心情。不是用来当零食吃的。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_strg1',
    i18n = {
      ['zh'] = {
        name = '代糖',
        description = '机械化制作的廉价天然糖替代产物，可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '有着微弱的甜味，也许可以吃。同时其溶液也常用于化工用途。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_iron4',
    recipe = {{{
      prefab='ark_item_mtl_sl_iron3', count=2
    }, {
      prefab='ark_item_mtl_sl_boss3', count=1
    }, {
      prefab='ark_item_mtl_sl_rush3', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '异铁块',
        description = '价值高昂的工业材料。可用于多种强化场合，也常作为制作聚合剂的原料之一。',
        recipeDescription = '在极为苛刻的条件下，由多套异铁组熔铸成型的异铁块。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_iron3',
    recipe = {{{
      prefab='ark_item_mtl_sl_iron2', count=4
    }, {
      prefab='ark_gold', count=200
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=10
    }}},
    i18n = {
      ['zh'] = {
        name = '异铁组',
        description = '珍贵的工业材料。可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '多块异铁在极少数非人为因素影响下，偶然产生的异铁组合。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_iron2',
    recipe = {{{
      prefab='ark_item_mtl_sl_iron1', count=3
    }, {
      prefab='ark_gold', count=100
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=5
    }}},
    i18n = {
      ['zh'] = {
        name = '异铁',
        description = '罕见的工业材料。可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '在少数惰化流程中，异铁碎片偶尔会产生相变，聚合为异铁。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_iron1',
    i18n = {
      ['zh'] = {
        name = '异铁碎片',
        description = '普普通通的工业材料。可用于多种强化场合，也常作为制造站合成项目的原料',
        recipeDescription = '大规模金属原料加工的副产物，常被用于材料金属熔炼与阶段性再处理。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_ketone4',
    recipe = {{{
      prefab='ark_item_mtl_sl_ketone3', count=2
    }, {
      prefab='ark_item_mtl_sl_strg3', count=1
    }, {
      prefab='ark_item_mtl_sl_manganese1', count=1
    }, {
      prefab='ark_gold', count=300
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=20
    }}},
    i18n = {
      ['zh'] = {
        name = '酮阵列',
        description = '大量的工业用有机化合物。可用于多种强化场合，也常作为制作聚合剂的原料之一。',
        recipeDescription = '由工程干员严格监控的大量不稳定实验性酮制剂。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_ketone3',
    recipe = {{{
      prefab='ark_item_mtl_sl_ketone2', count=4
    }, {
      prefab='ark_gold', count=200
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=10
    }}},
    i18n = {
      ['zh'] = {
        name = '酮凝集组',
        description = '中等量的工业用有机化合物。可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '工程干员理当精准操作，以免浪费材料。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_ketone2',
    recipe = {{{
      prefab='ark_item_mtl_sl_ketone1', count=3
    }, {
      prefab='ark_gold', count=100
    }, {
      prefab=CHARACTER_INGREDIENT.SANITY, count=5
    }}},
    i18n = {
      ['zh'] = {
        name = '酮凝集',
        description = '少量的工业用有机化合物。可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '经过特殊处理后产出的少量多态酮制剂。',
      }
    }
  }, {
    prefab = 'ark_item_mtl_sl_ketone1',
    i18n = {
      ['zh'] = {
        name = '双酮',
        description = '极少量的工业用有机化合物。可用于多种强化场合，也常作为制造站合成项目的原料。',
        recipeDescription = '通过再处理后用来粘结其它稳定结构。',
      }
    }
  },
}