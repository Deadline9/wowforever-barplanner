# Conventional WASD Keybinding Baseline

## Purpose and scope

This document provides the default ergonomic starting point for an AI designing World of Warcraft: Forever keybindings for a **conventional left-hand WASD player**.

It is intentionally opinionated. The main manual explains how to adapt to the individual player; this document exists so the AI does not begin from an empty ergonomic model.

Use these tiers when the player has not supplied stronger evidence.

Player-reported physical comfort, pain, hand limitations, reliable modifier habits, and genuine established muscle memory override this baseline. A speculative or lightly practiced preference such as "I like this spell on X" does not automatically override it.

The tiers are discussion shorthand:

- "Keep the core rotation in Tier 1-2."
- "Move consumables to Tier 4."
- "I do not want defensives below Tier 3."

They describe **default ergonomic value**, not immutable truth.

---

# 1. Bare-Key Baseline

Assume A/D are movement or strafe controls and therefore unavailable. If Q/E are also used for movement, they are unavailable rather than Tier 1 candidates.

## Tier 1 - Premium combat real estate

Typical candidates:

- `1`, `2`, `3`, `4`
- `R`, `F`
- `Q` and/or `E` only when not used for movement
- `C` for players who find it natural
- easiest side mouse buttons such as Mouse 4 / Mouse 5
- scroll-wheel directions when deliberately repurposed and reliable

Default targets:

- main rotational or filler actions pressed constantly
- core generator/spender actions
- highly frequent proc reactions
- interrupts
- frequently used crowd control
- reaction-critical abilities whose failure is costly
- movement abilities used often while already moving

Treat Tier 1 as scarce. A long cooldown, potion, resurrection, buff, or rare utility action should not occupy Tier 1 while a genuinely Tier 1-2 combat action is forced onto worse input.

## Tier 2 - Excellent combat real estate

Typical candidates:

- `~`
- `5`
- `T`, `G`, `V`
- `X`, `Z`
- `C` when it is less natural for the player
- additional comfortable mouse inputs
- the easiest modifier chords built from Tier 1 keys

Default targets:

- secondary rotational actions
- short rotational cooldowns
- important procs
- movement tools
- important control
- frequently needed dispels
- major defensives or offensive cooldowns when accidental activation is not a concern

Tier 1 and Tier 2 should contain most actions the player expects to press frequently or under pressure.

## Tier 3 - Good secondary combat real estate

Typical candidates:

- `6`
- `Y`, `H`, `B`
- less convenient nearby letters
- ordinary Shift/Ctrl/Alt chords that are comfortable for the player
- secondary mouse buttons that require more thumb travel

Default targets:

- major cooldowns
- lower-frequency crowd control
- situational defensives
- threat drops
- niche movement tools
- infrequent combat utility
- deliberate consumables

Tier 3 is still combat-capable, but the AI should have a reason before placing a high-frequency rotational action here while Tier 1-2 space remains available.

## Tier 4 - Deliberate or infrequent actions

Typical candidates:

- awkward or farther modifier chords
- distant-but-reliable nearby keys
- less comfortable mouse inputs
- keys that require meaningful hand repositioning

Default targets:

- long cooldowns
- combat potions and other consumables
- infrequently used utility
- niche crowd control
- emergency actions that must be available but are rarely pressed and benefit from deliberate activation
- resurrection or recovery tools when they might still matter in combat

## Tier 5 - Rare utility / clickable territory

Typical candidates:

- distant number-row keys
- awkward chords
- remote keyboard keys
- visible unbound buttons intended primarily for clicking

Default targets:

- out-of-combat resurrection
- buffs with long duration
- portals and travel utility
- professions
- toys
- extremely rare utility
- actions that do not justify scarce combat-key real estate

A visible clickable slot is acceptable here when keyboard access provides little practical value.

---

# 2. Modifier Rule of Thumb

Modifiers expand capacity; they are not automatically bad.

As a default:

- an **easy Shift chord** is often roughly one tier below the bare key and can remain excellent combat real estate
- **Ctrl** and **Alt** chords are usually Tier 2-4 depending on the player's hand and habits
- letter chords and number chords must be evaluated separately
- do not assume `Ctrl+3` is comparable to `Ctrl+F`
- do not force a player's preferred modifier order if their actual comfort says otherwise

If the player has no modifier history, prefer Shift for early expansion, then evaluate Ctrl and Alt through actual use.

The player's demonstrated comfort can promote or demote any chord.

---

# 3. Ability-to-Tier Baseline

| Ability type | Default target |
|---|---|
| Constant rotational/filler action | Tier 1 |
| Core generator, spender, or proc reaction | Tier 1-2 |
| Interrupt or extremely reaction-critical control | Tier 1-2 |
| Frequently used movement ability | Tier 1-2 |
| Short rotational cooldown | Tier 2 |
| Important CC, dispel, or threat control | Tier 2-3 |
| Major defensive | Tier 2-3 |
| Major offensive cooldown | Tier 2-3 |
| Long cooldown or infrequent situational action | Tier 3-4 |
| Combat potion / limited consumable | Tier 3-4 |
| Resurrection / recovery utility | Tier 4-5 |
| Buff, portal, profession, or very rare utility | Tier 5 or clickable |

These are starting targets, not automatic assignments. Reaction urgency, movement concurrency, accidental-use cost, targeting complexity, and class mechanics can move an ability up or down.

---

# 4. Premium-Key Preservation Rule

Before assigning a Tier 1 or Tier 2 bare key to a low-frequency action, explicitly ask:

1. Which present rotational or reaction-critical abilities compete for this key?
2. Which known future leveling abilities will compete for it?
3. Is the proposed action important because it is frequently or urgently pressed, or merely because its effect is powerful?
4. Would a reliable modifier provide equally useful access with lower opportunity cost?

Do not confuse **importance of effect** with **importance of access**.

A five-minute cooldown can be strategically powerful while still belonging below a filler, interrupt, proc reaction, or frequent movement tool.

---

# 5. Visual and Semantic Consistency

Tier selection does not replace bar organization.

When practical:

- put related rotational actions together
- group defensives, movement, control, consumables, and utility into recognizable regions
- make visible button order correspond intelligibly to key order
- keep semantically similar jobs in similar locations across forms, specs, and characters
- reserve prime visible slots for current or strongly expected future high-value actions

The bar should look deliberately designed rather than like historical placement with new labels attached.

---

# 6. Evidence and Calibration

This baseline reflects common high-level WoW guidance rather than one player's personal bar.

Two useful reference points:

- **Skill Capped, WoW PvP Keybindings Guide (2026):** places 1-4, R, F, C, an available Q/E, Mouse 4/5, and scroll-wheel inputs in its highest group; ~, 5, T, G, V immediately below; Z/X lower; and 6/Y/H/B as situational. It recommends the highest-value keys for rotation, frequent CC, and interrupts, and explicitly recommends organizing bars by functional groups.
  - https://www.skill-capped.com/wowarticles/general/keybindings-guide/

- **Wowhead, "How to Keybind in WoW - Raiding and Mythic+":** recommends Q/E/R/F and 1-4 for rotational and fast-reaction abilities, with T/G/Z/X/C/V/B/5/~ for less frequent actions, and commonly moves longer cooldowns and utility onto modifiers.
  - https://www.wowhead.com/guide/how-to-keybind-in-wow-raiding-and-mythic-5965

The sources disagree on some individual keys, especially within adjacent tiers. That is expected. Use the shared pattern as the baseline and let actual player ergonomics move the borders.
