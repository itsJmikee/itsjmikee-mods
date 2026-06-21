# LiveReins Mods — R.E.P.O

Install these to join a **LiveReins host's** lobby and let their stream commands affect
your game (turn you into a monster, scale you, etc.). You only need these if you're
playing **with** a host — you don't run any app yourself.

## Requirements
- **R.E.P.O** (Steam)
- **BepInEx 5** — the mod loader
- **ScalerCore** (by Vippy, from Thunderstore) — needed for scaling effects

---

## Easiest install (auto) ✅
1. Download this repo — green **Code** button → **Download ZIP**, then unzip it.
2. **Close R.E.P.O.**
3. Run **`Update and Play.bat`**.
   It auto-installs BepInEx + ScalerCore (if you don't have them), downloads the latest
   mods, and launches the game. Run it again any time to get the host's newest update.

---

## Manual install
Put these two folders into your R.E.P.O `BepInEx\plugins\` folder:

```
<REPO>\BepInEx\plugins\LiveReinsMod\LiveReinsMod.dll
<REPO>\BepInEx\plugins\PlayableMonsters\PlayableMonsters.dll
```

`<REPO>` is your game folder, usually:
`C:\Program Files (x86)\Steam\steamapps\common\REPO`

You also need **BepInEx** + **ScalerCore** installed first. The easiest way to get those
is **Thunderstore Mod Manager** (install BepInEx + ScalerCore into a REPO profile with one
click each), then drop the two folders above into that profile's `BepInEx\plugins\`.

Launch R.E.P.O normally. To update later, re-download these two `.dll` files into the same
folders (or just use the bat).
