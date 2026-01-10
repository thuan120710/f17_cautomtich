# CHANGELOG

## [Version 2.0.0] - Hệ Thống Level

### Thêm mới
- **Hệ thống Level (3 cấp độ)**
  - Level 1: Tôm thường 60%, Tôm xanh 35%, Tôm đỏ 5%, Tôm vàng 0%
  - Level 2: Tôm thường 45%, Tôm xanh 40%, Tôm đỏ 10%, Tôm vàng 5%
  - Level 3: Tôm thường 40%, Tôm xanh 30%, Tôm đỏ 15%, Tôm vàng 15%
- Hiển thị level của người chơi trên UI
- Tỷ lệ rơi vật phẩm thay đổi theo level
- Hệ thống kinh nghiệm (EXP) để lên level

### Cải tiến
- Tối ưu hóa logic random vật phẩm theo level
- Cập nhật giao diện hiển thị level badge
- Đồng bộ level giữa client và server

### Ghi chú
- Level mặc định: 1
- Có thể tùy chỉnh hàm `GetPlayerLevel()` trong server/main.lua để lấy level từ database hoặc metadata của framework
- Exp cần thiết: Level 2 = 100 exp, Level 3 = 300 exp
- Exp nhận được: Tôm thường = 5, Tôm xanh = 10, Tôm đỏ = 20, Tôm vàng = 50
