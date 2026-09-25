# BOB

A virtual pet game made in Godot 4.7, built phone-first. Bob is a stick figure
in an empty white room, drawn in a sketchy black-and-white style, and
everything in the room is physics.

- **Drop toys**: drag one from the tray into the room, or tap it to drop it
  from above. Ball, beach ball, crate, rubber duck, balloon (floats "up"),
  anvil, and snacks, which Bob eats.
- **Tilt your phone** and gravity follows it. Bob stands up against whichever
  way is down, so he'll end up walking on the walls.
- **Shake your phone** to throw everything around. Bob goes limp, flails,
  and gets back up.
- **Grab anything** with your finger, Bob included, and fling it.
- **Talk** to him from the chat bar. He knows greetings and jokes, and will
  "dance", "jump", "wave", "come here" or take a "nap" when asked.

He has three needs: Food (drop snacks), Fun (toys, being flung around)
and Energy (he naps on the floor when he runs out). He saves every 10
seconds, and his needs drain slowly while the game is closed.

On desktop: arrow keys tilt the room, Space shakes it.

## Files

- `scripts/bob.gd`: Bob's physics body, behaviour, pose, speech bubble and voice
- `scripts/bob_talk.gd`: everything Bob says
- `scripts/toy.gd`: the toys' physics
- `scripts/sketch.gd`: the wobbly pencil lines and all toy drawings
- `scripts/room.gd`: the walls, sized to the screen above the toy tray
- `scripts/motion.gd`: phone tilt → gravity, phone shakes → impulses
- `scripts/main.gd`: dropping toys, grabbing and flinging
- `scripts/hud.gd`: needs meters, toy tray, chat bar
- `scripts/pet_state.gd`: needs and saving
- `tools/autopilot.gd`: scripted scene for recording the arcade attract video

## Phone sensors on the web

Browsers only give motion data to web pages, so the web export's
`html/head_include` (in `export_presets.cfg`) adds a small script. It
listens for `deviceorientation` / `devicemotion` into `window.bobMotion`,
and on iOS asks for motion permission on the first tap. `motion.gd` reads
that through `JavaScriptBridge`. When the game runs inside another page's
iframe, the iframe needs `allow="accelerometer; gyroscope"`.

## Web build

`build/` holds the web export served by GitHub Pages at
https://sclondon.github.io/BOB/build/index.html. Re-export with:

    godot --headless --path . --export-release "Web" build/index.html

Attract video (16:9):

    godot --path . --resolution 1280x720 --write-movie attract.avi --fixed-fps 30 --quit-after 540 -- --autopilot
