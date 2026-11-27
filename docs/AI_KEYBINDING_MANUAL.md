# Barsmith AI Action-Bar & Keybinding Design Manual
## World of Warcraft: Forever

**Purpose:** This document instructs an AI assistant how to design, revise, and safely deploy a player's World of Warcraft: Forever action bars and keybindings using a BP2/BC1-capable version of Barsmith.

This procedure is intended for all classes and specializations, including:

- healing, tanking, ranged, melee, and hybrid play
- Druid forms
- Warrior stances
- Rogue Stealth
- Priest Shadowform and multi-role Priest setups
- Hunter pets and pet controls
- Warlock pets
- Shaman totems
- Paladin seals, auras, and utility
- leveling characters with important future abilities not yet learned
- characters using macros, mouseover healing, click-casting, gaming mice, addons, or unusual movement schemes

The human should not need to understand Barsmith's internal formats. The AI carries the technical and analytical burden. The human primarily supplies physical comfort information, preferences, intended playstyle, and approval or rejection of proposed layouts.

---

# 1. Fundamental Operating Principle

Treat the system as three complementary safety layers:

**Export setup = the Barsmith-managed setup.**

It describes supported action-bar contents, macros used on those bars, and Barsmith-managed bindings.

**Binding Census = the surrounding WoW binding environment.**

It describes the broader binding registry exposed by WoW, including ordinary bindings, secondary bindings, addon bindings, custom controls, unbound commands, and detectable runtime overrides.

**Check = final live verification.**

It examines the proposed plan against the current live game state immediately before anything is changed.

These three sources are not interchangeable.

## Absolute rules

**Never assume a key is free merely because it is absent from Export setup. Consult the Binding Census.**

**Never recommend Apply without a fresh successful Check against the exact current plan and current live state.**

**Never perform a blanket removal of secondary bindings.**

**Never replace preservation-safe BP2 behavior with BP1-style exact binding replacement unless the user explicitly requires legacy behavior.**

**Never assume that the Binding Census can enumerate every possible dynamically created runtime override. Check is the final authority for keys touched by the plan.**

---

# 2. Required Barsmith Capability

Use a Barsmith build that supports:

- BP2 plans
- Export setup
- BC1 Binding Census
- Check before Apply
- Check invalidation after plan editing
- live-state revalidation during Apply
- Summary, Details, and Full diagnostics reporting

If the installed Barsmith version lacks Binding Census or allows an unchecked plan to be applied, stop. Do not proceed under the safety model in this document.

The public or historical BP1-only version of Barsmith is not sufficient for this workflow.

---

# 3. BP2, BC1, and Barsmith Concepts

## BP2

BP2 is the preservation-safe executable plan format.

Important binding instructions include:

`ENSURE key command`

Give the specified key to the specified command. Preserve unrelated keys already belonging to that command.

`REMOVE key expected-command`

Remove only that exact key/command relationship. If the key unexpectedly belongs to something else, the operation must not silently remove it.

`ALLOWORPHAN command`

Acknowledges an intentional situation in which a command may end with no key. Do not add ALLOWORPHAN merely to make warnings disappear. Use it only when leaving that command unbound is genuinely intentional.

A reassignment can itself displace the previous owner of a key. Check reports this.

Example conceptually:

- CTRL-C currently opens Character
- the new plan assigns CTRL-C to another command

Check should expose that displacement before Apply.

A deliberate displacement may be acceptable. An unexpected displacement is not.

## BP1

BP1 is the legacy plan format.

Its binding records describe an exact set of keys for each managed command. That means omitted keys can be removed.

For redesign work, prefer converting an imported BP1 plan to preservation-safe BP2 before editing it.

Do not generate new BP1 plans for ordinary work.

## BC1 Binding Census

BC1 is read-only.

It is not a set of instructions and must never be treated as one.

A census includes commands and their currently exposed keys, including secondary keys and many addon/custom commands. It can also report detectable runtime overrides.

The census may include controls that Barsmith intentionally cannot edit. Their presence is still important because they affect whether a key should be considered available.

## Spell representation

Barsmith is deliberately **name-first**.

Preserve readable spell names in plans.

Do not convert an entire plan into spell IDs.

Spell IDs may be used internally or as a fallback where a readable spell name cannot reliably represent the exact action. Existing Barsmith spell resolution handles unusual learned abilities, including abilities that normal spellbook enumeration may miss.

---

# 4. What the AI Is Responsible For

The AI should perform the following work:

1. reconstruct the player's current action bars and binding environment
2. identify genuinely occupied, apparently available, and uncertain keys
3. research the current World of Warcraft: Forever version of the class/spec when necessary
4. determine the practical importance of each ability
5. determine the ergonomic characteristics of candidate keys
6. account for movement, targeting, pets, forms, stances, macros, and special mechanics
7. identify valuable existing muscle memory
8. design a coherent proposed layout
9. explain only the meaningful changes to the player
10. generate a valid BP2 plan
11. require Barsmith Check
12. interpret the Check result
13. revise the plan when necessary
14. permit Apply only after a successful Check whose meaningful results have been reviewed

The AI should not dump technical analysis onto the human merely to demonstrate that it performed it.

Do the complicated work internally. Present the human with the decisions that require human judgment.

---

# 5. What the Human Is Responsible For

The human is the authority on:

- physical comfort
- pain or limitations
- hand size and mobility
- which keys feel easy or difficult
- which modifiers feel natural
- whether mouse buttons are comfortable
- existing bindings that feel deeply ingrained
- preferred targeting method
- desired playstyle
- tolerance for relearning
- approval or rejection of the proposed result

A generic guide never overrides the player's actual hand.

If a guide says a key is excellent and the player says it hurts, the key is bad for that player.

## Preference Authority Is Not Layout Authority

Distinguish **physical/ergonomic evidence** from **hotbar-design opinions**.

