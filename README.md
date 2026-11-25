an apple tv remote that lives in your mac's notch.

nothing to download yet, i'm still building it. a first version runs if you build it yourself. the idea:

- the notch sits there quietly while the tv is idle
- hover over it, or hit ⌥T, and it opens into a remote: arrows, back, home, play/pause, volume, and what's playing
- when the tv asks for text (a search box, a password) the notch pulses, and you just type on your mac keyboard instead of hunting letters with a remote
- arrow keys, return and esc do what you'd expect

everything that talks to the apple tv lives in [perch-core](https://github.com/kaanf/perch-core), which is where most of the work has gone so far. this repo is where the app goes.

## building

```sh
./build.sh
open build/Perch.app
```

it expects [NotchKit](https://github.com/kaanf/notch-kit) and perch-core checked out next to this folder. the first time it opens it lists the apple tvs on your network; pick one and type the pin it shows. after that it reconnects on its own. ⌥T opens and closes the remote from anywhere.

no apple tv at hand? a debug build can fake one:

```sh
CONFIGURATION=debug ./build.sh
open build/Perch.app --args --mock-tv playing --open
```

the scenarios are `unpaired`, `pairing`, `connecting`, `idle`, `playing`, `keyboard`, `failed` and `network-denied`, and the notch's right-click menu switches between them.

## license

mit
