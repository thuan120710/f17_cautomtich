# 🚀 HƯỚNG DẪN UPLOAD LÊN FILEZILLA - CHI TIẾT

## ⚠️ LỖI BẠN GẶP PHẢI

Bạn đã **XÓA thư mục `html/`** trên server → Game không chạy vì thiếu UI!

---

## ✅ CÁCH UPLOAD ĐÚNG

### **📁 CẤU TRÚC PHẢI CÓ TRÊN SERVER**

```
Server FiveM:
resources/
└── f17_cautomtich/           ← Tên resource
    ├── 📂 html/              ← ✅ PHẢI CÓ THỦ MỤC NÀY!
    │   ├── index.html
    │   ├── script.js         ← Code đã obfuscate
    │   ├── style.css         ← CSS đã minify
    │   ├── 📂 images/
    │   │   ├── tomtich.png
    │   │   ├── tomtich_xanh.png
    │   │   ├── tomtich_do.png
    │   │   └── tomtich_vang.png
    │   └── 📂 sounds/
    ├── 📂 server/
    │   └── main.lua
    ├── 📂 client/
    │   └── main.lua
    └── fxmanifest.lua
```

---

## 🎯 HƯỚNG DẪN TỪNG BƯỚC

### **Bước 1: Chuẩn bị**

1. Mở thư mục `d:\nghework\f17_cautomtich\build\`
2. Bạn sẽ thấy:
   ```
   build/
   ├── html/           ← Thư mục này
   ├── server/         ← Thư mục này
   ├── client/         ← Thư mục này
   ├── fxmanifest.lua  ← File này
   └── README.md
   ```

---

### **Bước 2: Mở FileZilla**

1. Kết nối tới server FiveM
2. Điều hướng đến thư mục `resources/`

---

### **Bước 3: XÓA resource cũ (nếu có)**

**Trên server (bên phải FileZilla):**
```
resources/
└── f17_cautomtich/  ← Click phải → Delete
```

⚠️ Xóa **TOÀN BỘ** thư mục cũ!

---

### **Bước 4: Upload TOÀN BỘ thư mục build/**

#### **Cách 1: Kéo thả (Đơn giản nhất)**

1. **Bên trái FileZilla:** Mở thư mục `d:\nghework\f17_cautomtich\`
2. **Kéo thả thư mục `build/`** sang bên phải (server)
3. Đợi upload hoàn tất (4 MB)

#### **Cách 2: Upload thủ công**

1. Click phải vào thư mục `build/`
2. Chọn "Upload"
3. Đợi upload hoàn tất

---

### **Bước 5: Đổi tên thư mục**

**Trên server (bên phải FileZilla):**
```
resources/
└── build/  ← Click phải → Rename → Đổi thành "f17_cautomtich"
```

**Kết quả:**
```
resources/
└── f17_cautomtich/  ← Tên mới
    ├── html/        ← ✅ Có đầy đủ
    ├── server/      ← ✅ Có đầy đủ
    ├── client/      ← ✅ Có đầy đủ
    └── fxmanifest.lua
```

---

### **Bước 6: Kiểm tra lại**

**Trên server, mở thư mục `f17_cautomtich/` và kiểm tra:**

- [ ] ✅ Có thư mục `html/`
- [ ] ✅ Có thư mục `server/`
- [ ] ✅ Có thư mục `client/`
- [ ] ✅ Có file `fxmanifest.lua`
- [ ] ✅ Trong `html/` có: `index.html`, `script.js`, `style.css`
- [ ] ✅ Trong `html/images/` có các file ảnh tôm

---

### **Bước 7: Khởi động resource**

**Trong server console:**
```
ensure f17_cautomtich
```

Hoặc nếu đã chạy:
```
restart f17_cautomtich
```

---

## ❌ NHỮNG SAI LẦM THƯỜNG GẶP

### **1. Chỉ upload các file riêng lẻ**
```
❌ SAI:
resources/
└── f17_cautomtich/
    ├── index.html      ← Sai! Phải trong html/
    ├── script.js       ← Sai! Phải trong html/
    ├── main.lua        ← Sai! Phải trong server/
    └── fxmanifest.lua
```

### **2. Xóa thư mục html/**
```
❌ SAI:
resources/
└── f17_cautomtich/
    ├── server/
    ├── client/
    └── fxmanifest.lua
    ❌ THIẾU html/
```

### **3. Upload sai thư mục**
```
❌ SAI: Upload thư mục GỐC thay vì build/
resources/
└── f17_cautomtich/
    ├── html/
    │   └── script.js   ← Code CHƯA obfuscate (dễ đọc)
    └── ...