The player is authoritative about what feels comfortable, painful, reliable, confusing, or deeply practiced. The player is not automatically authoritative about which ability deserves a premium key, how the class should scale into later levels, or how the bars should be architected.

Treat prior binding preferences as strong evidence only when they reflect:

- real physical comfort or discomfort
- substantial demonstrated muscle memory
- a stable targeting or control method
- a deliberate playstyle requirement

For a new or inexperienced player, an earlier statement such as "I like this spell on X" may be only a provisional choice made without enough class knowledge to understand future competition for that key. Do not elevate such choices into protected requirements merely because they appeared in prior conversation.

Recent or lightly practiced placements should usually be treated as flexible. Preserve the player's body and genuine habits; do not preserve accidental early-game architecture.

---

# 6. Ergonomic Baseline: Use Gaming Hand Position, Not Touch Typing

**Do not evaluate gaming key reach from touch-typing home-row position.**

The relevant resting position is the player's actual movement position.

For a conventional WASD player, a reasonable initial physical model is:

- ring finger near A
- middle finger near W/S
- index finger near D
- pinky available around Shift/Ctrl
- thumb available around Space and often Alt

This is only a starting model. The player's actual technique overrides it.

For an ESDF player, left-handed player, keypad user, controller user, or someone with another movement cluster, reconstruct the geometry from that position instead.

The question is not:

> How far is this key from the typist's home row?

The question is:

> How easily and reliably can this player activate this key while performing the movement and targeting actions that occur at the same time?

This distinction is essential.

---

# 7. Ergonomic Evidence

Use general ergonomics only to establish broad physical principles.

Relevant principles include:

- repeated actions should avoid unnecessary reach
- awkward wrist deviation increases physical cost
- frequently repeated controls should remain accessible
- input devices and keys should be arranged around the actual task being performed
- neutral wrist posture is preferable to repeated twisting or extreme reach

OSHA's workstation guidance supports these general reach, repetition, and wrist-posture principles. It is not a gaming key-ranking guide and must not be interpreted as one.

For WoW-specific practical guidance, experienced keybinding guides commonly place high-frequency and reaction-sensitive abilities near the movement cluster. Wowhead, for example, identifies Q/E/R/F and 1–4 as typical high-value WASD-adjacent keys while emphasizing that exact assignments must make sense for the individual player. It also recommends retaining semantic consistency across characters.

These are defaults, not laws.

---

# 8. Use the WASD Baseline, Then Adapt It

For a conventional left-hand WASD player with no contrary ergonomic evidence, use the [Conventional WASD Keybinding Baseline](WASD_KEYBIND_BASELINE.md) as the default starting model.

The baseline defines **Tier 1 through Tier 5** keybind real estate and default ability-to-tier targets. Use that vocabulary directly when useful.

Do not start from an ergonomically blank slate. Nearby bare keys and reliable easy inputs are presumptively more valuable than distant or awkward chords, and Tier 1-2 real estate should normally be preserved for frequent or reaction-critical combat actions.

The tier list is a baseline, not a law. Player-reported physical comfort, pain, movement technique, modifier reliability, mouse usage, and genuine established muscle memory can promote or demote keys.

Do not treat a novice or lightly practiced spell/key preference as equivalent to ergonomic evidence.

Within and across tiers, key quality still depends on what the player is doing when the key must be pressed.

Evaluate candidate keys across several dimensions.

## Reach

How much movement does the hand or finger require from the normal gaming position?

## Repetition comfort

Could the player press this hundreds of times in a play session without fatigue or annoyance?

A key that is easy once may still be poor for a spammed rotational ability.

## Movement interference

Which movement finger must leave its movement key?

Examples for a conventional WASD posture:

- Q may compete with A/left strafe
- E/R/F may compete with D/right strafe
- number-row keys may require upward movement
- Shift usually occupies the pinky
- Ctrl can require an awkward curl for some players
- Alt is often accessible to the thumb for some players and terrible for others

Do not assume these conflicts are equally important to every player.

## Modifier comfort

Evaluate Shift, Ctrl, and Alt independently.

Also distinguish:

- Shift + letter
- Shift + number
- Ctrl + letter
- Ctrl + number
- Alt + letter
- Alt + number

A player can find Ctrl+F comfortable while finding Ctrl+3 miserable.

## Chord reliability

A key combination can be physically reachable but unreliable under pressure.

## Accidental activation risk

Some actions are expensive to press by mistake:

- long cooldowns
- combat potions
- limited consumables
- abilities with severe positioning consequences
- dangerous pet commands
- target-dropping or mode-changing actions

A key can therefore be **too easy to hit accidentally** for a particular ability.

## External conflicts

BC1 describes WoW's exposed binding environment.

It does not guarantee knowledge of:

- Discord push-to-talk
- mouse-driver bindings
- keyboard firmware
- operating-system shortcuts
- Steam or other overlays
- external accessibility software

If a proposed key is commonly used outside WoW or the player reports an external binding, account for it.

Avoid obviously dangerous operating-system combinations such as Alt+F4.

---

# 9. Ability Priority Is Multidimensional

Do not rank abilities solely by frequency.

Evaluate each relevant ability using the following characteristics.

## Frequency

How often is it pressed?

High-frequency rotational/filler abilities strongly favor repeatable, low-fatigue keys.

## Reaction urgency

How quickly must it sometimes be pressed?

Examples:

- interrupt
- taunt
- emergency heal
- panic defensive
- instant crowd control
- pet Follow when the pet is about to do something disastrous

A rarely used ability can deserve an excellent key if hesitation is costly.

## Consequence of failure

What happens if the player cannot find the key immediately?

Missing a cosmetic toggle is irrelevant.

Missing an interrupt, defensive, taunt, dispel, or emergency pet command can wipe a group.

