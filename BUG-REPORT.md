# Bug report (draft) — routing combo OmniRoute → AgentRouter

> Draf laporan untuk https://github.com/diegosouzapw/OmniRoute
> Setup: `omniroute-bin` 3.8.49 (AUR, desktop AppImage), Arch Linux, provider
> AgentRouter (agentrouter.org) terhubung via API key, opencode 1.18.17 via
> `@ai-sdk/openai-compatible`.

## Ringkasan

Request ke model AgentRouter (`agentrouter/claude-opus-4-8`, `claude-opus-5`,
`gpt-5.6-sol`) **sering** (kadang konsisten) gagal dengan
`400 content-blocked` — terutama saat payload datang dari coding agent
(opencode: system prompt ~9 KB + 10 tools + max_tokens 32000) atau saat
dirutekan **melalui combo** — sementara request minimal curl ke model yang
sama **berhasil (200)** pada waktu yang hampir bersamaan.

Error di sisi gateway:
```
[400]: content-blocked (request id: ...)
type: "agent_router_api_error", code: "content-blocked"
upstream_details.error.code: "content-blocked"
```

Untuk model `claude-opus-5` kadang muncul error lain dari AgentRouter:
```
[500]: 分组 tokenrouter 下模型 claude-opus-5 无可用渠道（distributor）
```
→ "di grup `tokenrouter`, model `claude-opus-5` tidak punya channel/distributor".

## Gejala yang teramati (time-varying, bukan deterministik per payload)

| Uji | Hasil |
|---|---|
| curl minimal → `agentrouter/claude-opus-4-8` | 200 (sering), 400 (kadang) |
| curl replay payload opencode persis (30 KB) | 400 (saat itu), 200 (saat diuji lagi beberapa menit kemudian) |
| curl minimal → combo berisi agentrouter saja | 400 konsisten di satu momen, 200 di momen lain |
| opencode → `omniroute/agentrouter/claude-opus-4-8` | 400 (mayoritas) |
| opencode → `omniroute/ops-free` (felo dulu) | 200 (felo yang menjawab) |
| `felo/felo-chat` | 200, lalu 429 setelah banyak request ("Felo thread creation failed with HTTP 429") |

Kesimpulan sementara: `content-blocked` datang dari upstream AgentRouter dan
**berfluktuasi terhadap waktu/volume**, bukan ditentukan payload. Tidak ada
pemicu tunggal yang bisa diisolasi (system prompt 9 KB, tools, max_tokens,
stream_options, header session — semua lolos di satu momen lalu 400 di momen
lain dengan payload yang sama persis).

## Pertanyaan/dugaan

1. Apakah `content-blocked` dari AgentRouter = WAF/anti-abuse mereka terhadap
   traffic agent non-Claude-Code (fingerprint `CC_WIRE_IMAGE_BUILTINS`)?
2. Apakah ada parameter yang bisa dipasang di combo/connection agar request
   lewat combo diperlakukan sama dengan request langsung?
3. `importFreeModelsOnly: true` pada connection — apakah model
   `claude-opus-4-8`/`claude-opus-5`/`gpt-5.6-sol` benar-benar masuk tier
   gratis grup `tokenrouter`? (`claude-opus-5` sempat dilaporkan "no available
   distributor".)

## Langkah reproduksi

1. Connect AgentRouter (API key) di OmniRoute.
2. `curl -X POST localhost:20128/v1/chat/completions -d '{"model":"agentrouter/claude-opus-4-8","messages":[{"role":"user","content":"halo"}]}'` → 200 (umumnya).
3. Ulangi bertubi-tubi atau kirim payload besar (system prompt ~9 KB + tools) → amati `400 content-blocked` yang muncul-hilang.
4. Buat combo round-robin berisi model agentrouter → request via combo cenderung gagal lebih sering daripada langsung.
