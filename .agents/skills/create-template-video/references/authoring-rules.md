# Quy tắc biên soạn video

## Cấu trúc JSON nền

Luôn xác nhận lại với `src/render/template-script-schema.ts` và `templates/CATALOG.md` trước khi ghi file.

```json
{
  "version": "1.0",
  "renderer": "hyperframes",
  "aspect": "9:16",
  "metadata": {
    "title": "...",
    "source": { "url": "...", "domain": "...", "image": null },
    "channel": "AI Coding"
  },
  "voice": { "provider": "omnivoice", "speed": 1.0 },
  "scenes": []
}
```

Mỗi scene gồm `id`, `type`, `voiceText`, `templateId` và `inputs`. Dùng URL nguồn thật cho `metadata.source.url`; với file local, dùng giá trị phù hợp schema và không bịa URL.

## Chọn template

Catalog trong repo là nguồn chính xác về template và slots. Dùng các heuristic sau nếu các template này vẫn còn trong catalog:

- `frame-vignelli`: một số liệu nổi bật, sắc thái editorial tối.
- `frame-pentagram-stat`: một benchmark hoặc số liệu cần cảm giác neon/kỹ thuật.
- `frame-bold-poster`: tuyên bố mạnh nhiều dòng, có figure lớn.
- `frame-build-minimal`: nhận định ngắn xoay quanh một từ khóa.
- `frame-creative-voltage`: khẩu hiệu hoặc câu sáng tạo ngắn.
- `frame-glitch-title`: tin sốc, breaking news hoặc công nghệ.
- `frame-aicoding-list`: danh sách, checklist hoặc 2–5 mục.
- `frame-aicoding-comparison`: so sánh đúng hai phía.

Xen kẽ template hợp lý; không ép nội dung vào template chỉ để tạo sự đa dạng. Không tự đặt slot chưa có trong catalog.

## Nhịp nội dung

- Tạo 8–12 scene, tổng khoảng 270–360 từ narration.
- Giữ mỗi body scene khoảng 25–40 từ và một ý duy nhất.
- Hook nói ngay điểm đáng chú ý nhất; không mở đầu vòng vo.
- Giữ dữ kiện, đơn vị, tên riêng và mức độ chắc chắn đúng với nguồn.
- Outro ngắn, phù hợp thương hiệu và không thêm tuyên bố thực tế mới.

## TTS tiếng Việt

`voiceText` là lời OmniVoice đọc; `inputs` là chữ hiển thị. Không dùng cùng cách định dạng cho cả hai.

Trong `voiceText`:

- Viết số và ký hiệu thành cách đọc tiếng Việt tự nhiên.
- Không dùng emoji, icon, URL hoặc các ký hiệu `→ & % $ # + =`.
- Kết câu bằng `.` hoặc `?` để tạo nhịp nghỉ.
- Giữ nguyên tên thương hiệu; phiên âm acronym chỉ khi cần để TTS đọc đúng.

Trong `inputs`:

- Giữ cách trình bày số gọn, ví dụ `5.5`, `82.7%`, `200MP`.
- Cho phép emoji vừa phải, tối đa khoảng một icon mỗi field.
- Không đặt emoji trong field được animate từng ký tự như hero word.

Ví dụ chuyển đổi cho `voiceText`:

| Hiển thị | Cách đọc |
| --- | --- |
| `GPT 5.5` | `GPT năm chấm năm` |
| `82.7%` | `tám mươi hai phẩy bảy phần trăm` |
| `iOS 18.2` | `iOS mười tám chấm hai` |
| `200MP` | `hai trăm megapixel` |
| `5000mAh` | `năm nghìn miliampe giờ` |
| `$5` | `năm đô la` |
| `2x` | `gấp đôi` |
| `3:1` | `ba trên một` |