## Movement concurrency

Does the player commonly need this ability while moving?

Instant casts, mobility tools, interrupts, melee abilities, tanking controls, and pet commands frequently fall into this category.

## Rotational importance

Is the ability central to normal damage, healing, tanking, threat, resource generation, or resource spending?

## Targeting complexity

Does the ability require:

- current hostile target
- friendly target
- mouseover
- focus
- self
- ground placement
- pet target
- party member
- target-of-target

A targeting-intensive action may benefit from an especially simple activation key.

## Accidental-use consequence

Emergency abilities can simultaneously have:

- high urgency
- high cost when pressed accidentally

That often calls for a **fast but protected** binding, such as a very reliable modifier chord rather than an awkward reach.

## Cooldown

Cooldown is useful context but is not itself a priority score.

A 10-minute emergency ability may deserve a much better key than a 30-second low-value utility.

## State or form dependence

Ask whether the ability is available only:

- in Cat Form
- in Bear Form
- in a Warrior stance
- from Stealth
- in Shadowform
- with a particular pet
- while a proc is active

## Future importance

For a leveling character, consider abilities the player will definitely or very likely obtain soon.

Reserve useful space for important future core abilities.

Do not reserve premium keys indefinitely for speculative abilities from talent builds the player may never take.

---

# 10. Match Ability Demands to Key Properties

Do not produce two linear rankings and mechanically pair them.

Instead ask:

> What physical properties does this ability need from its key?

Examples:

### Frequent filler or builder

Needs:

- excellent repetition comfort
- short reach
- little movement disruption

Accidental activation is usually less important.

### Interrupt or immediate control

Needs:

- very low reaction time
- high reliability
- good access while moving

Frequency may be only moderate.

### Emergency defensive

Needs:

- rapid access
- reliable activation
- protection against accidental use

This may justify a premium modifier chord.

### Taunt

Needs:

- extremely reliable access
- strong movement compatibility
- easy location under stress

### Long-duration buff

Needs:

- memorability
- little urgency

It can live farther from the movement cluster.

### Resurrection or other out-of-combat utility

Usually:

- very low urgency
- very low frequency

An awkward key or clickable bar slot may be completely acceptable.

### Potion or Healthstone

Often:

- emergency importance
- low/moderate frequency
- significant accidental-use cost

Give it a reliable key that is unlikely to be fat-fingered.

The best binding is therefore a **fit** between an ability profile and a key profile, not a numerical popularity contest.

---

# 11. Researching the Class and Spec

World of Warcraft: Forever differs materially from old Classic and is actively receiving class changes.

Do not assume a Vanilla/Classic, Season of Discovery, Retail, or private-server guide describes Forever correctly.

Use this hierarchy.

## First: current live evidence

If the player's Export setup, spellbook, tooltip, talent tree, or actual in-game behavior supplies current information, treat it seriously.

## Second: Blizzard's current WoW: Forever class material

Blizzard has published Forever class deep dives covering Hunter/Druid, Priest/Warrior, Mage/Shaman, Rogue/Warlock, and Paladin. These describe Forever-specific baseline abilities, talents, pets, forms, roles, and mechanical changes.

## Third: current WoW: Forever hotfixes

Check current hotfixes when a mechanical distinction affects a binding decision.

This is important. Forever hotfixes have already changed or corrected behavior relevant to keybinding decisions, including whether abilities can be used while moving, pet behavior, cooldown behavior, Shadowform interactions, and class mechanics.

## Fourth: current Forever client-data resources

ForeverDB is useful for:

- ability lists
- levels learned
- cooldowns
- forms
- current client data
- talent information
- rotations and practical priority suggestions
- changes between client builds

Its class pages explicitly track current Forever builds and update rotation/ability information as the client changes.

## Fifth: specialist guides and community knowledge

Use them to understand:

- practical rotations
- unusual use cases
- PvP priorities
- raid/dungeon habits
- common macro strategies

Cross-check important claims against current Forever mechanics.

Do not treat guide popularity as proof that a particular key belongs to a particular ability.

---

# 12. Frequency Evidence Is Not the Same as Importance

A rotation guide or simulator can reveal that an ability is pressed constantly.

That makes it useful ergonomic evidence.

It does **not** prove that the ability deserves the single easiest emergency key.

Likewise, logs or simulation may show that an emergency ability contributes little numerical damage or healing while still being strategically essential.

Separate:

- throughput importance
- reaction importance
- survival importance
- control importance
- frequency

Do not collapse them into one metric.

---

# 13. Muscle Memory Policy

Existing muscle memory creates a **migration cost**, not an absolute veto.

For every existing binding, ask:

1. Is the current key already good for this ability?
2. How frequently is the player likely to have practiced it?
3. Does changing it create a meaningful ergonomic or organizational gain?
4. Does moving it enable a much more important ability to use the old key?
5. Will cross-character or cross-form consistency improve enough to justify relearning?

Use a preservation bias.

If a highly practiced ability is already on an excellent key, do not move it for a tiny theoretical improvement.

If an emergency tool is stranded on a terrible key while prime space is occupied by trivial or rarely used functionality, optimization may justify the change.

A useful internal classification is:

**Protected:** move only with explicit reason and player approval.

**Preservation-preferred:** keep unless there is substantial benefit.

**Flexible:** move when it improves overall coherence.

**Disposable:** little or no muscle-memory value.

The AI does not need to show these labels unless they help explain the proposed changes.

---

# 14. Semantic Consistency Across Characters and States

Consistency has real value.

Where practical, give similar **jobs** similar physical locations.

Examples:

- interrupt
- taunt
- primary defensive
- emergency heal
- movement ability
- hard crowd control
- dispel
- major offensive cooldown
- pet emergency control

Do not rigidly force identical keys when class mechanics make that inferior.

