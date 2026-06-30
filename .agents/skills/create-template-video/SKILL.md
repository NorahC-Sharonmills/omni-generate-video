---
name: create-template-video
description: Tạo video tin tức dọc 9:16 bằng các template HyperFrames của repo omni-generate-video từ URL bài báo hoặc file .txt tiếng Việt. Dùng khi người dùng yêu cầu tạo video tin tức, short news, video template/poster, bản tin kiểu poster, hoặc muốn xuất video.mp4, voice.mp3 và script.txt để dùng với CapCut.
---

# Create Template Video

Tạo `script.json` từ một URL bài báo hoặc file `.txt`, sau đó chạy pipeline HyperFrames của repo để xuất video hoàn chỉnh.

## Yêu cầu đầu vào

Nhận đúng một trong hai loại đầu vào:

- URL bắt đầu bằng `http://` hoặc `https://`.
- Đường dẫn tới file `.txt` tiếng Việt.

Nếu người dùng chưa cung cấp đầu vào, hỏi họ URL hoặc đường dẫn file. Không yêu cầu API Claude hoặc DeepSeek.

## Chuẩn bị

1. Làm việc trong repo `omni-generate-video`. Xác nhận có `package.json`, `templates/CATALOG.md` và `src/render/template-script-schema.ts`.
2. Đọc `docs/PROJECT_CONTEXT.md` và `docs/TREE.md` trước khi thao tác.
3. Đọc [references/authoring-rules.md](references/authoring-rules.md) trước khi viết nội dung.
4. Đọc `templates/CATALOG.md` và coi catalog là nguồn chính xác duy nhất về `templateId`, slot và kiểu dữ liệu của `inputs`.
5. Đọc `src/render/template-script-schema.ts` để kiểm tra contract hiện tại. Nếu schema hoặc catalog khác hướng dẫn trong skill, ưu tiên source trong repo.

## Quy trình

### 1. Lấy nội dung

- Với URL: dùng công cụ duyệt web hiện có để lấy tiêu đề, nội dung chính khoảng 500–1500 từ, ảnh `og:image` nếu có và domain. Không bịa nội dung không truy cập được. Nếu trang bị paywall, phụ thuộc JavaScript hoặc trả lỗi, đề nghị người dùng lưu bài vào `.txt` rồi dừng.
- Với file `.txt`: đọc file; lấy dòng đầu tối đa 80 ký tự làm tiêu đề, phần còn lại làm nội dung; đặt ảnh là `null` và domain là `local`.

### 2. Tạo thư mục output

Tạo slug ASCII không dấu, chuyển `đ` thành `d`, tối đa 40 ký tự. Dùng timestamp `YYYYMMDD-HHmm` và tạo:

```text
output/<slug>-<timestamp>/
```

Không ghi đè run cũ và không xóa cache hay output khác.

### 3. Soạn `script.json`

Soạn nội dung tiếng Việt trung thành với nguồn:

- Dùng `renderer: "hyperframes"`, `aspect: "9:16"` và voice provider `omnivoice`.
- Tạo 8–12 scene: một hook, 6–10 body và một outro.
- Dùng `frame-liquid-bg-hero` cho hook.
- Dùng `frame-logo-outro` cho outro mặc định; chỉ dùng outro khác có trong catalog khi người dùng yêu cầu.
- Chọn template body theo ý nghĩa scene và tránh lặp đơn điệu.
- Đảm bảo từng `inputs` khớp chính xác catalog.
- Giữ tổng `voiceText` khoảng 270–360 từ; mỗi body scene khoảng 25–40 từ và chỉ truyền đạt một ý.
- Áp dụng toàn bộ quy tắc TTS trong file tham chiếu.

Ghi JSON UTF-8 hợp lệ vào `<outputDir>/script.json` bằng công cụ filesystem hiện có.

### 4. Tự kiểm tra

Kiểm tra và sửa tối đa hai lượt:

- Scene đầu là `hook`, scene cuối là `outro`.
- Mọi `templateId` tồn tại trong catalog.
- Mọi `inputs` đủ slot bắt buộc và đúng kiểu.
- Headline ngắn, tối đa ba dòng.
- `voiceText` không có emoji, URL hoặc ký hiệu bị cấm và mọi số đã được chuyển sang cách đọc tiếng Việt.
- Emoji chỉ xuất hiện vừa phải trong `inputs`.
- JSON khớp schema hiện tại.

### 5. Chạy pipeline

Chạy foreground và theo dõi output:

```bash
npm run pipeline -- <outputDir>/script.json
```

Pipeline cần OmniVoice, FFmpeg/ffprobe và Chrome/Chromium. Nếu thiếu dependency hoặc service, giữ nguyên `script.json`, báo chính xác lỗi và đưa lệnh để người dùng chạy lại. Không tuyên bố video đã hoàn thành nếu pipeline thất bại.

### 6. Báo kết quả

Khi thành công, trả đường dẫn có thể nhấp tới:

- `video.mp4`
- `voice.mp3`
- `script.txt`

Kèm tổng thời lượng nếu log hoặc ffprobe cung cấp. Nêu rõ `outputDir` khi thất bại.

## Cache và tái chạy

Giữ `voice/scene-<id>.mp3` và `clips/scene-<id>.mp4` mặc định. Chỉ xóa file cache của đúng scene cần tạo lại khi người dùng yêu cầu regeneration; không xóa template, fixture hoặc output khác.