```

---

## ✅ CÁCH ĐÚNG - CHECKLIST

### **Trước khi upload:**
- [ ] Đã chạy `npm run build` trên máy tính
- [ ] Thư mục `build/` đã được tạo
- [ ] Kiểm tra `build/html/script.js` có bị obfuscate không (mở xem có khó đọc không)

### **Khi upload:**
- [ ] Xóa resource cũ trên server
- [ ] Upload **TOÀN BỘ** thư mục `build/`
- [ ] Đổi tên `build/` thành `f17_cautomtich`
- [ ] Kiểm tra có đủ 4 thành phần: `html/`, `server/`, `client/`, `fxmanifest.lua`

### **Sau khi upload:**
- [ ] Chạy `ensure f17_cautomtich` hoặc `restart f17_cautomtich`
- [ ] Kiểm tra console có lỗi không
- [ ] Test game trong game

---

## 🔍 KIỂM TRA SAU KHI UPLOAD

### **1. Kiểm tra file tồn tại**

**Trên server, kiểm tra các file sau:**
```
f17_cautomtich/html/index.html       ← Phải có
f17_cautomtich/html/script.js        ← Phải có (obfuscated)
f17_cautomtich/html/style.css        ← Phải có
f17_cautomtich/html/images/tomtich.png ← Phải có
f17_cautomtich/server/main.lua       ← Phải có
f17_cautomtich/client/main.lua       ← Phải có
f17_cautomtich/fxmanifest.lua        ← Phải có
```

### **2. Kiểm tra script.js đã obfuscate**

Mở file `html/script.js` trên server, bạn sẽ thấy:
```javascript
// ✅ ĐÚNG - Code đã obfuscate (khó đọc)
;109H0x2c21e6._0xa9d553,-_0x2c21e6._0x1d5028)](_0x5386be...

// ❌ SAI - Code gốc (dễ đọc)
const { createApp, ref, onMounted } = Vue;
```

Nếu thấy code dễ đọc → Bạn đã upload sai thư mục!

---

## 🛠️ TROUBLESHOOTING

### **Lỗi: "Resource f17_cautomtich not found"**
→ Kiểm tra tên thư mục có đúng là `f17_cautomtich` không

### **Lỗi: "UI không hiển thị"**
→ Kiểm tra thư mục `html/` có tồn tại không

### **Lỗi: "Missing file: html/index.html"**
→ Bạn đã xóa thư mục `html/` hoặc upload thiếu

### **Lỗi: "Script error in script.js"**
→ Kiểm tra file `script.js` có bị lỗi khi obfuscate không
→ Thử build lại: `npm run build`

---

## 📊 SO SÁNH ĐÚNG/SAI

| Thành phần | ❌ SAI | ✅ ĐÚNG |
|------------|--------|---------|
| **Thư mục upload** | Thư mục gốc | Thư mục `build/` |
| **Cấu trúc** | Thiếu `html/` | Đầy đủ `html/`, `server/`, `client/` |
| **script.js** | Code gốc (dễ đọc) | Code obfuscated (khó đọc) |
| **Tên thư mục** | `build/` | `f17_cautomtich/` |

---

## 🎯 TÓM TẮT NHANH

```bash
# 1. Build
npm run build

# 2. Upload TOÀN BỘ thư mục build/ lên server

# 3. Đổi tên build/ → f17_cautomtich/

# 4. Khởi động
ensure f17_cautomtich
```

---

## ✅ KẾT QUẢ MONG ĐỢI

Sau khi làm đúng, bạn sẽ có:

```
Server:
resources/
└── f17_cautomtich/
    ├── 📂 html/              ← ✅ CÓ
    │   ├── index.html        ← ✅ CÓ
    │   ├── script.js         ← ✅ CÓ (obfuscated)
    │   ├── style.css         ← ✅ CÓ (minified)
    │   ├── 📂 images/        ← ✅ CÓ
    │   └── 📂 sounds/        ← ✅ CÓ
    ├── 📂 server/            ← ✅ CÓ
    ├── 📂 client/            ← ✅ CÓ
    └── fxmanifest.lua        ← ✅ CÓ
```

**Game sẽ chạy bình thường!** 🎉

---

## 📞 NẾU VẪN LỖI

1. Xóa toàn bộ resource trên server
2. Build lại: `npm run build`
3. Upload lại **TOÀN BỘ** thư mục `build/`
4. Đổi tên thành `f17_cautomtich`
5. Restart server FiveM

---

**Nhớ: KHÔNG XÓA thư mục `html/` trên server!** 🚫