The objective is cognitive consistency, not symmetry for its own sake.

A player logging onto a second character should ideally think:

> My panic defensive lives here.

rather than:

> What spell name did I put on this key on this character?

WoW keybinding guidance similarly recommends maintaining consistent functions across characters where practical.

## Multiple Characters and Binding Scope

Barsmith layouts can be character-specific, but WoW's underlying keybinding set may be **account-wide** or **character-specific**. The Binding Census records the active binding context, and Check/Apply operate on that active set. Never assume a binding change is isolated to the current character merely because the action-bar contents are character-specific.

In the addon's profile manager, confirm the displayed character and active layout before Check. Read the profile’s Managed bars settings alongside the export and census. Each excluded independent bar protects its physical slots and every key on its standard button commands, including keys that an assignment elsewhere would displace. For example, Bar 2 occupies slots 61–72 and owns MULTIACTIONBAR1BUTTON1 through MULTIACTIONBAR1BUTTON12. Check’s Details identifies skipped instructions. Keep intentionally reserved keys out of the generated plan. Selecting a profile loads its saved plan for review. Apply approves the reviewed batch in the current WoW binding set. A character may have separate leveling and healing profiles with different future-slot overwrite preferences.

For a player setting up multiple characters, prefer a layered model:

1. Establish a clean **account-wide baseline** first. It should contain universal controls the player wants everywhere and a reusable physical **key -> action-button command** geometry for a reasonable number of useful bar positions.
2. Keep the baseline class-agnostic. Do not put class-specific spells, Druid forms, Warrior stances, Hunter/Warlock pet controls, healer-only controls, or one-character macros into the generic account layer merely because they are available.
3. Do not bind every possible action-bar slot account-wide just because it exists. Standardize useful physical locations, not the entire binding namespace.
4. Before class-specific optimization, enable **character-specific bindings** for that character. WoW copies the current account bindings into the character binding set when character-specific bindings are selected.
5. After switching binding scope, obtain a **fresh Export setup and fresh Binding Census** from that character. The pre-switch census is no longer sufficient as the design authority.
6. Customize that inherited character profile for the class/spec. Once character-specific bindings are active, class-specific deviations can be made without intentionally rewriting the account-wide baseline.
7. Treat the resulting character binding profile as a fork of the baseline. Later account-wide changes must not be assumed to propagate automatically into an existing character-specific profile.
8. Give every additional character its own Export setup + Binding Census and its own design pass. Other characters may provide ergonomic and muscle-memory references, but they are never binding-state authority for the current character.

The important distinction is between **binding geometry** and **ability placement**.

For example, an account baseline might establish:

`Q -> ACTIONBUTTON6`

A Druid can then place Rejuvenation in that character's corresponding slot while a Priest places Power Word: Shield there. The physical vocabulary remains consistent without forcing the two classes to use the same spells or even the same semantic role when their mechanics justify something different.

If a particular character needs a different physical key-to-command mapping, make that deviation only after character-specific bindings are active and the current scope has been verified through the Census/Check workflow.

Pet classes do not require a separate account baseline. A Hunter or Warlock can inherit the same generic baseline as every other character; add pet-specific bindings only in that character's design layer unless the player deliberately wants a pet command to be universal.

---

# 15. Forms, Stances, Stealth, and Other State-Specific Bars

Treat state-specific bars as an opportunity, not merely a complication.

A single physical key can perform a different action in:

- humanoid/caster form
- Cat Form
- Bear Form
- Warrior Battle/Defensive/Berserker Stance
- Rogue Stealth
- other supported paging states

Design each state for its actual role while seeking semantic consistency.

Example:

A key does not need to cast the same spell in every Druid form.

It is more useful if the key retains a related **purpose**, such as:

- mobility
- control
- defensive reaction
- primary spender
- threat tool

Do not sacrifice a materially better state-specific layout merely to create superficial symmetry.

Inspect the Export setup rather than guessing which slots/pages are actually used.

Bar 1 controls the shared ACTIONBUTTON keys across humanoid, Cat, Bear and other paged bars. Excluding one form page protects its slots. A shared key change on an enabled Bar 1 is felt across forms. Keep exported exact spell IDs when the client distinguishes form-specific actions. A physical page number alone cannot tell you which variant was placed there.

For a transforming ability, keep the exact `spell:ID` from Export setup when it identifies the intended physical action. The same ID can legitimately appear on two form pages. Keep different exported IDs when the character has separately learned variants. Preserve explicit ranks.

A fresh installation may recognize only the variant currently displayed. Barsmith learns verified relationships as the character visits each form or stance, including with Auto-fill off. Check the named plan, visit the relevant states, then Check again in the intended form. Each character learns its own relationships. A talent or client change can require another observation. If Check still reports ambiguity, use a verified export or leave that placement pending. A shared name stem or page label supplies insufficient evidence for choosing an ID.

Only explicit `SLOT` records authorize placement on a form page. If a bar addon needs a copy on a different physical page, establish its actual destination before adding that record. Check lists occupied destinations and future replacements. The profile can prompt once for a leveling batch or automatically replace occupied managed slots when its overwrite option is enabled.

---

# 16. Healers and Targeting Method

Before redesigning a healer, determine how the player actually heals.

Possible systems include:

- target ally, press keyboard heal
- mouseover macro
- Clique or another click-casting addon
- Blizzard click casting
- party-frame mouse buttons
- hybrid keyboard and mouseover usage

This can radically change binding priority.

A Priest who casts Flash Heal from the keyboard may need Flash Heal on extremely accessible real estate.

A Priest who reliably invokes common heals through mouseover click-casting may need keyboard space more urgently for:

- emergency defensives
- dispels
- crowd control
- damage
- target-based utility
- self-preservation

Do not assume BC1 exposes every click-casting relationship. Ask the human about healing/click-casting behavior if it matters to the design.

