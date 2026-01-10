# 🚨 FIX LỖI: Could not open resource metadata file

## ❌ LỖI BẠN GẶP

```
Couldn't load resource f17_cautomtich: 
Could not open resource metadata file - no such file
```

→ **Nguyên nhân:** Thiếu file `fxmanifest.lua` hoặc upload sai cấu trúc!

---

## ✅ GIẢI PHÁP - UPLOAD LẠI ĐÚNG CÁCH

### **Bước 1: Xóa resource cũ trên server**

Trong FileZilla (bên phải - server):
1. Vào thư mục `resources/`
2. Tìm thư mục `f17_cautomtich`
3. Click phải → **Delete** (xóa hoàn toàn)

---

### **Bước 2: Chuẩn bị thư mục build trên máy tính**

Mở thư mục: `d:\nghework\f17_cautomtich\build\`

Kiểm tra xem có đủ các file/thư mục sau không:

```
build/
├── ✅ fxmanifest.lua    ← PHẢI CÓ FILE NÀY!
├── ✅ html/
│   ├── index.html
│   ├── script.js
│   ├── style.css
│   ├── images/
│   └── sounds/
├── ✅ server/
│   └── main.lua
├── ✅ client/
│   └── main.lua
└── README.md
```

**Nếu THIẾU `fxmanifest.lua`** → Chạy lại build:
```bash
npm run build
```

---

### **Bước 3: Upload ĐÚNG CÁCH**

#### **⚠️ QUAN TRỌNG: Có 2 cách upload**

---

#### **CÁCH 1: Upload từng file/thư mục BÊN TRONG build/ (KHUYẾN NGHỊ)**

**Bước 3.1:** Trên server (FileZilla bên phải), tạo thư mục mới:
1. Vào `resources/`
2. Click phải → **Create directory**
3. Đặt tên: `f17_cautomtich`

**Bước 3.2:** Vào trong thư mục `f17_cautomtich/` vừa tạo

**Bước 3.3:** Trên máy tính (FileZilla bên trái), vào thư mục `build/`

**Bước 3.4:** Chọn **TẤT CẢ** file/thư mục BÊN TRONG `build/`:
- ✅ `fxmanifest.lua` (file)
- ✅ `html/` (thư mục)
- ✅ `server/` (thư mục)
- ✅ `client/` (thư mục)
- ⚠️ KHÔNG chọn `README.md`

**Bước 3.5:** Kéo thả vào thư mục `f17_cautomtich/` trên server

**Kết quả:**
```
Server:
resources/
└── f17_cautomtich/
    ├── fxmanifest.lua  ← ✅ CÓ
    ├── html/           ← ✅ CÓ
    ├── server/         ← ✅ CÓ
    └── client/         ← ✅ CÓ
```

---

#### **CÁCH 2: Upload cả thư mục build/ rồi đổi tên**

**Bước 3.1:** Trên máy tính (FileZilla bên trái), vào thư mục `d:\nghework\f17_cautomtich\`

**Bước 3.2:** Kéo thả **TOÀN BỘ thư mục `build/`** sang server (vào `resources/`)

**Bước 3.3:** Trên server, click phải vào thư mục `build/` → **Rename** → Đổi tên thành `f17_cautomtich`

**Kết quả:**
```
Server:
resources/
└── f17_cautomtich/  ← Đã đổi tên từ build/
    ├── fxmanifest.lua
    ├── html/
    ├── server/
    └── client/
```

---

### **Bước 4: Kiểm tra lại trên server**

Trong FileZilla (bên phải), mở thư mục `resources/f17_cautomtich/` và kiểm tra:

**PHẢI CÓ:**
```
f17_cautomtich/
├── ✅ fxmanifest.lua    ← FILE NÀY PHẢI CÓ!
├── ✅ html/
│   ├── index.html
│   ├── script.js
│   ├── style.css
│   ├── images/
│   └── sounds/
├── ✅ server/
│   └── main.lua
└── ✅ client/
    └── main.lua
