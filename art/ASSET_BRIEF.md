# SafeFuel pet redesign: asset brief

Drop finished files in `art/incoming/` using the file names below. Claude handles
background removal, rigging, compression and wiring into the app.

## Rules for every asset

- **Style:** match `marketing/mascot/master.png` (grainy, hand-textured, soft flat colour).
  Attach it as the reference image on every generation.
- **Stills:** PNG, 2048x2048, transparent background if you can. If not, plain flat
  background is fine. Character centred, feet on the same line, same size as master.png
  in every pose. (If the size drifts between poses, the pet "jumps" when it switches.)
- **Animations:** MP4 or MOV, square (1080x1080 or bigger), 3-6 seconds.
  - Background: **solid magenta #FF00FF**. Not green: the avocado is green and would get cut out.
  - Camera locked: no zoom, no pan, no cuts.
  - Loops (marked LOOP) must end in the same pose they start in.
  - No shadow on the background. Claude adds the shadow.
- **No text** in any image.

## Tier 1: needed for the new look

### Pip poses (stills)
| File | What |
|---|---|
| pip_idle.png | standing relaxed, small smile, arms down |
| pip_happy.png | big smile, eyes squinted shut with joy |
| pip_wave.png | one arm up waving hello |
| pip_point.png | pointing to the side (for onboarding tips) |
| pip_think.png | head tilted, hand on chin, curious |
| pip_eat.png | holding a fork with food, chewing |
| pip_drink.png | sipping a glass of water |
| pip_sleepy.png | eyes half closed, yawning |
| pip_bloated.png | holding tummy, a bit uncomfortable (gentle and cute, nothing gross) |
| pip_proud.png | hands on hips, chest out |
| pip_cheer.png | both arms up, jumping |
| pip_hug.png | arms open wide for a hug |

### Pip animations (magenta background)
| File | What |
|---|---|
| anim_idle.mp4 | LOOP: breathing, blinks twice, small sway |
| anim_wave.mp4 | waves hello, back to idle |
| anim_celebrate.mp4 | jumps with arms up, lands, back to idle |
| anim_eat.mp4 | takes a bite from a fork, chews happily |
| anim_drink.mp4 | drinks water, "ahh", back to idle |
| anim_walk.mp4 | LOOP: walking in place, side view facing right |
| anim_sleep.mp4 | LOOP: sitting asleep, slow breathing |
| anim_tummy.mp4 | rubs tummy, wobbly face, then a relieved smile |

(The four existing animations are only 480x480, so all of them get redone in HD.)

### Onboarding: "plant your pit" (the Finch egg hatch, food version)
| File | What |
|---|---|
| pot_1.png ... pot_6.png | 6 small flower pots with soil, front view, different colours and patterns (terracotta, sage, butter yellow, blush pink, sky blue, cream with dots) |
| pit_in_soil.png | an avocado pit sitting in soil (no pot, so it can go in any pot) |
| pit_crack.png | same pit with a crack and a tiny green sprout |
| anim_hatch.mp4 | pit wiggles, cracks open, baby Pip pops out and waves (magenta background) |

### Backgrounds (portrait 1290x2796, no characters)
| File | What |
|---|---|
| bg_home_day.png | cozy kitchen windowsill garden: herbs in pots, window with soft sky, wooden counter. Keep the bottom-middle third fairly empty (Pip stands there) |
| bg_home_night.png | the same scene at night, warm lamp light, stars through the window |
| bg_onboarding.png | soft sunny garden or field, very simple and calm, lots of empty sky for text |
| anim_bg_home_day.mp4 | OPTIONAL: bg_home_day with herbs gently swaying and steam from a mug. LOOP, no character, background not magenta |

### UI animations (free from lottiefiles.com, download as Lottie JSON)
Recolour to greens, cream and warm brown before downloading.
| File | What |
|---|---|
| lottie_confetti.json | confetti burst (meal logged, goal hit) |
| lottie_check.json | check mark pop |
| lottie_sparkle.json | small sparkle or twinkle |
| lottie_coin.json | coin or seed pop (earning currency) |
| lottie_loading.json | small cute loading animation |

### App icon
| File | What |
|---|---|
| icon_1024.png | 1024x1024, Pip's face close up on a soft solid background, NO transparency, no text |

## Tier 2: the Finch / Focus Friend game layer (after Tier 1 ships)

### Currency and energy icons (512x512 transparent)
- icon_seed.png: the currency (a shiny golden seed)
- icon_fuel.png: Pip's energy (a little leaf or lightning drop)
- icon_streak.png: streak flame, but as a sprouting plant

### Outfits (512x512 transparent, item alone, front view, no character)
hat_chef.png, hat_sun.png, hat_beanie.png, hat_bow.png, hat_crown.png,
glasses_sun.png, glasses_round.png, scarf.png, apron.png, headband_pink.png

### Kitchen decor (Focus Friend-style room, 512x512 transparent, item alone)
decor_plant_big.png, decor_rug.png, decor_lamp.png, decor_shelf.png,
decor_fridge.png, decor_fruit_bowl.png, decor_teapot.png, decor_wall_art.png,
decor_fairy_lights.png, decor_cat_bed.png

### Adventure postcards (1080x1350, Pip in the scene, illustrated)
Pip comes back from a trip with one of these when its energy is full.
post_farmers_market.png, post_beach_picnic.png, post_orchard.png,
post_bakery.png, post_mountain_hike.png, post_night_market.png
