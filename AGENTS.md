# Repository Guide

## Read first

1. Read `docs/PROJECT_CONTEXT.md`.
2. Read `docs/TREE.md`.
3. Read only the source files relevant to the requested change.

Do not read generated or dependency trees by default: `.git/`, `.venv/`,
`node_modules/`, `logs/`, `dist/`, `build/`, `output/`, `coverage/`, or cache
folders such as `__pycache__/` and `.pytest_cache/`.

## Before editing

- Identify the exact entrypoint for the behavior being changed.
- Find the smallest related file set and follow the call path before editing.
- Avoid unrelated rewrites, formatting churn, and generated files.
- Treat `templates/<id>/` as self-contained visual projects; consult
  `templates/CATALOG.md` when changing template inputs or selection.

## Project overview

This is a Node.js/TypeScript pipeline that turns a validated HyperFrames
`script.json` into a narrated video. It uses a local OmniVoice service for TTS,
HyperFrames/Chromium for template rendering, and FFmpeg/ffprobe for audio and
video processing.

Main entrypoints:

- `src/cli.ts`: CLI behind `npm run pipeline -- <path/to/script.json>`.
- `src/render/template-pipeline.ts`: eight-step production pipeline.
- `.claude/skills/create-template-video/SKILL.md`: optional content-authoring
  workflow that creates `script.json` from a URL or text file.
- `src/render/template-composer.ts`: template renderer and standalone POC.
- `scripts/download-sfx.ts` and `scripts/filter-sfx.ts`: SFX maintenance tasks.

## Runtime data flow

`script.json` is parsed and validated by `TemplateScriptSchema`; narration is
written to `script.txt`; scene speech is fetched from OmniVoice; FFmpeg joins
speech with 0.3-second gaps and mixes optional SFX; HyperFrames renders each
scene; FFmpeg fits clips to narration, concatenates them, and muxes the final
audio. Outputs are written beside the input script, including `voice/`,
`clips/`, `voice.mp3`, and `video.mp4`.

Existing `voice/scene-<id>.mp3` and `clips/scene-<id>.mp4` files are reused.
Rendering scenes is sequential. TTS work uses `TTS_CONCURRENCY` (default `1`).
The authoring skill estimates roughly 15-20 seconds to render each scene and
3-5 minutes for an 8-10 scene video; actual time depends on the machine and
services.

## API behavior

- **Full fixture replacement:** not implemented in this repository. The files
  under `tests/fixtures/` are audio test inputs, not HTTP response fixtures.
- **Direct modification:** not implemented; there is no request/response
  modifier or web editing API.
- **External TTS contract:** the pipeline sends `POST <OMNIVOICE_ENDPOINT>/tts`
  with JSON `{ "text": "..." }`, accepts `audio/mpeg`, and writes the response
  bytes as an MP3. It retries server errors and HTTP 429 responses up to three
  times after the initial request; other HTTP 4xx responses fail immediately.

There is no mitmproxy modifier or Flask editor in the current repository, so
neither can be run from this checkout. Do not invent commands for them.

## Cleanup policy

- Keep generated runs under ignored `output/`; do not commit them.
- Keep scene MP3 and raw scene MP4 caches unless regeneration is required.
- To regenerate one scene's speech, delete its `voice/scene-<id>.mp3`; to
  re-render one scene, delete its `clips/scene-<id>.mp4`, then rerun the CLI.
- Remove obsolete output runs manually. Do not delete source templates or test
  fixtures as cleanup.
- Audio/video helpers remove their own concat temporary directories. Do not
  rely on generated artifacts as source files.

## Validation

Run the smallest relevant check, then broader checks when appropriate:

```bash
npm test
npm run typecheck
npm run build
npm run pipeline -- output/<run>/script.json
```

The full pipeline requires a running OmniVoice service, FFmpeg/ffprobe,
Chrome/Chromium, and a valid script. Unit tests and type checking do not.

## After editing

In the handoff:

- summarize the files changed;
- explain the behavior change;
- provide the exact test command run (or the command the user should run if an
  external dependency prevented validation).
