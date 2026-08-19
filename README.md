# LogX

Ulangan Android qurilmalardagi OkHttp so‘rovlarini ko‘radigan macOS ilova.

```bash
bash scripts/run.sh
```

Ilova: `dist/LogX.app`

## Nima bor

- Ulangan `adb` device-lar (tanlash)
- App filter: ulangan USB dagi har qanday ilova (Mahalla, Ijara, Toza Hudud, Avto-park, boshqalar)
- Request / Response / Header tablar — formatlangan JSON
- Copy · Share (rangli JSON rasm, Telegram va h.k.)

Backend: `http://127.0.0.1:8787` (`~/Projects/online-mahalla` monitor).

## Test

```bash
swift test
```