Do not duplicate every heal on both systems unless redundancy is intentional.

---

# 17. Hunter and Warlock Pets

Treat pet control as a first-class combat system.

For Hunters in Forever this is especially important because pets are a central part of the class and individual pet families have distinct abilities. Blizzard's Forever Hunter design gives pets broader shared abilities plus a family-specific ability, so the value of deliberate pet control can be substantial.

Evaluate separately:

- Pet Attack
- Follow
- Stay
- Passive/Defensive/Assist or equivalent behavior controls
- autocast abilities
- manually activated pet abilities
- family-specific abilities
- pet movement abilities
- emergency pet-management actions

Do not automatically bind every pet ability.

First determine which abilities are normally left on autocast and which require deliberate activation.

For a player who actively micros a pet:

**Pet Follow can be a reaction-critical key.**

Pet Attack may be pressed very frequently.

Passive or equivalent emergency recall behavior can prevent pulls, deaths, or unwanted combat and may deserve far better access than its raw frequency suggests.

When different pets expose different family abilities, preserve a stable semantic location where practical:

> "manual pet special" lives here

rather than rebuilding the pet-control muscle memory every time the pet family changes.

Apply the same reasoning to Warlock demons and any other controllable companion system.

---

# 18. Movement Abilities

Mobility abilities often deserve better keys than frequency alone suggests.

Consider:

- gap closers
- charges
- sprints
- leaps
- disengages
- movement-breaking abilities
- instant form changes used for mobility

They are frequently activated while another movement key is already being held.

For these abilities, movement interference deserves unusually high weight.

A key that is wonderful while standing still may be mediocre while strafing out of an encounter mechanic.

---

# 19. Interrupts, Taunts, Dispels, and Emergency Tools

These should usually receive a reaction-time premium.

Do not bury them simply because they have cooldowns.

For tanks, taunts and critical defensives can deserve the best real estate on the entire keyboard.

For healers, dispels and emergency heals may outrank ordinary throughput spells.

For DPS, interrupts, crowd control, threat drops, or survival tools may deserve better access than a moderately frequent but forgiving rotational action.

Always reason from failure consequence.

---

# 20. Future Abilities on Leveling Characters

The AI should design toward the character the player is becoming, not merely the character that exists at this exact level.

Research:

- future trainer abilities
- intended talents
- major milestone abilities
- form/stance abilities
- class mechanics unlocked later

Reserve good bindings for future abilities when:

- the ability is definitely or very likely to be learned
- its role is predictable
- it is important enough that inserting it later would otherwise disrupt established muscle memory

Do not reserve large amounts of prime space for speculative builds.

A reasonable leveling layout should be usable now while avoiding obvious future dead ends.

---

# 21. Multiple Specs

If the player intends to use multiple specs, optimize both the individual spec and the transition between them.

Shared functions should receive consistency bonuses.

Examples:

- the main defensive
- dispel
- interrupt
- emergency heal
- movement tool

Do not assume one spec's bar design is optimal for another.

When spec changes alter bar contents or paging, inspect or export the relevant state rather than guessing.

Separate Barsmith plans may be appropriate when the layouts materially differ.

---

# 22. Minimal Human Intake

Do not interrogate the player with a giant questionnaire.

Infer what you can from Export setup, Binding Census, and prior conversation.

Ask only missing questions that materially change the design.

A good minimum set is:

### Movement
What movement scheme do you use?

Examples: WASD, ESDF, unusual layout, controller.

### Hand comfort
Which nearby keys feel especially good or especially bad?

### Modifiers
How comfortable are Shift, Ctrl, and Alt?

If relevant, distinguish letters from numbers.

### Mouse
Which mouse buttons or wheel combinations are comfortable?

### Physical limitations
Are there fingers, reaches, motions, or chords you avoid because of pain, limited movement, hand size, or another physical reason?

### Existing muscle memory
Are there current bindings you strongly prefer not to change?

### Intended content
What matters most?

Examples:

- leveling
- solo play
- dungeons
- healing
- tanking
- raids
- PvP

### Conditional questions

Ask these only when relevant:

**Healer:** Do you heal through keyboard target casting, mouseover macros, click-casting, or some combination?

**Pet class:** How much manual pet control do you want?

**Multiple specs:** Which specs must this layout support?

If the player already supplied an answer, do not ask it again.

---

# 23. Reconstructing the Current State

When the user provides Export setup and Binding Census:

## Parse Export setup

Determine:

- class
- race
- current level if available
- action slots
- state-specific/form/stance slots
- macros
- action-bar bindings
- existing Barsmith binding instructions

Preserve the current export as the structural baseline.

This means preserve the real slot/page structure, macro definitions, and live state needed for safe reconstruction. It does **not** mean that an occupied managed slot is visually immovable. Existing spell placement has preservation value only when it represents useful muscle memory or another concrete design reason.

Do not invent a new SLOT or MACRO record syntax from memory. Use the actual current export or the current Barsmith specification as the template.

## Parse Binding Census

Build a binding map:

`key -> command`

and:

`command -> all exposed keys`

Include secondary bindings.

Also identify:

- addon commands
- custom controls
- currently unbound commands
- runtime overrides reported by BC1
- account/character binding context where available

## Classify keys

Internally sort candidate keys into:

**Occupied:** BC1 shows an owner.

**Candidate-free:** no persistent owner is shown by the census.

**Reserved by preference:** technically available but the player wants it left alone.

**Externally uncertain:** could conflict with non-WoW software or hardware.

**Unsuitable:** physically poor or dangerous.

Do not call a key definitively free before Check.

---

# 24. Preserve Existing Useful Controls

Existing WoW controls are not disposable merely because they are not combat abilities.

Examples may include:

- Autorun
- targeting
- camera or mouse-look controls
- interact
- bags
- nameplates
- sound controls
- addon commands
- push-to-talk
- action-page switching

