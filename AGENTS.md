# LogX

Native macOS OkHttp inspector — **faqat USB/live lokal**. RTDB/tarmoq loglari yo‘q.
Backend: OnlineMahalla monitor `http://127.0.0.1:8787` (devices + http-stream only).

Run: `bash scripts/run.sh`
Test: `swift test`

## HARD

- **Har bir o'zgarishdan keyin release run qilinadi (Qoida):** `bash scripts/run.sh` orqali ilovani release build qilib ishga tushirish shart.
- **REAL test TAQIQ.** Agent REAL-VERIFY / live QA / `qa` spawn / full-qa / desktop-27 / picky live surface qilmaydi.
- Done = `swift test` exit 0 (+ kerak bo‘lsa fl-verifier). Live sirt — operator yoki boshqa (FL) project.
- REAL-VERIFY faqat boshqa client projectlar uchun.

## Arxitektura xaritasi (2026-08-31)
- `Sources/LogX/` — asosiy target · `Sources/LogXCore/` — core target
- `Tests/` — testlar · `Resources/` — assetlar · `scripts/`, `dist/` — build