```

**KHÔNG ĐƯỢC:**
```
❌ SAI - Cấu trúc lồng nhau:
f17_cautomtich/
└── build/              ← KHÔNG ĐƯỢC CÓ THƯ MỤC NÀY!
    ├── fxmanifest.lua
    └── ...

❌ SAI - Thiếu fxmanifest.lua:
f17_cautomtich/
├── html/
├── server/
└── client/
❌ THIẾU fxmanifest.lua
```

---

### **Bước 5: Khởi động resource**

Trong server console:
```
ensure f17_cautomtich
```

Hoặc:
```
restart f17_cautomtich
```

---

## 🔍 KIỂM TRA FILE FXMANIFEST.LUA

Nếu vẫn lỗi, kiểm tra nội dung file `fxmanifest.lua` trên server:

**Nội dung ĐÚNG:**
```lua
fx_version 'cerulean'
game 'gta5'

author 'FiveM Developer'
description 'Mini Game Câu Tôm Tích'
version '1.0.0'

-- Server scripts
server_scripts {
    'server/main.lua'
}

-- Client scripts
client_scripts {
    'client/main.lua'
}

-- UI files
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png',
    'html/images/*.jpg',
    'html/sounds/*.mp3',
    'html/sounds/*.ogg'
}
```

---

## 🛠️ TROUBLESHOOTING

### **Vẫn báo lỗi "no such file"?**

#### **Kiểm tra 1: Tên file có đúng không?**
- ✅ ĐÚNG: `fxmanifest.lua` (chữ thường)
- ❌ SAI: `FxManifest.lua`, `fxManifest.lua`, `FXMANIFEST.LUA`

#### **Kiểm tra 2: File có bị lỗi không?**
Mở file `fxmanifest.lua` trên server, xem có lỗi cú pháp không.

#### **Kiểm tra 3: Đường dẫn có đúng không?**
```
✅ ĐÚNG:
resources/f17_cautomtich/fxmanifest.lua

❌ SAI:
resources/f17_cautomtich/build/fxmanifest.lua  ← Lồng nhau!
resources/build/fxmanifest.lua                 ← Tên sai!
```

---

## 📋 CHECKLIST CUỐI CÙNG

Trước khi chạy `ensure f17_cautomtich`, kiểm tra:

- [ ] ✅ Đã xóa resource cũ
- [ ] ✅ Đã chạy `npm run build` trên máy tính
- [ ] ✅ Thư mục `build/` có file `fxmanifest.lua`
- [ ] ✅ Đã upload đúng cách (không lồng nhau)
- [ ] ✅ Trên server có đường dẫn: `resources/f17_cautomtich/fxmanifest.lua`
- [ ] ✅ Trên server có đường dẫn: `resources/f17_cautomtich/html/index.html`
- [ ] ✅ Trên server có đường dẫn: `resources/f17_cautomtich/server/main.lua`
- [ ] ✅ Trên server có đường dẫn: `resources/f17_cautomtich/client/main.lua`

---

## 🎯 TÓM TẮT NHANH

```bash
# 1. Xóa resource cũ trên server (FileZilla)

# 2. Build lại (trên máy tính)
npm run build

# 3. Upload ĐÚNG:
# - Vào resources/ trên server
# - Tạo thư mục f17_cautomtich
# - Vào trong thư mục đó
# - Upload TẤT CẢ nội dung BÊN TRONG build/
#   (fxmanifest.lua, html/, server/, client/)

# 4. Kiểm tra file tồn tại:
# resources/f17_cautomtich/fxmanifest.lua ← PHẢI CÓ!

# 5. Khởi động
ensure f17_cautomtich
```

---

## ✅ KẾT QUẢ MONG ĐỢI

Sau khi làm đúng:
```
Server console:
✅ Started resource f17_cautomtich
```

Không còn lỗi `Could not open resource metadata file`!

---

## 📞 NẾU VẪN LỖI

1. Chụp ảnh cấu trúc thư mục trên server (FileZilla)
2. Kiểm tra xem file `fxmanifest.lua` có trong thư mục `build/` trên máy tính không
3. Thử xóa thư mục `build/` và chạy lại `npm run build`
