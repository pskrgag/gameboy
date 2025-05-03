## Yet another gameboy classic emulator

in yet another C killer. Not very timing-accurate, but still passes timings
tests.

### Supported

- [x] CPU
- [x] GPU
- [x] Keypad
- [x] MBC1
- [x] MBC0 (w/o ram)


### Not supported

- [ ] Sound (sorry I use linux, there is no sound)
- [ ] Other MBC types
- [ ] Saves to ROM
- [ ] HW bugs

### Following games known to work

- [x] Tetris
- [x] Mario

### How to run

```bash
zig build run -- <path to rom>
```

(I am not sure it will download dependencies, but project depends on [SDL2 wrapper](https://github.com/ikskuh/SDL.zig.git]))
