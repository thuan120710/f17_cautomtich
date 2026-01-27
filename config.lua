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

-- Thông tin hiển thị trên NUI
Config.NUIItems = {
    [Config.Items.COMMON] = { name = 'Tôm Tích', image = 'images/tomtich.png' },
    [Config.Items.UNCOMMON] = { name = 'Tôm Tích Xanh', image = 'images/tomtich_xanh.png' },
    [Config.Items.RARE] = { name = 'Tôm Tích Đỏ', image = 'images/tomtich_do.png' },
    [Config.Items.LEGENDARY] = { name = 'Tôm Tích Hoàng Kim', image = 'images/tomtich_vang.png' },
    [Config.Items.TRASH] = { name = 'Rác thải nhựa', image = 'images/trash.png' } -- Cần có ảnh rác nếu muốn hiện
}

-- Giao diện & Độ khó (NUI)
Config.NUI = {
    -- ÂM THANH
    Sounds = {
        win = { url = 'https://assets.mixkit.co/active_storage/sfx/2000/2000-preview.mp3', volume = 0.5 },
        lose = { url = 'https://assets.mixkit.co/active_storage/sfx/2955/2955-preview.mp3', volume = 0.4 },
        ocean = { url = 'https://assets.mixkit.co/active_storage/sfx/2393/2393-preview.mp3', volume = 0.2 },
        reelIn = { url = 'https://assets.mixkit.co/active_storage/sfx/2571/2571-preview.mp3', volume = 0.3 },
        shrimpPull = { url = 'https://assets.mixkit.co/active_storage/sfx/2573/2573-preview.mp3', volume = 0.6 },
        tension = { url = 'https://assets.mixkit.co/active_storage/sfx/2577/2577-preview.mp3', volume = 0.4 }
    },
    
    -- PHASE 1: DI CHUYỂN TRONG HANG (TUNNEL)
    Tunnel = {
        totalDepth = 5000,       -- Độ sâu tổng cộng
        pathWidth = 130,         -- Chiều rộng đường đi
        warningDistance = 20,    -- Khoảng cách cảnh báo đụng tường
        maxSpeed = 3.0,          -- Tốc độ rơi tối đa
        acceleration = 0.1,      -- Gia tốc
        friction = 0.2,          -- Ma sát (khi không nhấn)
        retractSpeed = 8,        -- Tốc độ thu dây khi đụng tường
        lerpSpeed = 0.25,        -- Độ mượt khi móc câu theo chuột
        swayAmount = 80          -- Độ ngoằn ngoèo của hang
    },
    
    -- PHASE 2: THẢ DÂY (DROPPING)
    Dropping = {
        dropSpeed = 40,          -- Tốc độ thả dây
        retractSpeed = 60        -- Tốc độ thu dây (khi buông Space)
    },
    
    -- PHASE 3: ĐỢI TÔM CẮN (WAITING & BITING)
    Biting = {
        waitMin = 5000,          -- Thời gian đợi tối thiểu (ms)
        waitRandom = 3000,       -- Thời gian đợi ngẫu nhiên (ms)
        biteWindow = 2000        -- Thời gian tôm cắn để giật (ms)
    },
    
    -- PHASE 4: KÉO TÔM (FISHING)
    Fishing = {
        tensionSafeMin = 30,      -- Lực căng an toàn tối thiểu
        tensionSafeMax = 70,      -- Lực căng an toàn tối đa
        gameTimeLimit = 30000,    -- Thời gian tối đa (ms)
        catchDuration = 20000,    -- Thời gian cần giữ để câu được (ms)
        pullIntervalMin = 2000,   -- Khoảng thời gian tôm giật tối thiểu (ms)
        pullIntervalMax = 4000,   -- Khoảng thời gian tôm giật tối đa (ms)
        
        -- Vật lý lực căng
        tensionIncreaseHolding = 35,    -- Lực căng tăng khi giữ Space
        tensionDecreaseReleased = 25,   -- Lực căng giảm khi buông Space
        resistanceBase = 15,            -- Lực kháng cơ bản của tôm
        progressDecreaseRate = 50,      -- Tốc độ giảm tiến trình khi ngoài vùng an toàn
        
        -- Ngưỡng thất bại
        failTensionMax = 95,
        failTensionMin = 5,
        warningThresholdHigh = 85,
        warningThresholdLow = 15,
        
        -- Độ khó theo độ hiếm
        rarityMultipliers = {
            tomtichhoangkim = 1.3,
            tomtichdo = 1.1
        }
    }
}

-- ============================================
-- CẤU HÌNH VÙNG CÂU TÔM TÍCH (HÌNH CHỮ NHẬT)
-- ============================================
Config.TomTichZone = {
    coords = vector3(-282.18, 6547.14, 2.59), -- Tọa độ trung tâm vùng
    size = vector3(30.0, 25.0, 15), -- Kích thước (dài x rộng x cao/sâu)
    rotation = 0 -- Góc xoay (0-360)
    -- Lưu ý: 
    -- - size.x = chiều dài (length)
    -- - size.y = chiều rộng (width)
    -- - size.z = chiều cao/sâu (height) - tăng lên nếu địa hình có độ cao thấp khác nhau
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
            [Config.Items.COMMON] = 60,      -- Tôm thường: 60%
            [Config.Items.UNCOMMON] = 40,    -- Tôm xanh: 40%
            [Config.Items.RARE] = 0,
            [Config.Items.LEGENDARY] = 0
        }
    },
    [2] = {
        expRequired = 50,
        rates = {
            [Config.Items.COMMON] = 20,      -- Tôm thường: 20%
            [Config.Items.UNCOMMON] = 40,    -- Tôm xanh: 40%
            [Config.Items.RARE] = 40,        -- Tôm đỏ: 40%
            [Config.Items.LEGENDARY] = 0
        }
    },
    [3] = {
        expRequired = 100,
        rates = {
            [Config.Items.COMMON] = 25,      -- Tôm thường: 25%
            [Config.Items.UNCOMMON] = 35,    -- Tôm xanh: 35%
            [Config.Items.RARE] = 30,        -- Tôm đỏ: 30%
            [Config.Items.LEGENDARY] = 10    -- Tôm vàng: 10%
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
    treasureChance = 100, -- Tỷ lệ xuất hiện kho báu (10%)
    minLevelRequired = 3, -- Level tối thiểu để có kho báu
    rewardAmount = 1, -- Số lượng kho báu nhận được khi thắng
    maxPerHour = 2, -- Giới hạn tối đa 2 rương/giờ
    hourWindow = 3600 -- 1 giờ = 3600 giây
}

-- ============================================
-- CẤU HÌNH ANIMATION
-- ============================================
Config.Animation = {
    dict = "amb@world_human_stand_fishing@idle_a",
    name = "idle_c"
}

Config.DiggingAnimation = {
    dict = "amb@world_human_gardener_plant@male@base",
    name = "base"
}