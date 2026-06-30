# Project Context

## Purpose

Generate deterministic short videos from a HyperFrames `script.json`. The
pipeline produces a rendered video, narration audio, and plain caption text.
Content authoring may be handled by the optional Claude skill; production is a
Node.js/TypeScript pipeline using local OmniVoice TTS, HyperFrames/Chromium,
and FFmpeg.

## Main entrypoints

- `npm run pipeline -- <path/to/script.json>` -> `src/cli.ts` ->
  `src/render/template-pipeline.ts`.
- `.claude/skills/create-template-video/SKILL.md`: creates an output directory
  and `script.json` from a URL or local `.txt`, then invokes the pipeline.
- `tsx src/render/template-composer.ts`: standalone two-render template POC.
- `npm run sfx:download` and `npm run sfx:filter`: maintain the optional SFX
  library.

## Important folders and files

- `src/render/template-script-schema.ts`: Zod input contract (3-12 scenes,
  first scene `hook`, last scene `outro`).
- `src/render/template-pipeline.ts`: pipeline orchestration and cache reuse.
- `src/render/template-composer.ts`: HyperFrames invocation and aspect entry
  selection.
- `src/render/video-tools.ts`, `src/assets/audio-tools.ts`: FFmpeg/ffprobe
  processing.
- `src/tts/omnivoice-client.ts`, `src/config.ts`: TTS HTTP client and runtime
  configuration.
- `src/assets/sfx-selector.ts`: deterministic optional SFX selection.
- `templates/` and `templates/CATALOG.md`: vendored visual templates and input
  slot catalog.
- `tests/fixtures/`: MP3 inputs used by audio tests.
- `output/`: ignored generated runs.

## Runtime data flow

1. The CLI receives a `script.json` path and loads `.env.local`.
2. The pipeline validates the JSON and writes all scene narration to
   `script.txt`.
3. OmniVoice generates `voice/scene-<id>.mp3`; existing scene MP3s are reused.
4. FFmpeg concatenates narration with 0.3-second gaps, selects/mixes optional
   SFX, and writes `voice.mp3`.
5. HyperFrames renders each template to `clips/scene-<id>.mp4`; existing raw
   clips are reused. FFmpeg trims or last-frame-pads fitted clips to narration
   duration, with a three-second final outro hold.
6. FFmpeg concatenates fitted clips to `video-silent.mp4` and muxes narration
   into `video.mp4`.

TTS calls are limited by `TTS_CONCURRENCY` (default `1`); template scenes render
sequentially. Missing `assets/sfx/` is allowed and produces narration without
SFX.

## API behavior

### Full fixture replacement

Not implemented. This repository has no proxy fixture-replacement layer;
`tests/fixtures/` contains audio test inputs only.

### Direct modification

Not implemented. This repository has no mitmproxy request/response modifier and
no editing API.

The only application HTTP contract is the outbound OmniVoice call:
`POST <OMNIVOICE_ENDPOINT>/tts` with JSON `{ "text": "..." }`, expecting
`audio/mpeg` bytes. The endpoint defaults to `http://127.0.0.1:8123`. Requests
time out after 60 seconds. Server errors and HTTP 429 are retried with 1, 2, and
4 second delays; other HTTP 4xx responses fail without retry.

## Running the applications

Install dependencies and configure the TTS endpoint:

```bash
npm install
# .env.local: OMNIVOICE_ENDPOINT=http://127.0.0.1:8123
npm run pipeline -- output/<run>/script.json
```

The full pipeline also requires FFmpeg/ffprobe, Chrome/Chromium, and a running
OmniVoice service. There is no mitmproxy modifier or Flask editor in this
checkout, and there are no repository commands for running them.

## Validation commands

```bash
npm test
npm run typecheck
npm run build
npm run pipeline -- output/<run>/script.json
```

Use the first three for repository validation. The last command is an
integration run and needs the external runtime dependencies above.

## Cleanup policy

- Generated output belongs under ignored `output/` and should not be committed.
- Preserve cached `voice/scene-<id>.mp3` and `clips/scene-<id>.mp4` by default.
- Delete a scene MP3 to force TTS regeneration, or its raw scene MP4 to force a
  template re-render; then rerun the pipeline.
- Remove obsolete output run directories manually. Keep source templates and
  `tests/fixtures/` intact.
- FFmpeg concat helpers remove their own temporary directories.
