# OmniVoice-compatible local TTS server

Đây là một server TTS cục bộ tương thích với HTTP contract mà pipeline mong
đợi. Nó **không phải OmniVoice gốc**. Server dùng FastAPI và `edge-tts`, không
yêu cầu API key; máy vẫn cần kết nối Internet để `edge-tts` truy cập dịch vụ
giọng nói của Microsoft.

Server cung cấp:

- `GET /` trả về `{"ok": true}`.
- `POST /tts` nhận JSON `{"text":"..."}` và trả về bytes MP3 với content type
  `audio/mpeg`.

Giọng mặc định là `vi-VN-HoaiMyNeural`. Để chọn giọng khác trong PowerShell,
đặt biến môi trường trước khi khởi động:

```powershell
$env:OMNI_TTS_VOICE = "vi-VN-NamMinhNeural"
```

## Chạy server trên Windows

Từ thư mục gốc repository:

```powershell
cd tools\omnivoice-server
.\run-windows.bat
```

Script tạo môi trường Python riêng tại `.venv` nếu chưa có, kích hoạt môi
trường, cài dependency từ `requirements.txt`, rồi chạy server tại
`http://127.0.0.1:8123`.

## Kiểm tra TTS

Mở terminal khác, vẫn trong `tools\omnivoice-server`, rồi chạy:

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:8123/tts" -Method Post -ContentType "application/json; charset=utf-8" -Headers @{ Accept = "audio/mpeg" } -Body '{"text":"Xin chào, đây là câu kiểm tra."}' -OutFile "tts-test.mp3"
ffprobe tts-test.mp3
```

`tts-test.mp3` chỉ là file kiểm tra cục bộ và đã được Git bỏ qua.

## Chạy pipeline

Giữ server đang chạy, mở terminal khác và chạy:

```powershell
cd D:\GitHub\omni-generate-video
npm run pipeline -- output/demo-video/script.json
```

Pipeline mặc định kết nối tới `http://127.0.0.1:8123`. Nếu cấu hình thủ công,
hãy đặt `OMNIVOICE_ENDPOINT=http://127.0.0.1:8123` trong `.env.local` ở thư mục
gốc repository.
