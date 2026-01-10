# 🔒 HƯỚNG DẪN SỬ DỤNG - F17 Câu Tôm Tích

## 📁 CẤU TRÚC THỦ MỤC

```
f17_cautomtich/
├── 📂 html/              ← SOURCE GỐC (Để phát triển)
│   ├── script.js         ← Code Vue.js gốc
│   ├── style.css         ← CSS gốc
│   └── index.html
├── 📂 server/            ← Server Lua gốc
├── 📂 client/            ← Client Lua gốc
├── 📂 build/             ← PHIÊN BẢN BẢO MẬT (Upload lên server)
│   ├── html/
│   │   ├── script.js     ← ✅ ĐÃ OBFUSCATE
│   │   ├── style.css     ← ✅ ĐÃ MINIFY
│   │   └── index.html
│   ├── server/
│   ├── client/
│   └── fxmanifest.lua
├── build.js              ← Script build tự động
└── package.json
```

---

## 🚀 CÁCH SỬ DỤNG

### **1️⃣ KHI PHÁT TRIỂN (Sửa code)**

✏️ **Sửa code trong thư mục GỐC:**
- `html/script.js` - Code Vue.js
- `html/style.css` - CSS
- `server/main.lua` - Server logic
- `client/main.lua` - Client logic

⚠️ **KHÔNG SỬA** trong thư mục `build/`!

---

### **2️⃣ KHI UPLOAD LÊN SERVER**

#### **Bước 1: Build code**
```bash
npm run build
```

✅ Lệnh này sẽ:
- Obfuscate `script.js` (làm rối code)
- Minify `style.css` (nén CSS)
- Copy tất cả file cần thiết vào `build/`

#### **Bước 2: Upload lên FileZilla**
1. Mở FileZilla
2. Kết nối tới server FiveM
3. Vào thư mục `resources/`
4. **Upload toàn bộ thư mục `build/`**
5. Đổi tên thư mục `build` thành `f17_cautomtich`

```
Server FiveM:
resources/
└── f17_cautomtich/  ← Thư mục build đã đổi tên
    ├── html/
    ├── server/
    ├── client/
    └── fxmanifest.lua
```

#### **Bước 3: Khởi động resource**
```
ensure f17_cautomtich
```

---

## 🔒 BẢO MẬT ĐÃ ĐƯỢC THÊM

### ✅ **JavaScript Obfuscation**
Code `script.js` đã được làm rối:
```javascript
// Trước (Dễ đọc)
const tensionLevel = ref(50);
const catchProgress = ref(0);

// Sau (Khó đọc)
const _0x4a2b=_0x1c3d;(function(_0x5e4f,_0x6a7b){...})();
```

### ✅ **Server-side Validation**
Server **KHÔNG TIN** client:
- ❌ Client gửi tôm gì → Server KHÔNG DÙNG
- ✅ Server tự random tôm theo level
- ✅ Kiểm tra thời gian chơi (tối thiểu 15 giây)
- ✅ Rate limiting (10 giây/lần chơi)

### ✅ **Anti-Cheat**
```lua
-- Chống spam
if playerCooldowns[src] and os.time() - playerCooldowns[src] < 10 then
    return -- Chặn
end

-- Chống cheat thời gian
if gameDuration < 15 then
    print("⚠️ [ANTI-CHEAT] Player hoàn thành quá nhanh")
    return -- Chặn
end

-- Server tự random
rewardItem = GetRandomShrimpByLevel(game.level)
```

---

## 📊 SO SÁNH TRƯỚC/SAU

| Tính năng | Trước | Sau |
|-----------|-------|-----|
| **Code JavaScript** | Xem được rõ ràng | ✅ Obfuscated (khó đọc) |
| **Server trust client** | ❌ Tin 100% | ✅ Không tin, tự random |
| **Anti-spam** | ❌ Không có | ✅ 10 giây/lần |
| **Time validation** | ❌ Không có | ✅ Tối thiểu 15 giây |
| **CSS** | Dễ đọc | ✅ Minified |

---

## 🔄 QUY TRÌNH LÀM VIỆC

```
1. Sửa code trong thư mục GỐC
   ↓
2. Chạy: npm run build
   ↓
3. Upload thư mục build/ lên FileZilla
   ↓
4. Đổi tên thành f17_cautomtich
   ↓
5. Restart resource
```

---

## ⚠️ LƯU Ý QUAN TRỌNG

### ✅ **NÊN:**
- Sửa code trong thư mục GỐC
- Chạy `npm run build` trước khi upload
- Giữ source gốc an toàn
- Backup thường xuyên

### ❌ **KHÔNG NÊN:**
- Sửa code trong thư mục `build/`
- Upload thư mục gốc lên server
- Xóa thư mục gốc
- Share file `script.js` gốc

---

## 🛠️ TROUBLESHOOTING

### **Lỗi: "Cannot find module 'javascript-obfuscator'"**
```bash
npm install
```

### **Muốn build lại:**
```bash
npm run build
```

### **Xóa build cũ:**
```bash
# Windows
rmdir /s /q build

# Sau đó build lại
npm run build
```

---

## 📞 HỖ TRỢ

Nếu có vấn đề:
1. Kiểm tra console log trong server
2. Xem file `server/main.lua` có lỗi không
3. Đảm bảo đã chạy `npm run build` trước khi upload

---

## 🎉 HOÀN TẤT!

Bây giờ bạn có:
- ✅ Source gốc để phát triển
- ✅ Phiên bản bảo mật để upload
- ✅ Server validation chống hack
- ✅ Quy trình build tự động

**Chỉ cần chạy `npm run build` và upload thư mục `build/` lên FileZilla!** 🚀
