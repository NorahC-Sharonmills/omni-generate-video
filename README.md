# Omni Generate Video

Pipeline Node.js/TypeScript tạo video tin tức từ một `script.json` đã được kiểm tra. Mỗi scene dùng một template HyperFrames, OmniVoice tạo giọng đọc tiếng Việt, còn FFmpeg ghép audio, hiệu ứng âm thanh và video thành file hoàn chỉnh.

Đầu ra chính:

| File | Công dụng |
| --- | --- |
| `video.mp4` | Video hoàn chỉnh, đã ghép giọng đọc và SFX |
| `voice.mp3` | Track narration cuối cùng, có thể đưa riêng vào CapCut |
| `script.txt` | Toàn bộ lời đọc, dùng để tạo caption tự động |

Pipeline phù hợp nhất với video dọc `9:16` cho TikTok, YouTube Shorts và Reels. Các template dọc hiện tại render ở kích thước `1080×1920`.

> Repository này không kèm server OmniVoice. Trước khi chạy pipeline, bạn phải có một server TTS tương thích đang hoạt động. Repository cũng không có web editor, Flask editor, mitmproxy modifier hay API chỉnh sửa video.

## Mục lục

- [Pipeline làm gì](#pipeline-làm-gì)
- [Yêu cầu hệ thống](#yêu-cầu-hệ-thống)
- [Cài đặt từng bước](#cài-đặt-từng-bước)
- [Cách 1: tạo video bằng AI agent](#cách-1-tạo-video-bằng-ai-agent)
- [Cách 2: tự viết script.json](#cách-2-tự-viết-scriptjson)
- [Chạy pipeline](#chạy-pipeline)
- [Cấu trúc script.json](#cấu-trúc-scriptjson)
- [Chọn template và viết nội dung](#chọn-template-và-viết-nội-dung)
- [Hiệu ứng âm thanh](#hiệu-ứng-âm-thanh)
- [Cache và cách render lại](#cache-và-cách-render-lại)
- [Cấu trúc output](#cấu-trúc-output)
- [Xử lý lỗi](#xử-lý-lỗi)
- [Kiểm tra mã nguồn](#kiểm-tra-mã-nguồn)

## Pipeline làm gì

Lệnh chính:

```bash
npm run pipeline -- output/<ten-run>/script.json
```

Lệnh trên gọi `src/cli.ts`, sau đó chạy tám bước trong `src/render/template-pipeline.ts`:

1. Đọc và validate `script.json` bằng Zod.
2. Gộp `voiceText` của các scene thành `script.txt`.
3. Gọi OmniVoice để tạo MP3 cho từng scene.
4. Ghép các đoạn giọng, chèn khoảng nghỉ `0.3` giây và tạo `voice-raw.mp3`.
5. Chọn SFX, trộn SFX vào narration và tạo `voice.mp3`.
6. Render từng template bằng HyperFrames, rồi cắt hoặc giữ frame cuối để khớp thời lượng narration.
7. Ghép các clip, sau đó mux `voice.mp3` vào video.
8. In đường dẫn kết quả và tổng thời lượng.

Một scene thông thường dài bằng narration cộng `0.3` giây chuyển tiếp. Scene outro cuối cùng được giữ hình thêm `3` giây. Video vì vậy dài hơn track narration ở phần đuôi.

## Yêu cầu hệ thống

| Thành phần | Yêu cầu | Cách kiểm tra |
| --- | --- | --- |
| Node.js | Khuyến nghị Node.js 22 trở lên | `node --version` |
| npm | Đi kèm Node.js | `npm --version` |
| FFmpeg | Có trong `PATH`, hỗ trợ `libx264`, `libmp3lame`, AAC | `ffmpeg -version` |
| ffprobe | Có trong `PATH` | `ffprobe -version` |
| Chrome/Chromium | Cần cho HyperFrames render HTML thành video | mở Chrome/Chromium bình thường |
| OmniVoice | Server local tương thích contract `/tts` | xem phần kiểm tra TTS bên dưới |
| Internet | Cần khi cài npm và lần đầu `npx` lấy HyperFrames `0.6.94` | — |

### Cài Node.js

Cài Node.js từ [nodejs.org](https://nodejs.org/) hoặc trình quản lý package của hệ điều hành. Sau khi cài, mở terminal mới và chạy:

```bash
node --version
npm --version
```

### Cài FFmpeg

Windows:

```powershell
winget install Gyan.FFmpeg
```

macOS:

```bash
brew install ffmpeg
```

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install ffmpeg
```

Đóng và mở lại terminal, sau đó xác nhận cả hai binary đều dùng được:

```bash
ffmpeg -version
ffprobe -version
```

## Cài đặt từng bước

### 1. Clone repository

```bash
git clone https://github.com/NorahC-Sharonmills/omni-generate-video.git
cd omni-generate-video
```

Nếu bạn đang dùng một fork khác, thay URL bằng URL của fork đó.

### 2. Cài dependency

```bash
npm install
```

### 3. Tạo `.env.local`

Tạo file `.env.local` ở thư mục gốc, cùng cấp với `package.json`:

```env
TTS_PROVIDER=omnivoice
OMNIVOICE_ENDPOINT=http://127.0.0.1:8123
TTS_CONCURRENCY=1
```

Ý nghĩa từng biến:

| Biến | Mặc định | Ý nghĩa |
| --- | --- | --- |
| `TTS_PROVIDER` | `omnivoice` | Hiện chỉ chấp nhận đúng giá trị `omnivoice` |
| `OMNIVOICE_ENDPOINT` | `http://127.0.0.1:8123` | Base URL của server TTS, không thêm `/tts` ở cuối |
| `TTS_CONCURRENCY` | `1` | Số request TTS chạy song song; phải là số nguyên |

Giữ `TTS_CONCURRENCY=1` khi mới cài. Chỉ tăng khi server TTS và phần cứng chịu được nhiều request đồng thời. Việc render template vẫn chạy tuần tự.

### 4. Khởi động OmniVoice

OmniVoice là dịch vụ bên ngoài repository này, vì vậy hãy chạy nó theo tài liệu của bản OmniVoice bạn đã cài. Pipeline cần đúng contract sau:

```http
POST <OMNIVOICE_ENDPOINT>/tts
Content-Type: application/json
Accept: audio/mpeg

{"text":"Xin chào, đây là câu kiểm tra."}
```

Response thành công phải là bytes MP3 với content type `audio/mpeg`. Không cần API key hoặc voice ID; giọng được cấu hình ở phía server.

Kiểm tra trên PowerShell:

```powershell
Invoke-WebRequest `
  -Uri "http://127.0.0.1:8123/tts" `
  -Method Post `
  -ContentType "application/json; charset=utf-8" `
  -Headers @{ Accept = "audio/mpeg" } `
  -Body '{"text":"Xin chào, đây là câu kiểm tra."}' `
  -OutFile "tts-test.mp3"

ffprobe tts-test.mp3
```

Kiểm tra trên macOS/Linux:

```bash
curl --fail \
  -H 'Content-Type: application/json' \
  -H 'Accept: audio/mpeg' \
  -d '{"text":"Xin chào, đây là câu kiểm tra."}' \
  http://127.0.0.1:8123/tts \
  --output tts-test.mp3

ffprobe tts-test.mp3
```

Client đặt timeout `60` giây. Lỗi HTTP `429` và lỗi server `5xx` được thử lại tối đa ba lần sau request đầu, với khoảng chờ lần lượt `1`, `2` và `4` giây. Các lỗi HTTP `4xx` khác dừng ngay.

### 5. Kiểm tra project trước khi render

```bash
npm run typecheck
npm test
```

Hai lệnh này không cần OmniVoice, Chrome hay FFmpeg.

## Cách 1: tạo video bằng AI agent

Repository có skill `create-template-video` tại `.agents/skills/create-template-video/`. Skill nhận một URL bài viết hoặc đường dẫn tới file `.txt` tiếng Việt, biên soạn nội dung, tạo `script.json`, rồi chạy pipeline.

Trong Codex, yêu cầu trực tiếp:

```text
Dùng create-template-video tạo video từ https://example.com/bai-viet
```

Hoặc với file local:

```text
Dùng create-template-video tạo video từ news/bai-viet.txt
```

Đầu vào phải là đúng một trong hai dạng:

- URL bắt đầu bằng `http://` hoặc `https://` và agent truy cập được nội dung;
- file `.txt` tiếng Việt có sẵn trên máy.

Skill sẽ:

1. đọc nguồn và không tự bịa phần không truy cập được;
2. tạo thư mục `output/<slug>-<YYYYMMDD-HHmm>/` mới;
3. viết video dọc gồm một hook, các body scene và một outro;
4. kiểm tra template, slot, quy tắc đọc số tiếng Việt và schema;
5. chạy pipeline ở foreground;
6. trả đường dẫn `video.mp4`, `voice.mp3` và `script.txt` khi thành công.

Nếu trang bị paywall, bắt buộc JavaScript hoặc chặn truy cập, hãy lưu nội dung thành file `.txt` rồi dùng file đó. Skill không yêu cầu Claude API hay DeepSeek API.

## Cách 2: tự viết script.json

Pipeline không nhận URL trực tiếp. Khi không dùng skill, bạn phải tự chuẩn bị `script.json`.

### 1. Tạo thư mục run

PowerShell:

```powershell
New-Item -ItemType Directory -Force output/my-first-video
```

macOS/Linux:

```bash
mkdir -p output/my-first-video
```

Nên luôn dùng đúng cấu trúc `output/<ten-run>/script.json`. Code tìm thư viện SFX theo cấu trúc này; nếu đặt run sâu hơn hoặc ngoài `output/`, video vẫn có thể render nhưng pipeline có thể không tìm thấy `assets/sfx/`.

### 2. Tạo `output/my-first-video/script.json`

Ví dụ tối thiểu hợp lệ với ba scene:

```json
{
  "version": "1.0",
  "renderer": "hyperframes",
  "aspect": "9:16",
  "metadata": {
    "title": "Ví dụ video đầu tiên",
    "source": {
      "url": "",
      "domain": "local",
      "image": null
    },
    "channel": "AI Coding"
  },
  "voice": {
    "provider": "omnivoice",
    "speed": 1.0
  },
  "scenes": [
    {
      "id": "hook",
      "type": "hook",
      "voiceText": "Đây là video đầu tiên được tạo hoàn toàn từ một file JSON.",
      "templateId": "frame-liquid-bg-hero",
      "inputs": {
        "kicker": "AI Coding",
        "headline": "Video đầu tiên",
        "subheadline": "Từ JSON đến video dọc hoàn chỉnh",
        "cta": "Xem ngay",
        "brand": "AI Coding"
      }
    },
    {
      "id": "body-1",
      "type": "body",
      "voiceText": "HyperFrames dựng phần hình, OmniVoice tạo giọng đọc, còn FFmpeg ghép tất cả thành video.",
      "templateId": "frame-pentagram-stat",
      "inputs": {
        "label": "Quy trình",
        "headline": "3 bước",
        "subtitle": "Dựng hình, tạo giọng và ghép video",
        "anchor": "3",
        "footer_left": "AI Coding",
        "footer_right": "local"
      }
    },
    {
      "id": "outro",
      "type": "outro",
      "voiceText": "Theo dõi AI Coding để xem thêm các quy trình tự động hóa hữu ích.",
      "templateId": "frame-logo-outro",
      "inputs": {
        "brand_name": "AI Coding",
        "tagline": "Tự động hóa nội dung bằng AI",
        "primary_url": "aicodingvn.vercel.app"
      }
    }
  ]
}
```

Lưu file dưới dạng UTF-8 để tiếng Việt không bị lỗi dấu.

### 3. Chạy pipeline

```bash
npm run pipeline -- output/my-first-video/script.json
```

Không bỏ dấu `--`: npm dùng nó để chuyển đường dẫn phía sau cho `src/cli.ts`.

## Chạy pipeline

Cú pháp:

```bash
npm run pipeline -- <duong-dan-toi-script.json>
```

Ví dụ PowerShell:

```powershell
npm run pipeline -- .\output\my-first-video\script.json
```

Ví dụ macOS/Linux:

```bash
npm run pipeline -- ./output/my-first-video/script.json
```

Chạy lệnh từ thư mục gốc repository. `.env.local` cũng được đọc theo thư mục làm việc hiện tại.

Trong lần render đầu, mỗi scene thường cần khoảng `15–20` giây để render, nhưng thời gian thực tế phụ thuộc CPU, GPU, Chrome, số scene và độ dài narration. Một video `8–10` scene thường mất vài phút. HyperFrames được gọi qua `npx -y hyperframes@0.6.94`, vì vậy lần đầu có thể chậm hơn do tải package.

Khi thành công, log cuối có dạng:

```text
=== Result ===
Video:  output/my-first-video/video.mp4
Audio:  output/my-first-video/voice.mp3  (cho CapCut)
Script: output/my-first-video/script.txt  (cho CapCut auto-caption)
Tong thoi luong: 42.10s
```

## Cấu trúc script.json

### Các field cấp cao

| Field | Bắt buộc | Quy tắc |
| --- | --- | --- |
| `version` | Có | Phải là chuỗi `"1.0"` |
| `renderer` | Có | Phải là `"hyperframes"` |
| `aspect` | Không | `"9:16"`, `"16:9"` hoặc `"1:1"`; mặc định `"9:16"` |
| `metadata` | Có | Thông tin tiêu đề, nguồn và channel |
| `voice` | Có | Provider và speed |
| `scenes` | Có | Từ `3` đến `12` scene |

### `metadata`

```json
{
  "title": "Tiêu đề không được rỗng",
  "source": {
    "url": "https://example.com/article",
    "domain": "example.com",
    "image": null
  },
  "channel": "AI Coding"
}
```

- `source.url` và `source.domain` là chuỗi; với nguồn local có thể dùng `""` và `"local"`.
- `source.image` phải là URL hợp lệ hoặc `null`.
- Pipeline hiện lưu metadata trong JSON nhưng chưa tự tải hoặc đưa `source.image` vào template.

### `voice`

```json
{
  "provider": "omnivoice",
  "speed": 1.0
}
```

- `provider` chỉ chấp nhận `omnivoice`.
- `speed` phải từ `0.5` đến `2.0`.
- Lưu ý: phiên bản hiện tại chỉ validate `speed`; request TTS chỉ gửi `{ "text": "..." }`. Thay đổi `speed` chưa làm giọng nhanh hoặc chậm hơn.

### `scenes`

Mỗi scene có dạng:

```json
{
  "id": "body-1",
  "type": "body",
  "voiceText": "Lời đọc của scene.",
  "templateId": "frame-vignelli",
  "inputs": {},
  "sfx": {
    "name": "emphasis/ding",
    "volume": 0.35,
    "startOffsetSec": 0.2
  }
}
```

Quy tắc schema:

- `id`, `voiceText` và `templateId` không được rỗng;
- `type` chỉ là `hook`, `body` hoặc `outro`;
- scene đầu tiên phải có `type: "hook"`;
- scene cuối cùng phải có `type: "outro"`;
- tổng số scene từ `3` đến `12`;
- `inputs` là object và mặc định là `{}`;
- `sfx.volume` từ `0` đến `1`, mặc định `0.4`;
- `sfx.startOffsetSec` mặc định `0`.

Schema chưa bắt buộc `id` phải duy nhất, nhưng bạn luôn nên dùng ID duy nhất, ngắn và an toàn cho tên file, ví dụ `hook`, `body-1`, `body-2`, `outro`. Tránh `/`, `\`, `..` và các ký tự không hợp lệ trong tên file. ID trùng nhau sẽ dùng chung tên cache và làm kết quả sai.

Schema cũng giữ `inputs` ở dạng mở. Điều đó không có nghĩa mọi field đều đúng: bạn phải đối chiếu [`templates/CATALOG.md`](templates/CATALOG.md) để biết chính xác tên slot, kiểu dữ liệu và giới hạn độ dài của từng template.

### Aspect ratio

- `9:16`: dùng `compositions/portrait.html`; đây là chế độ được hỗ trợ đầy đủ và nên dùng.
- `16:9`: dùng `index.html`.
- `1:1`: tìm `compositions/square.html`; nếu template không có file này, renderer fallback về `index.html`. Các template hiện tại chủ yếu cung cấp `9:16` và `16:9`, vì vậy không nên kỳ vọng output vuông đúng chuẩn nếu chưa tự thêm composition square.

## Chọn template và viết nội dung

Danh sách dưới đây chỉ giúp chọn nhanh. Slot đầy đủ và giới hạn ký tự nằm trong [`templates/CATALOG.md`](templates/CATALOG.md); catalog là nguồn chính xác cần ưu tiên.

| Template | Vai trò phù hợp | Dùng khi |
| --- | --- | --- |
| `frame-liquid-bg-hero` | Hook | Mở đầu hiện đại, headline và CTA |
| `frame-bold-poster` | Hook/body | Tuyên bố mạnh, figure lớn, tối đa ba dòng headline |
| `frame-glitch-title` | Hook/body | Tin nóng, công nghệ, sắc thái cyberpunk |
| `frame-creative-voltage` | Hook/body | Câu sáng tạo hoặc khẩu hiệu ngắn |
| `frame-vignelli` | Body | Một số liệu nổi bật, tương phản cao |
| `frame-pentagram-stat` | Body | Benchmark, phần trăm hoặc con số hero |
| `frame-build-minimal` | Body | Một từ khóa ngắn được reveal từng ký tự |
| `frame-aicoding-list` | Body | Danh sách từ hai đến năm mục |
| `frame-aicoding-comparison` | Body | So sánh đúng hai phía |
| `frame-logo-outro` | Outro | End-card logo mặc định |
| `frame-statement-outro` | Outro | CTA dạng poster giấy đỏ |

### Quy tắc viết `voiceText`

`voiceText` là nội dung OmniVoice đọc, không phải text hiển thị. Để giọng tự nhiên hơn:

- viết số và ký hiệu thành chữ tiếng Việt;
- không dùng emoji, URL hoặc các ký hiệu `→`, `&`, `%`, `$`, `#`, `+`, `=`;
- kết câu bằng dấu `.` hoặc `?` để tạo nhịp nghỉ;
- mỗi body scene chỉ nên trình bày một ý;
- giữ nguyên tên thương hiệu, chỉ phiên âm acronym nếu OmniVoice đọc sai.

Ví dụ:

| Chữ hiển thị trong `inputs` | Nên viết trong `voiceText` |
| --- | --- |
| `GPT 5.5` | `GPT năm chấm năm` |
| `82.7%` | `tám mươi hai phẩy bảy phần trăm` |
| `iOS 18.2` | `iOS mười tám chấm hai` |
| `200MP` | `hai trăm megapixel` |
| `5000mAh` | `năm nghìn miliampe giờ` |
| `$5` | `năm đô la` |
| `2x` | `gấp đôi` |

### Quy tắc viết `inputs`

`inputs` là chữ xuất hiện trên màn hình:

- giữ số ở dạng ngắn như `5.5`, `82.7%`, `200MP`;
- headline càng ngắn càng tốt;
- có thể dùng emoji vừa phải;
- không đặt emoji trong field animate từng ký tự, ví dụ `hero` của `frame-build-minimal`;
- array và object phải đúng kiểu catalog, đặc biệt với `headline`, `display_lines`, `items`, `left` và `right`.

Một video tin tức dễ xem thường có `8–12` scene, tổng narration khoảng `270–360` từ và mỗi body scene khoảng `25–40` từ. Đây là hướng dẫn biên tập, không phải giới hạn của schema.

## Hiệu ứng âm thanh

SFX là tùy chọn. Nếu không có thư mục `assets/sfx/`, pipeline vẫn tạo video và `voice.mp3`, chỉ không có hiệu ứng âm thanh.

### Tải và lọc thư viện SFX

Chạy từ thư mục gốc:

```bash
npm run sfx:download
npm run sfx:filter
```

Hai lệnh làm hai việc khác nhau:

1. `sfx:download` tải file thô từ MyInstants vào `SFX/<category>/`;
2. `sfx:filter` dùng ffprobe, chỉ copy file dài từ `0.1` đến `3.0` giây sang `assets/sfx/<category>/`.

`SFX/` và output được ignore khỏi Git. Thư viện đã lọc trong `assets/sfx/` là nơi pipeline thực sự đọc.

Tùy chọn nâng cao:

```bash
npm run sfx:download -- --target SFX --max 5
npm run sfx:download -- --config path/to/sfx-config.json
npm run sfx:filter -- --source SFX --target assets/sfx --min-sec 0.1 --max-sec 3
npm run sfx:filter -- --source SFX --target assets/sfx --overwrite
```

### Cách pipeline tự chọn SFX

Thứ tự ưu tiên:

1. `scene.sfx` chỉ định trực tiếp;
2. từ khóa trong `voiceText`, ví dụ “cảnh báo” → `alert`, “kỷ lục” → `success`, “ra mắt” → `reveal`;
3. mặc định theo loại scene: hook, body hoặc outro;
4. fallback sang bất kỳ category có file.

Trong một category, file được chọn bằng hash của scene ID. Cùng scene ID và cùng thư viện sẽ chọn cùng một file.

### Chỉ định SFX thủ công

Nếu file là `assets/sfx/emphasis/ding.mp3`:

```json
"sfx": {
  "name": "emphasis/ding",
  "volume": 0.35,
  "startOffsetSec": 0.2
}
```

Không thêm đuôi `.mp3` vì pipeline tự nối đuôi này. Nếu đường dẫn không tồn tại, pipeline bỏ qua SFX đó mà không dừng toàn bộ run.

Tắt SFX cho một scene:

```json
"sfx": {
  "name": "none"
}
```

## Cache và cách render lại

Pipeline tái sử dụng hai loại file:

- `voice/scene-<id>.mp3`: cache giọng đọc;
- `clips/scene-<id>.mp4`: cache clip template thô.

Pipeline không so sánh nội dung JSON với cache. Nếu file đã tồn tại, nó được dùng lại ngay cả khi `voiceText`, `templateId` hoặc `inputs` đã đổi.

| Bạn thay đổi | Cần xóa trước khi chạy lại |
| --- | --- |
| `voiceText` của một scene | `voice/scene-<id>.mp3` |
| `templateId` hoặc `inputs` của một scene | `clips/scene-<id>.mp4` |
| Cả lời đọc lẫn hình | Cả hai file trên |
| SFX hoặc thư viện SFX | Không cần xóa cache scene; `voice.mp3` được tạo lại |
| Chỉ thứ tự scene | Thường không cần xóa cache, nhưng kiểm tra ID vẫn duy nhất |

PowerShell, ví dụ tạo lại scene `body-2`:

```powershell
Remove-Item -LiteralPath "output/my-first-video/voice/scene-body-2.mp3"
Remove-Item -LiteralPath "output/my-first-video/clips/scene-body-2.mp4"
npm run pipeline -- output/my-first-video/script.json
```

macOS/Linux:

```bash
rm output/my-first-video/voice/scene-body-2.mp3
rm output/my-first-video/clips/scene-body-2.mp4
npm run pipeline -- output/my-first-video/script.json
```

Các file `scene-<id>-fit.mp4`, `voice-raw.mp3`, `voice.mp3`, `video-silent.mp4` và `video.mp4` được tạo lại trong mỗi run. Không xóa source template hoặc file trong `tests/fixtures/` để xử lý cache.

## Cấu trúc output

```text
output/my-first-video/
├── script.json
├── script.txt
├── voice/
│   ├── scene-hook.mp3
│   ├── scene-body-1.mp3
│   └── scene-outro.mp3
├── clips/
│   ├── scene-hook.mp4
│   ├── scene-hook-fit.mp4
│   ├── scene-body-1.mp4
│   ├── scene-body-1-fit.mp4
│   ├── scene-outro.mp4
│   └── scene-outro-fit.mp4
├── voice-raw.mp3
├── voice.mp3
├── video-silent.mp4
└── video.mp4
```

| File/thư mục | Có thể xóa? | Ghi chú |
| --- | --- | --- |
| `script.json` | Không, nếu muốn chạy lại | Input gốc |
| `script.txt` | Có | Pipeline tạo lại |
| `voice/scene-*.mp3` | Có chủ đích | Xóa sẽ gọi TTS lại |
| `clips/scene-*.mp4` | Có chủ đích | Xóa raw clip sẽ render scene lại |
| `clips/scene-*-fit.mp4` | Có | Pipeline luôn tạo lại |
| `voice-raw.mp3`, `voice.mp3` | Có | Pipeline tạo lại |
| `video-silent.mp4`, `video.mp4` | Có | Pipeline tạo lại |

Giữ các run trong `output/`; thư mục này đã được ignore để tránh commit video và cache dung lượng lớn.

## Xử lý lỗi

### `Usage: npm run pipeline -- <path/to/script.json>`

Bạn chưa truyền đường dẫn hoặc quên `--`:

```bash
npm run pipeline -- output/my-first-video/script.json
```

### `ENOENT ... script.json`

Đường dẫn sai hoặc bạn không chạy từ root repository. Kiểm tra:

```powershell
Test-Path .\output\my-first-video\script.json
Get-Location
```

### `TTS_PROVIDER must be "omnivoice"`

Sửa `.env.local`:

```env
TTS_PROVIDER=omnivoice
```

### `Env var TTS_CONCURRENCY must be integer`

Dùng số nguyên như `1`, `2`, `3`; không dùng `1.5` hoặc chữ.

### `ECONNREFUSED 127.0.0.1:8123`

OmniVoice chưa chạy hoặc endpoint sai. Kiểm tra server và `OMNIVOICE_ENDPOINT`, sau đó gọi thử `/tts` bằng lệnh ở phần cài đặt.

### `OmniVoice TTS failed (status 400/404/...)`

- `404`: endpoint đang trỏ sai base URL; pipeline tự thêm `/tts`.
- `400/422`: server không chấp nhận JSON `{ "text": "..." }` như contract yêu cầu.
- `401/403`: server của bạn có auth nhưng client hiện không gửi token.

### `ffmpeg` hoặc `ffprobe` không được nhận diện

Cài FFmpeg, thêm thư mục binary vào `PATH`, rồi mở terminal mới. Xác nhận cả `ffmpeg -version` và `ffprobe -version` chạy được.

### `Template not found`

`templateId` không khớp tên folder trong `templates/`. So sánh với [`templates/CATALOG.md`](templates/CATALOG.md). Giá trị phân biệt chính xác ký tự và dấu gạch ngang.

### HyperFrames render thất bại

Kiểm tra theo thứ tự:

1. Chrome/Chromium đã cài và có thể mở;
2. máy có Internet ở lần đầu để `npx` lấy `hyperframes@0.6.94`;
3. `inputs` đúng kiểu theo catalog;
4. ổ đĩa đủ chỗ cho MP4 trung gian;
5. thử chạy lại sau khi xóa đúng `clips/scene-<id>.mp4` bị lỗi.

### Đã sửa JSON nhưng video hoặc giọng vẫn cũ

Đây là cache, không phải renderer bỏ qua thay đổi. Xóa MP3 nếu sửa `voiceText`; xóa raw MP4 nếu sửa `templateId` hoặc `inputs`. Xem bảng [Cache và cách render lại](#cache-và-cách-render-lại).

### Video không có SFX

Kiểm tra:

```powershell
Test-Path .\assets\sfx
Get-ChildItem .\assets\sfx -Recurse -Filter *.mp3 | Select-Object -First 5
```

Nếu chưa có file, chạy cả hai lệnh:

```bash
npm run sfx:download
npm run sfx:filter
```

Đồng thời giữ script ở đúng dạng `output/<ten-run>/script.json` để pipeline tìm đúng `assets/sfx/`.

### JSON validate thất bại

Đọc message Zod trong log và kiểm tra:

- `version` có đúng `1.0` không;
- `renderer` có đúng `hyperframes` không;
- có từ ba đến mười hai scene không;
- scene đầu là hook và scene cuối là outro không;
- `source.image` là URL hợp lệ hoặc `null` không;
- `voice.speed` có nằm trong `0.5–2.0` không;
- JSON có dấu phẩy thừa hoặc sai dấu ngoặc không.

## Kiểm tra mã nguồn

Chạy kiểm tra nhỏ nhất trước:

```bash
npm test
npm run typecheck
```

Build TypeScript:

```bash
npm run build
```

Build tạo JavaScript trong `dist/`, nhưng cách chạy production được hỗ trợ trong repository vẫn là:

```bash
npm run pipeline -- output/<ten-run>/script.json
```

Full integration test cần OmniVoice, FFmpeg/ffprobe, Chrome/Chromium và một `script.json` hợp lệ:

```bash
npm run pipeline -- output/my-first-video/script.json
```

## Entrypoint và tài liệu liên quan

| Tệp | Vai trò |
| --- | --- |
| [`src/cli.ts`](src/cli.ts) | CLI nhận đường dẫn `script.json` |
| [`src/render/template-pipeline.ts`](src/render/template-pipeline.ts) | Điều phối pipeline tám bước |
| [`src/render/template-script-schema.ts`](src/render/template-script-schema.ts) | Schema Zod của input |
| [`src/render/template-composer.ts`](src/render/template-composer.ts) | Gọi HyperFrames và chọn composition theo aspect |
| [`src/tts/omnivoice-client.ts`](src/tts/omnivoice-client.ts) | HTTP contract, timeout và retry TTS |
| [`templates/CATALOG.md`](templates/CATALOG.md) | Danh sách template, slot và giới hạn nội dung |
| [`.agents/skills/create-template-video/SKILL.md`](.agents/skills/create-template-video/SKILL.md) | Workflow tạo video từ URL hoặc `.txt` |

## License

[MIT](LICENSE)
