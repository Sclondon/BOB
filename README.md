# BOB

A virtual pet game made in Godot 4.7. Your pet is Bob, a stick figure who walks
around his room, talks to you and needs looking after.

- **Feed, Play, Shower, Sleep** keep his four needs (Food, Energy, Fun, Clean) up.
- **Type in the chat box** to talk to him. He knows greetings, jokes and
  compliments, and will "dance", "jump", "wave" or "come here" when asked.
- **Click Bob** to poke him, **drag him** to pick him up and throw him.

Bob is drawn entirely in code; there are no image assets. He saves every
10 seconds, and his needs keep draining (slowly) while the game is closed.

## Files

- `scripts/bob.gd`: drawing, animation, behaviour, speech bubble and voice
- `scripts/bob_talk.gd`: everything Bob says
- `scripts/pet_state.gd`: needs, decay rates, saving
- `scripts/room.gd`: the room
- `scripts/hud.gd`: bars, buttons and chat box
- `tools/autopilot.gd`: scripted scene for recording the arcade attract video

## Web build

`build/` holds the web export served by GitHub Pages at
https://sclondon.github.io/BOB/build/index.html. Re-export with:

    godot --headless --path . --export-release "Web" build/index.html

Attract video:

    godot --path . --write-movie attract.avi --fixed-fps 30 --quit-after 555 -- --autopilot