Assess whether the player actually values them.

If a high-value combat key is currently occupied by a trivial menu function, moving that function may make sense.

If the key controls something the player relies on constantly, preserve it unless there is a strong reason.

Never silently orphan an existing command just because a combat ability would fit nicely there.

---

# 25. Layout Construction Procedure

Use this order.

## A. Protect fundamental controls

First identify:

- movement
- camera/mouselook
- jump
- targeting
- interact
- autorun
- push-to-talk
- important addon controls
- external controls the user has identified

## B. Place extremely high-frequency combat actions

Optimize for:

- low fatigue
- short travel
- minimal movement conflict

Treat premium unmodified keys as a scarce budget. Before giving one to a long-cooldown, consumable, or situational action, compare that use against present and likely future rotational, reaction-critical, movement-concurrent, and control abilities. "Important" by itself is not enough to justify prime real estate.

## C. Place reaction-critical actions

Examples:

- interrupt
- taunt
- emergency control
- pet recall
- emergency heal
- dispel when time-critical

Optimize for immediate reliable activation.

## D. Place survival tools

Prefer fast but low-fat-finger-risk keys.

## E. Place movement tools

Evaluate them while imagining the player actively holding movement keys.

## F. Place secondary rotational abilities and cooldowns

Use remaining comfortable keys and reliable modifiers.

## G. Place occasional utility

These can tolerate greater reach or less desirable modifiers.

## H. Place out-of-combat and extremely rare utility

These need not consume premium combat space.

A visible clickable slot may sometimes be superior to wasting a valuable key.

## I. Organize the Visible Bars

Action-slot placement and key assignment are one design problem.

Do not merely rebind whichever abilities happen to occupy existing slots. When managed slots are available, actively reorganize them so the visible bars reflect the control scheme.

Where practical:

- group related rotational actions together
- keep defensives, movement, control, consumables, and utility in recognizable families
- make visible button order correspond intelligibly to the physical key order
- reserve intentional gaps only when they serve future abilities or readability
- move an existing action when doing so materially improves coherence, unless real muscle memory argues otherwise

The final result should look deliberate even before the player presses a key. A visually arbitrary sequence of bound buttons is evidence that the slot layout itself still needs work.

---

# 26. Modifiers

Modifiers are capacity multipliers, not automatically inferior bindings.

Evaluate them according to the individual player.

Do not assume:

Shift > Ctrl > Alt

or any other universal order.

A player may find:

- Shift+letters excellent
- Ctrl+letters acceptable
- Ctrl+numbers awful
- Alt+numbers excellent

That is a perfectly valid ergonomic profile.

Modifier combinations can also be useful for **semantic families**.

Examples:

- base key = ordinary version
- Shift+same key = related emergency/strong version
- base key = normal target
- modifier = focus or self version

Use such patterns only if they remain intuitive to the player.

---

# 27. Mouse Buttons

Mouse buttons can reduce competition with the movement hand, which can make them excellent for:

- reaction abilities
- movement tools
- pet control
- targeting
- interrupts
- frequently used heals

But mouse ergonomics vary dramatically.

Do not assume an MMO mouse's twelve side buttons are all equally good.

Consider:

- thumb reach
- grip changes
- accidental activation
- repetitive load
- whether the player can distinguish neighboring buttons reliably

The player's reported experience outranks generic advice.

---

# 28. Designing Around Accidental Activation

Some abilities need excellent access but should not sit under a key the player routinely grazes.

Examples:

- 30-minute cooldown
- potion
- major raid cooldown
- suicidal mobility ability
- pet release/behavior control
- expensive consumable

A reliable modifier may be preferable to a bare key.

This is not because modifier keys are inherently worse.

It is because the modifier can act as a deliberate-action gate.

---

# 29. Do Not Optimize Past the Point of Human Usability

Avoid "spreadsheet optimization."

Do not move five established bindings because a theoretical model says the alternatives are microscopically better.

A good redesign should produce recognizable gains such as:

- important action moved dramatically closer
- emergency action becomes reliable
- movement interference is reduced
- related actions become consistent
- future ability gains a natural home
- previously hidden conflict is eliminated
- clutter is reduced

If the only justification is:

> this key scores 8.4 and that key scores 8.1

keep the established binding.

---

# 30. Presenting the Proposal

Before generating the final plan, show the player a concise proposed layout.

For each meaningful changed binding, explain:

- old use
- proposed use
- why the change is worthwhile
- whether anything else must move

Do not explain every unchanged slot.

Call out:

- major muscle-memory changes
- intentional displacement of existing WoW commands
- intentionally preserved bindings
- reserved future abilities
- pet-control decisions
- unusual modifier choices

Before presenting the proposal, perform a **visual coherence audit** of every managed bar the player will actually see. Check that ability families, button order, key labels, and reserved space form an understandable layout. If the visible sequence looks like historical accident rather than design, reorganize the slots before generating BP2.

The human approves the concept.

The AI handles the implementation.

---

# 31. Generating the BP2 Plan

Start from the player's current Export setup whenever possible.

Preserve everything that is not intentionally being changed.

For bindings:

## To add or assign a key

Use `ENSURE`.

Do not erase the command's unrelated existing secondary bindings.

## To deliberately release a key without assigning it elsewhere

Use `REMOVE key expected-command`.

Do not use REMOVE against an owner inferred from memory. Use the owner demonstrated by the current state.

## To move an existing command to a replacement key

Ensure the replacement binding explicitly.

Then either:

- assigning the old key to something else will displace the old relationship, or
- use REMOVE if the old key should become free

## To intentionally leave a command with no keys

Only do so deliberately.

Treat the orphan warning as meaningful.

Use ALLOWORPHAN only when leaving it unbound is truly intended.

## Spell records

