QBCore = exports["qb-core"]:GetCoreObject()
ok = exports['o-protection']
no = exports['f17notify']
ox = exports.ox_inventory

Config = {}

-- ============================================
-- CẤU HÌNH ITEMS
-- ============================================
Config.Items = {
    TRASH = "racthainhua",
    COMMON = "tomtich",
    UNCOMMON = "tomtichxanh",
    RARE = "tomtichdo",
    LEGENDARY = "tomtichhoangkim",
    TREASURE = "khobau"
}

-- ============================================
-- CẤU HÌNH ĐIỂM CÂU TÔM TÍCH
-- ============================================
Config.TomTichPoints = {
    vector3(-1903.75, -827.08, 0.56),
    vector3(-1854.1, -881.53, 1.38),
    vector3(-1861.53, -868.48, 1.67),
    vector3(-1869.86, -861.71, 1.31),
    vector3(-1877.67, -854.82, 1.02),
    vector3(-1887.46, -841.93, 1.1),
    vector3(-1899.26, -831.63, 0.67),
    vector3(-1906.17, -819.22, 1.11),
    vector3(-1915.38, -808.02, 1.1),
    vector3(-1925.53, -792.46, 1.16),
    vector3(-1941.22, -779.2, 0.49),
    vector3(-1944.33, -768.25, 1.14),
    vector3(-1956.03, -758.74, 0.77)
}

-- ============================================
-- CẤU HÌNH THỜI GIAN & KHOẢNG CÁCH
-- ============================================
Config.SpawnCooldown = 5 -- Thời gian cooldown mỗi điểm câu (giây)
Config.InteractionDistance = 2.0 -- Khoảng cách để tương tác
Config.MarkerDrawDistance = 50.0 -- Khoảng cách hiển thị marker

-- ============================================
-- CẤU HÌNH MARKER
-- ============================================
Config.Marker = {
    Available = {
        type = 1,
        size = {x = 1.5, y = 1.5, z = 1.0},
        color = {r = 0, g = 255, b = 150, a = 150},
        text = "[~g~E~w~] Câu Tôm Tích"
    },
    Cooldown = {
        type = 1,
        size = {x = 1.5, y = 1.5, z = 1.0},
        color = {r = 255, g = 0, b = 0, a = 150}
    }
}

-- ============================================
-- CẤU HÌNH LEVEL & TỶ LỆ RƠI
-- ============================================
Config.LevelConfig = {
    [1] = {
        expRequired = 0,
        rates = {
            [Config.Items.COMMON] = 60,
            [Config.Items.UNCOMMON] = 35,
            [Config.Items.RARE] = 5,
            [Config.Items.LEGENDARY] = 0,
            treasure = 0
        }
    },
    [2] = {
        expRequired = 50,
        rates = {
            [Config.Items.COMMON] = 45,
            [Config.Items.UNCOMMON] = 40,
            [Config.Items.RARE] = 10,
            [Config.Items.LEGENDARY] = 5,
            treasure = 0
        }
    },
    [3] = {
        expRequired = 100,
        rates = {
            [Config.Items.COMMON] = 40,
            [Config.Items.UNCOMMON] = 30,
            [Config.Items.RARE] = 15,
            [Config.Items.LEGENDARY] = 10,
            treasure = 5
        }
    }
}

-- ============================================
-- CẤU HÌNH EXP NHẬN ĐƯỢC
-- ============================================
Config.ExpRewards = {
    [Config.Items.COMMON] = 50,
    [Config.Items.UNCOMMON] = 50,
    [Config.Items.RARE] = 50,
    [Config.Items.LEGENDARY] = 50,
    [Config.Items.TREASURE] = 100
}

-- ============================================
-- CẤU HÌNH CHỐNG SPAM & CHEAT
-- ============================================
Config.AntiSpam = {
    cooldown = 10, -- Thời gian chờ giữa các lần chơi (giây)
    minGameDuration = 15 -- Thời gian tối thiểu để hoàn thành game (giây)
}

-- ============================================
-- CẤU HÌNH KHO BÁU
-- ============================================
Config.Treasure = {
    gridSize = 5, -- Kích thước lưới (5x5)
    treasureCount = 2, -- Số lượng kho báu cần tìm
    initialAttempts = 4, -- Số lượt đào ban đầu
    minDistance = 3, -- Khoảng cách tối thiểu giữa 2 kho báu
    treasureChance = 90, -- Tỷ lệ xuất hiện kho báu ở level 3 (%)
    minLevelRequired = 3, -- Level tối thiểu để có kho báu
    rewardAmount = 2 -- Số lượng kho báu nhận được khi thắng
}

-- ============================================
-- CẤU HÌNH ANIMATION
-- ============================================
Config.Animation = {
    dict = "amb@world_human_stand_fishing@idle_a",
    name = "idle_c"
}