Prefer readable names.

Do not transform the plan into an ID-first format.

## Macros

Preserve existing macro text unless intentionally changing it. An explicit macro edit affects every reference, including buttons on excluded bars. Read Check’s shared-use warnings before Apply. Preserve the selected question-mark icon (134400) for dynamic macros. Its displayed texture can change with form or target.

Do not "clean up" macros merely because they look unusual.

## Unmanaged bindings

Leave them unmanaged.

The absence of an instruction means Barsmith should not alter that relationship.

---

# 32. Never Use Blanket Binding Cleanup

This rule deserves repetition.

Do not issue operations whose purpose is effectively:

> remove every secondary binding

or:

> rebuild the whole WoW binding table from only the bindings I care about

The entire point of BP2 is preservation.

Modify only relationships deliberately included in the plan.

---

# 33. Before Check

Confirm that:

- the correct character is logged in
- the player is out of combat
- the current intended BP2 plan is pasted into Barsmith
- no later text edits have been made without rechecking
- the Binding Census used for design is reasonably current

If the user substantially changed addons, keybindings, spec setup, or controls after the census was captured, obtain a new census before continuing.

---

# 34. Check Is Mandatory

The user must press **Check**.

Do not recommend Apply yet.

Check is not ceremonial.

It is the point where the theoretical design meets the current game state.

A successful earlier Check does not authorize a changed plan.

Editing the plan invalidates that Check.

---

# 35. Reading Barsmith Reports

## Summary

Read this first.

Use it to determine whether the plan:

- passes
- has warnings
- contains changes
- encounters blockers

## Details

This is the normal report for review.

It should contain meaningful:

- changes
- warnings
- displacements
- skipped operations
- errors

This is normally what the AI should ask the user to provide after Check.

## Full diagnostics

Use this when:

- something is confusing
- a key owner appears unexpected
- a runtime override matters
- a slot appears wrong
- the user wants exhaustive verification
- a compatibility-copy issue must be diagnosed

Do not routinely make the human inspect every already-correct binding and slot.

---

# 36. Interpreting Check Results

## Expected reassignment

Example:

`Displacement: KEY from OLD_COMMAND to NEW_COMMAND`

If this is exactly what the layout intended, it is acceptable after review.

## Unexpected displacement

Stop.

Determine why the key had that owner and revise the plan if necessary.

Do not dismiss it because the desired new binding seems more important.

## Orphan warning

Determine whether the old command truly should become unbound.

If not, give it another appropriate key.

If yes, the warning can be accepted deliberately.

## Already-correct item

No problem.

It confirms that portion of the current plan already matches live state.

## Skipped slot

Investigate.

Possible causes include:

- ability not learned
- item unavailable
- incorrect action reference
- state/page issue

Do not assume skipped placement is harmless if that slot is supposed to be authoritative.

## Runtime override

Determine whether the override actually affects a proposed key or leaves the command without a usable fallback.

Harmless informational overrides need not derail the plan.

A masking override affecting the proposed design must be resolved.

## Blocking/error state

Do not Apply.

Revise or correct the live situation and Check again.

## Stale state

If the live binding graph changed after Check, recheck.

Apply itself performs live revalidation, but the goal is to understand changes before writing them, not to use Apply as an error detector.

---

# 37. Apply Rule

The AI may recommend **Apply** only when all of the following are true:

- the exact current plan has successfully passed Check
- the meaningful Details output has been reviewed
- every displacement is expected
- every orphan warning is understood and deliberate
- no blocker remains
- no unexplained runtime conflict affects the design
- the user has not edited the plan since Check

Then, and only then, Apply is appropriate.

---

# 38. After Apply

Verify the actual character.

Check:

- important keys
- form/stance pages
- macros
- pet controls if applicable
- movement
- emergency abilities
- any command intentionally moved
- addon bar compatibility where relevant

For a large redesign, test in a low-risk environment before relying on the new layout in difficult group content.

If a layout feels physically bad despite being theoretically excellent, change it.

Human experience is the final ergonomic test.

---

# 39. Iteration Protocol

When the player dislikes part of the layout:

Do not redesign everything automatically.

Identify the specific problem:

- reach
- movement conflict
- modifier discomfort
- confusion
- muscle-memory resistance
- accidental activation
- targeting problem
- pet-management problem

Then make the smallest coherent revision.

Generate the revised BP2.

Run a new Check.

Review again.

Apply only after that new Check succeeds.

---

# 40. Special Safety Invariants

The following must remain true throughout the process.

1. **No key is considered safely available solely because Export setup does not mention it.**

2. **BC1 must be consulted before redesigning bindings.**

3. **Unmanaged secondary bindings are preserved.**

4. **Only intentional key/command relationships are removed.**

5. **Unexpected owners block casual reassignment.**

6. **Player-reported physical comfort overrides generic key rankings.**

7. **Ergonomics are evaluated from the player's gaming movement position, not touch-typing home row.**

8. **Ability priority includes urgency and failure consequence, not merely cast frequency.**

9. **Premium unmodified keys are a scarce resource; low-frequency cooldowns and consumables must justify their opportunity cost against present and future competitors.**

10. **Existing muscle memory receives a preservation bias, but novice or lightly practiced layout preferences do not automatically become protected architecture.**

11. **Cross-form, cross-spec, and cross-character semantic consistency is valuable but never absolute.**

12. **Managed action-slot placement and keybinding assignment are designed together; occupied slots are not inherently immovable.**

13. **The final managed bars should pass a visual coherence audit before BP2 is generated.**

14. **Pet commands are combat abilities when pet management makes them combat-critical.**

15. **Click-casting and mouseover systems are considered when designing healer layouts.**

16. **Current Forever mechanics must be researched rather than assumed from older WoW versions.**

17. **Spell plans remain readable/name-first.**

18. **Fresh Check is mandatory after every plan edit.**

19. **Apply is never recommended after an unsuccessful or stale Check.**

20. **On multi-character accounts, confirm whether the active binding set is account-wide or character-specific before making class-specific binding changes.**

21. **After changing binding scope, obtain a fresh Export setup + Binding Census before redesigning or generating a plan.**

---

# 41. Recommended AI Workflow

When beginning a new character or redesign, follow this sequence:

### Phase 1: Acquire state

Obtain:

- current Export setup
- current Binding Census
- current binding scope when multiple characters are involved: account-wide or character-specific

If either Export setup or Binding Census is missing, do not finalize binding assignments.

For a new multi-character setup, establish the reusable account-wide baseline first, switch the character to character-specific bindings, and then obtain a **fresh** Export setup + Binding Census before doing that character's class-specific design.

### Phase 2: Understand the player

Establish:

- class/spec/level
- intended role/content
- movement scheme
- comfortable keys
- uncomfortable keys
- modifier preferences
- mouse-button availability
- physical limitations
- protected muscle-memory bindings

Ask conditional healer/pet/multi-spec questions only when needed.

### Phase 3: Research

Confirm current Forever:

- abilities
- talents
- future unlocks
- rotation or healing priorities
- emergency tools
- movement mechanics
- cooldowns
- pet mechanics
- current hotfixes relevant to the class

### Phase 4: Reconstruct

Map:

- action bars
- macros
- forms/stances/pages
- current keys
- secondary bindings
- addon commands
- custom commands
- detectable overrides
- candidate-free keys

### Phase 5: Classify abilities

Determine each ability's:

- frequency
- urgency
- failure consequence
- movement concurrency
- targeting requirements
- accidental-use cost
- state dependence
- future importance

### Phase 6: Classify keys

For a conventional left-hand WASD player, begin with the Tier 1-5 model in [Conventional WASD Keybinding Baseline](WASD_KEYBIND_BASELINE.md), then adjust it from actual player evidence.

Determine each key's:

- baseline tier
- physical reach
- repetition comfort
- movement conflict
- modifier cost
- chord reliability
- accidental activation risk
- current owner
- muscle-memory value
- external conflicts

### Phase 7: Design

Map ability requirements onto key properties **and managed slot positions together**.

Preserve useful existing bindings, not accidental slot occupancy.

Seek semantic consistency.

Reserve only justified future space.

Organize the visible bars into a coherent layout rather than leaving existing abilities fixed and only changing their keys.

Run a visual coherence audit before human review.

### Phase 8: Human review

Present the meaningful proposed layout and significant changes.

Obtain acceptance or revise.

### Phase 9: Generate BP2

Preserve untouched current state.

Use ENSURE and REMOVE narrowly.

Do not wipe unrelated bindings.

### Phase 10: Check

Require Barsmith Check.

Review Summary and Details.

Use Full diagnostics only where necessary.

### Phase 11: Revise if required

Any plan edit requires another Check.

### Phase 12: Apply

Only after the exact current plan has passed Check and all meaningful warnings are understood.

---

# 42. Preferred Communication Style for the Receiving AI

The human should not have to become the binding engineer.

Good:

> Q is currently Rejuvenation and is already an excellent high-frequency key, so I am keeping it. I want to move Barkskin onto Shift+V because it gives the emergency defensive fast access without putting a long cooldown under an easy accidental press. BC1 shows Shift+V is currently occupied, so I am not using it unless we deliberately relocate that command.

Bad:

> Q has an ergonomic score of 9.4 while Shift+V scores 8.9.

Good:

> Your pet Follow command needs a better key because you may need it instantly to prevent a bad pull.

Bad:

> Pet Follow is low frequency, so it belongs on Ctrl+8.

Good:

> Check found an owner on a key that the census did not reveal. We are not applying this version.

Bad:

> That's probably harmless. Apply and see what happens.

---

# 43. Resource Reference

For current game mechanics, search these sources in roughly this order:

**Blizzard World of Warcraft: Forever Class Deep Dives**

Use for class identity, new abilities, changed talents, pet mechanics, form/stance mechanics, and Forever-specific design. Blizzard's published set covers the Forever classes.

**Blizzard WoW: Forever Hotfixes**

Use to verify mechanics that may have changed since the class deep dives or launch. The hotfix record demonstrates that ability movement rules, pet behavior, cooldowns, and class interactions can change after release.

**ForeverDB**

Use for current-client ability data, learn levels, cooldowns, class pages, talents, spell details, and current rotation information. Treat simulations and guide priorities as evidence rather than unquestionable truth.

**Wowhead: How to Keybind in WoW**

Use as practical WoW-specific ergonomic guidance, particularly the principles of putting frequent/reaction-critical abilities near the movement cluster and using consistent semantic bindings between characters. Do not copy its exact key assignments as universal rules.

**OSHA Computer Workstation Ergonomics**

Use only for broad human-factors principles such as minimizing awkward wrist postures, excessive reach, and repetitive strain. Translate those principles into the player's actual gaming position rather than touch-typing posture.

---

# 44. Final Governing Principle

The objective is **not** to discover the mathematically perfect keyboard.

The objective is to build:

> the best coherent control system for this player, this character, this role, this physical hand, this existing muscle memory, and this current WoW binding environment.

Barsmith supplies state visibility, preservation, and execution safety.

External research supplies current game knowledge.

Ergonomic reasoning supplies the physical mapping.

The human supplies comfort and preference.

The AI integrates all four.

When those sources disagree, resolve the conflict according to what each source is actually authoritative about:

- the human is authoritative about their body and preferences
- the live game is authoritative about current state
- current Forever sources are authoritative about game mechanics
- Barsmith Check is authoritative about whether the proposed plan can safely be applied to the live binding state

Never substitute generic advice for any of those authorities.
