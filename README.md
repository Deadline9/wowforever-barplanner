# Barsmith

Set up your WoW Forever action bars, macros and keybinds in the browser, then load them into the game with one string.

**[Open the Barsmith planner](https://deadline9.github.io/wowforever-barplanner/)** · **[Download the matching addon](https://deadline9.github.io/wowforever-barplanner/Barsmith.zip)**

This BP2 fork builds on [Barsmith by Ruben (rubensayshi)](https://github.com/rubensayshi/wowforever-barplanner).

- An in-game-looking screen: main bar with bars 2, 3 and 6–8 stacked on top, bars 4 and 5 on the right edge, stance bar and pet bar above.
- Pick a class and race (only the combos Forever allows), then drag spells from that class's Forever spellbook: trainer spells, active talents and racials, with spells new in Forever marked ★. A level slider greys out spells you won't have yet.
- Write macros, plan the main bar once per stance or form that swaps it (warrior stances, Cat and Bear Form, Stealth) and on its page 2 (Shift+2), and bind keys in keybind mode (hover a button, press a key).
- Keep as many plans per class as you like. They're saved in your browser; the plan string moves them anywhere else.
- Works with EllesmereUI, Bartender4, Dominos and ElvUI: they show the game's normal bar slots and pass its keybinds on to their own buttons. Those three number bars by action page, so Bar 2 here is their bar 6, Bar 3 is 5, Bar 4 is 3, Bar 5 is 4 and Bars 6–8 are 13–15 (Dominos: 12–14). Some of them also switch the main bar for Shadowform, Moonkin Form or Prowl where the game doesn't, so include explicit SLOT records for any of those alternate buttons you want the profile to manage.

## Designing bars and keybindings with an AI assistant

Give your assistant the [AI Action-Bar & Keybinding Design Manual](docs/AI_KEYBINDING_MANUAL.md) and two separate strings from `/barsmith`. **Export setup** (BP2) supplies your action slots, macros, and supported keybindings. **Census** (BC1) supplies a read-only binding snapshot so the assistant can check proposed keys for collisions. After reviewing the layout, paste the proposed BP2 plan into Barsmith and run **Check** before **Apply**.

## Getting it into the game

1. Open the [planner](https://deadline9.github.io/wowforever-barplanner/) and download [Barsmith.zip](https://deadline9.github.io/wowforever-barplanner/Barsmith.zip). Extract it into the active WoW Forever installation’s `Interface/AddOns` folder. Check that `Interface/AddOns/Barsmith/Barsmith.toc` exists, then restart the game or type `/reload`.
2. In `/barsmith`, **Export setup** copies the current supported slots, macros and bar-planner key assignments into a BP2 plan. Press Ctrl+C and **Load** it on the page. **Census** produces a separate BC1 snapshot. Copy it and **Load** it with that plan open. Both strings can be given to an external planner.
3. Edit bar buttons as usual. Under **Binding instructions and collision preview**, add or delete individual instructions, including secondary keys and commands from addons. Deleting an instruction leaves that relationship unmanaged. To release a key in game, add a **REMOVE** instruction naming its current owner.
4. Copy the plan, paste it into `/barsmith` out of combat, and press **Check**. Review **Summary** for changes and warnings. Open **Details** for individual changes, skipped slots and problems. Expand **Full diagnostics** within Details to include already-correct bindings and slots, preserved keys and informational overrides. **Copy report** selects Details for Ctrl+C, including full diagnostics when expanded. Apply unlocks after a successful Check and locks again as soon as the plan text changes. **Apply** revalidates the checked binding graph before touching any slots, macros or bindings.
5. To recover the exact plan Barsmith last successfully applied on the selected profile, click **Last applied plan**. It selects the stored string for Ctrl+C, including instructions that a live **Export setup** cannot reconstruct, such as clears and future spells. Loading it leaves your bars and bindings alone. To reapply it, run **Check**, review the report, then click **Apply**. The shortcut `/barsmith apply` loads the same stored plan and runs **Check** for you. Auto-fill still places learned spells into empty planned slots.


## Character profiles and leveling

Click the profile name beside **Profile:** to switch layouts. The menu lists the logged-in character’s layouts first and marks the active one. The header shows the character (for example, **Seren Grey**) separately from the selected layout (**Leveling**). Profiles belong to the character's GUID, so a rename updates the display and keeps the layouts. Each character starts with **Default**.

Choose **Save new** to name and save the plan in the editor. The dialog suggests the imported plan’s `NAME` when available. **Rename** opens with the current name selected. **Duplicate** suggests a copy name you can edit. Delete asks for confirmation and keeps at least one profile per character.

Under **Profile → Other characters**, choose a character and a layout to copy. Barsmith opens an independent draft on the current character, using a numbered suffix if the name already exists. The draft carries the plan and bar exclusions. Future overwrite permission starts off. Check and Apply the draft before Auto-fill can use it. A different-class plan keeps its class and spells for editing in the planner or with an AI assistant.

**Managed bars...** controls physical slots and their standard WoW button commands. Every page starts enabled. Clearing a checkbox protects its slots during Check/Apply, Auto-fill and Revert. A checkbox change invalidates the current review. Check counts skipped binding instructions and Details names the key, requested command and protected bar.

| Managed Bars checkbox | Physical slots | Button bindings protected by excluding it |
|---|---|---|
| Bar 1 | 1–12 | `ACTIONBUTTON1`–`12`, shared across all main-bar pages and forms |
| Bar 2 | 61–72 | `MULTIACTIONBAR1BUTTON1`–`12` |
| Bar 3 | 49–60 | `MULTIACTIONBAR2BUTTON1`–`12` |
| Bar 4 | 25–36 | `MULTIACTIONBAR3BUTTON1`–`12` |
| Bar 5 | 37–48 | `MULTIACTIONBAR4BUTTON1`–`12` |
| Bars 6, 7 and 8 | 145–156, 157–168, 169–180 | `MULTIACTIONBAR5BUTTON`, `MULTIACTIONBAR6BUTTON` and `MULTIACTIONBAR7BUTTON` respectively, buttons 1–12 |
| Bar 1 page 2, form pages and other bonus pages | 13–24, 73–144 | These checkboxes control slots. Bar 1 owns the shared physical keys. |

For example, excluding Cat protects the contents of slots 73–84. With Bar 1 enabled, changing an `ACTIONBUTTON` key also changes the key used in Cat and Bear. Excluding Bar 1 protects those keys while allowing placements on enabled form pages. Pet, stance-selector and addon-specific commands have their own identities.

An excluded independent bar keeps all its keys, including secondaries. Barsmith skips BP2 assignments, removals and transfers that touch a protected command. For BP1 it skips an entire destination’s exact replacement if a requested key belongs to a protected bar. Revert honors current exclusions on both ends of each recorded key change. Details lists the changes it will leave in place.

Explicit `MACRO` definitions edit a shared object. Check identifies excluded buttons using a macro it will edit. Those buttons retain their slot references and use the updated body. Revert also identifies shared edits and blocks deletion while an excluded button still uses a newly created macro.

| Situation | What happens |
|---|---|
| Check finds occupied managed slots | Summary counts immediate and future replacements separately. Details identifies each slot, its current contents and the planned action. **Apply** approves the immediate batch and rechecks it against live state. |
| A planned spell is learned or an item arrives | With Auto-fill enabled, empty managed slots fill automatically. Only explicit `SLOT` destinations participate, including on alternate form pages. |
| A previously unavailable action would replace an occupied slot | One prompt covers the batch. Choose **Review batch**, inspect **Details**, then **Approve batch**, or choose **Later**. **Review pending updates** reopens postponed replacements. A changed batch needs a fresh review. |
| This profile should handle future collisions automatically | Enable **Auto-overwrite occupied managed slots for newly available actions**. Once a placement is fulfilled, later events leave occupied slots alone. Empty spell and item slots remain eligible for refill. |

**Auto-fill new spells** is the existing account-wide enable switch. Its work and overwrite permission belong to the active profile on the logged-in character. Profile selection leaves WoW's binding scope alone. Check still identifies the active account-wide or character-specific set when the plan includes bindings. Re-enabling a bar makes its empty spell/item destinations eligible on the next matching leveling event. Reapplying a plan while a bar is excluded preserves previously approved pending targets on that bar when their slot instructions match. A changed excluded instruction cannot authorize an occupied-slot replacement. Auto-fill reads the last applied working plan for that profile. **Check** reads the editor plan and performs no placements or binding writes. If an intervening event changes reviewed state, **Apply** stops. Details shows the old and current values.

Auto-fill coalesces spellbook and bag notifications and remembers both while waiting for combat to end or the cursor to clear. A bag update evaluates item reservations. A spellbook update evaluates spell reservations. After a verified placement, refilling that same action requires evidence that the physical slot became empty. A form change or a bulk bar refresh alone cannot re-arm it.

If an automatic placement fails, chat names the slot and whether it was pending or empty. Barsmith pauses that operation for the session and continues other eligible placements. A changed destination, a new target rank, or a confirmed relearn after the spell became unavailable can retry it. An unavailable item can retry after acquisition. To retry an unchanged placement, run **Check → Apply** or toggle **Auto-fill new spells** off and on. User-approved replacement batches still apply as one transaction.

**Upgrading from a single saved plan.** The old `BarsmithDB.last` string identifies no character. Barsmith keeps it unassigned and preserves your Auto-fill setting. On the intended character, select the destination profile, click **Import old plan**, review **Check**, then **Apply**. A successful Apply of the original string consumes the legacy copy and hides the import button. Loading it into the editor or logging in on a same-class alt leaves it available. **Last applied plan** and `/barsmith apply` use this unclaimed copy when the selected profile has no applied history. If migration preserved two different unclaimed plans, both controls prefer the newer remaining `BarsmithDB.last`. **Import old plan** opens the older `legacyPlan`. The shortcut runs Check. Successful Apply claims only matching history.

### Revert last Apply

Click **Revert last Apply**, inspect **Details**, then click **Confirm revert**. Each profile keeps one snapshot of its last state-changing manual Apply. It restores changed action slots, macro bodies/icons and scope, affected key relationships, and the profile's previous saved plan and pending leveling placements. A no-op Apply preserves the snapshot. Leveling updates do not replace it. Revert restores the earlier working plan. **Last applied plan** still retrieves the exact input of the most recent successful manual Apply, including a no-op. New and copied drafts have no applied history.

Revert checks the live result again at confirmation. A changed slot, modified macro, changed binding set or conflicting key stops the batch. An unrelated key or slot can change independently. Barsmith also checks whether a newly created macro has acquired other slot or key references. After Barsmith observes a character switch, it blocks deletion of a newly created **account** macro because the current character cannot inspect the other character's bars.

On Forever, Barsmith reads the macro editor's selected icon. A question mark remains 134400 in exports and undo records as its displayed tooltip changes with a target or form. A different selected icon, body or scope remains a configuration change. When upgrading an older undo record, Barsmith can recover a newly created macro's requested question mark from its applied definition. Revert stops if an old displayed texture cannot establish the selection needed for restoration. Clients exposing only a displayed icon use strict comparisons after the initial tooltip resolution.

**Missing macros after Apply.** Before reporting success, Apply rereads all reviewed macro definitions and every managed macro destination after the last write. It checks the current bank by name and scope, so indices can change during batch creation. If that Apply created macros and remains the active profile’s latest undo record, the next UI load reports a one-time comparison in chat. A discrepancy identifies the affected names and slots. This second check observes what the client loaded and leaves the bars and macro bank alone.

To repair a missing reference, load the active profile’s **Last applied plan** and run **Check**. For a managed, explicit macro destination in that same applied plan, a zero macro action ID and an absent label can qualify for repair if the macro bank is readable and confirms the plan’s definition is missing or already matches. Check names the candidate slot. During Apply, Barsmith picks up the unresolved reference with an empty cursor before creating any macros. If the slot yields a usable action, Barsmith returns it and stops. A confirmed broken reference can be replaced with the intended macro, including one already recreated manually. Revert returns a repaired slot to empty because the client cannot recreate its former invalid reference. If another write fails during repair, the recovery report names any invalid references already cleared.

The spellbook can report a stored spell and its current overriding spell separately. Export uses physical action-slot membership to identify an underlying spell when available, and writes exact IDs for form-dependent entries. It never derives a spell ID from a form page number. The spell cursor can report a book index, an effective spell ID and a base spell ID. Barsmith checks the carried spell, tries the exact learned ID if the book pickup disagrees, and verifies the physical destination after placement. A named transformation can use its learned base when the player’s spellbook row or a client override lookup links the exact display name to that action. Separate learned book entries, requested ranks and explicit `spell:ID` instructions retain their identities. When the client cannot establish a unique learned action for a qualifier, Check leaves the placement pending and explains why in Details. A pickup failure reports the cursor and client relationship IDs there. A changed intended spell or rank, learned availability, occupied slot, macro or profile setting requires another review. Check and Apply can run in form with an empty cursor and out of combat.

Barsmith can restore empty slots, available spells and items, and uniquely identified macros. If a replacement would remove an action it cannot recreate, Check identifies the slot and stops before writing. A spent item or forgotten spell can also become unavailable between Apply and Revert. Snapshots cover the changes made by that Apply. Later leveling placements in other slots are outside the snapshot.

The game client is the authority. The web preview uses the snapshot attached to the current plan. Browser storage on this branch imports earlier saved plans and keeps its own copy.

## Files

| File | What it is |
|---|---|
| [index.html](index.html) | The planner, with the spellbook data embedded. Plans are saved in your browser. |
| [backdrops/](backdrops) | One screenshot per race (its starting zone) for the screen's backdrop, 1440x900 WebP. |
| [addon/Barsmith](addon/Barsmith) | The in-game importer (`/barsmith`). |
| [tools/build-spellbook.py](tools/build-spellbook.py) | Rebuilds the spellbook data in index.html from Forever's data: `python3 -I tools/build-spellbook.py index.html [cache-dir]` |
| [tools/fetch-backdrops.py](tools/fetch-backdrops.py) | Downloads the race backdrops from Warcraft Wiki and shrinks them: `python3 -I tools/fetch-backdrops.py backdrops` (needs Pillow) |
| [.github/workflows/pages.yml](.github/workflows/pages.yml) | Publishes the planner, backdrops and matching addon ZIP from the selected commit. |
| [LICENSE](LICENSE) | MIT license for the code. Ships in both addon zips. |
| [.github/workflows/release.yml](.github/workflows/release.yml), [.pkgmeta](.pkgmeta) | Packages the addon and uploads it to CurseForge and GitHub Releases when a `v*` tag is pushed. |

## Binding plans and compatibility

Both plan versions use a prefix followed by base64-encoded UTF-8. Each decoded line contains tab-separated fields. The original escaping for backslash, tab and newline also applies to BP2 binding fields. SLOT, MACRO, CLASS, NAME and RACE retain their existing syntax. Spells accept names, ranks or `spell:ID`. Items accept names or `item:ID`.

| Prefix and header | Binding records | Behavior |
|---|---|---|
| `BP2:`, `BARPLAN 2` | `ENSURE key command` | Give this key to the command. Preserve the command's other keys. |
| | `REMOVE key expected-command` | Release only that relationship. An already free key is a no-op. A different owner blocks Apply. Explicit removal of the last key is reported. |
| | `ALLOWORPHAN command` | Optional acknowledgment that this command may lose its last key. Existing records still load. |
| `BP1:`, `BARPLAN 1` | `BIND key command` | For each named command, the listed keys form its exact set. Check lists omitted keys as legacy exact removals. Conflicting claims or unresolved displacements block Apply. |

New plans use BP2. Imported BP1 plans and saved upstream browser plans retain BP1 semantics until **Convert BP1 to preservation-safe BP2** is selected. Conversion changes each BIND to ENSURE. Both versions retain multiple keys for a command. Binding order in the Settings UI is managed by the game. Reapplying a matching plan leaves the current key order alone.

Example decoded BP2 plan, with literal tabs:

```text
BARPLAN	2
ENSURE	R	TOGGLEAUTORUN
ENSURE	B	ACTIONBUTTON4
ENSURE	CTRL-B	TOGGLEBACKPACK
```

If B is Backpack's only key, Check reports the following for the last two assignments:

```text
Displacement: B from TOGGLEBACKPACK to ACTIONBUTTON4
New binding: CTRL-B -> TOGGLEBACKPACK
TOGGLEBACKPACK remains on CTRL-B
```

Leaving out the CTRL-B assignment produces a warning that Backpack will be unbound as B moves to the action button. You can Apply after reviewing Check. An already-correct R and a preserved NUMLOCK contribute to the summary counts. Expand **Full diagnostics** for the individual keys. The preserved count covers usable, unmentioned keys on commands involved in the plan.

## Census and API limits

**BC1** is a read-only snapshot. Its decoded header is `BINDCENSUS<TAB>1<TAB>set` (1 account, 2 character). Each `CMD` record contains context number, command identifier, localized category when available, display label, control type (`binding` or `custom`), and zero or more keys in API order. Zero keys on an ordinary command means currently unbound. An `OVERRIDE key action` row records a detectable runtime difference on a known key. The planner stores census data separately from executable plan instructions.

The addon visits every `GetNumBindings()` index, requests gamepad keys with `GetBinding(i, true)`, and collects every returned key and every `GetBindingKey` result. This includes registered addon commands and unbound rows. For each planned key, Check queries its current persistent owner and follows that command's keys, even for a dynamically bound `CLICK Frame:Button`. The API exposes no universal iterator for frame-owned overrides or unregistered dynamic command strings. A census can therefore describe the exposed registry in full while a later in-game Check discovers additional owners. A bar addon can also change its overrides after Check.

Management targets ordinary persistent gameplay bindings. Context-specific commands (including gamepad-mode commands) and custom controls appear in the census. Attempts to edit them are blocked. Voice push-to-talk exposes its chord through a separate accessor. Full diagnostics lists all detected runtime overrides. Summary warns when an override masks a proposed change or fallback. If every remaining key for a command losing a key is masked, Check blocks Apply until the plan or live state changes.

Factory defaults are unavailable as a complete read-only binding graph in the inspected Forever client. Its Settings reset calls `LoadBindings(Enum.BindingSet.Default)`, which changes the active table. Barsmith never uses that path or infers defaults from unbound commands. A character's current set may be account-wide. Check labels that scope and Apply saves to precisely that active set.

The capture, simulation and guarded writes live in [Bindings.lua](addon/Barsmith/Bindings.lua). Apply rechecks live ownership, the profile and detected overrides, performs only the reviewed differences, verifies the resulting graph and saves once. A write or save failure triggers best-effort restoration of attempted keys, with a recovery failure reported explicitly. A no-op performs no binding write or save. The addon verifies slot and macro writes too. A failure triggers best-effort rollback of the batch, including successfully changed bindings, and reports incomplete recovery. Successful persistence across a client restart requires an in-game test.

## Publishing this fork

Pushing to `main` publishes the site. To redeploy manually in GitHub Actions, open **Deploy to GitHub Pages**, choose **Run workflow**, select **main**, and run it. The workflow checks out that run’s commit, packages its addon with the MIT license and versioned TOC, and deploys the ZIP alongside its planner. The successful run records the deployed commit.

The fork uses **Settings → Pages → Source → GitHub Actions**. Under **Settings → Environments → github-pages**, the only permitted deployment branch is `main`.

## Verification and upstream sync

From the repository root, run both addon suites with `texlua tools/tests/bindings.lua` and `texlua tools/tests/profiles.lua` (or use `lua` for either). The planner suite runs with Node and jsdom 26. The optional HTML argument exercises the original upstream example and browser-storage migration.

```sh
git show 3163d36:index.html > /tmp/barsmith-upstream.html
npm install --prefix /tmp/barsmith-test jsdom@26
NODE_PATH=/tmp/barsmith-test/node_modules node tools/tests/planner.cjs /tmp/barsmith-upstream.html
```

One-time setup for a new clone of the fork:

```sh
git remote add upstream https://github.com/rubensayshi/wowforever-barplanner.git
```

To bring later upstream changes into the development branch:

```sh
git switch -c upstream-sync main
git fetch upstream
git merge upstream/main
```

After reviewing the merge and rerunning the tests, merge the reviewed changes into `main` to publish.

## Sources

Binding behavior was checked against the [Forever 1.60.1 UI source, build 71037](https://github.com/Gethe/wow-ui-source/tree/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns). Relevant files are `Blizzard_SettingsDefinitions_Frame/Keybindings.lua` for enumeration, `Blizzard_Settings_Shared/Blizzard_Keybindings.lua` for contexts, saving and reset, `Blizzard_APIDocumentationGenerated/KeyBindingsDocumentation.lua` for the C namespace, and `Blizzard_FrameXML/CustomBindingManager.lua` for separately managed controls. See also [GetBinding](https://warcraft.wiki.gg/wiki/API:GetBinding), [GetBindingKey](https://warcraft.wiki.gg/wiki/API:GetBindingKey) and [GetBindingAction](https://warcraft.wiki.gg/wiki/API:GetBindingAction).

Read 2026-11-01.

- EllesmereUI source (retail 7.2.2, April 2026): https://github.com/Anysu94/EllesmereUI . `EllesmereUIActionBars/EllesmereUIActionBars.lua` maps Bar 1–8 to the standard action pages (slots 1–12, 61, 49, 25, 37, 145, 157, 169) and binding commands ACTIONBUTTON / MULTIACTIONBAR1–7BUTTON. Not checked against the Forever build.
- Bartender4 (https://github.com/Nevcairiel/Bartender4, 8339c74, 2026-10-02), Dominos (https://github.com/tullamods/Dominos, 6653640, 2026-10-31) and ElvUI (https://github.com/tukui-org/ElvUI, 1fe8b7e, 2026-10-31), read 2026-11-01. All three list interface 16001 and have Forever code paths. Bar N shows slots (N−1)×12+1 (Dominos skips bar 12's slots, so its 12–14 are slots 145–180), and bars 1, 3–6 and 13–15 (Dominos 12–14) pass the game's ACTIONBUTTON / MULTIACTIONBAR1–7BUTTON keys on to their buttons with override bindings (Bartender4 `ActionBars.lua` BINDING_MAPPINGS, Dominos `bars/actionBar/button.lua`, ElvUI `Modules/ActionBars/ActionBars.lua` barDefaults). Their default main bar paging on Forever: Bartender4 Prowl → slots 85–96 (`StateBar.lua`, `ActionBars.lua`); Dominos Shadowform → 73–84 and Moonkin Form → 109–120 (`core/barStates/Camelot.lua`, `bars/actionBar/bar.lua`); ElvUI Shadowform → 73–84 and Prowl → 85–96 (`Defaults/Profile.lua` bar1 paging). An applied profile can target those pages with explicit SLOT records.
- EllesmereUI on Forever: https://www.icy-veins.com/wow-forever/news/wow-forever-players-can-now-build-their-perfect-ui-with-ellesmereui/ (403 when fetched; title from search results)
- ForeverSVFix release notes (SavedVariables loading bug, EllesmereUI profiles): https://github.com/nobewayo/ForeverSVFix/releases
- EUI Tweaks (lists game version 1.60.1): https://www.curseforge.com/wow/addons/eui-tweaks
- Action slot numbers, including stance/form pages (slots 73–120, separate from bars 2–5): https://warcraft.wiki.gg/wiki/Action_slot (retail page; Forever differs for some forms, see the next two lines)
- Which forms swap the main bar in Forever: the client's SpellShapeshiftForm table, column BonusActionBar, for build 1.60.1.70707: https://wago.tools/db2/SpellShapeshiftForm?build=1.60.1.70707 . Cat Form 1, Bear and Dire Bear Form 3, Battle Stance 1, Defensive Stance 2, Berserker Stance 3, Stealth 1 (page = slot 73 + 12 × (value − 1)). Moonkin Form and Shadowform are 0, so they keep the normal main bar, unlike retail. There's no Prowl form, so Prowl should stay on the Cat Form page (not checked in game: `/dump GetBonusBarOffset()` while prowling should print 1).
- Forever's own UI source, 1.60.1 (70532), mirrored at https://github.com/Gethe/wow-ui-source/tree/forever (read 2026-11-01): `Blizzard_ActionBarController/ActionBarController.lua` pages the main bar by `C_ActionBar.GetBonusBarIndex()` (so by the table above), and `Blizzard_ActionBar/Shared/MultiActionBars.xml` gives Edit Mode's Bar 2, 3, 4 (RightBar1), 5 (RightBar2) and 6–8 the slots 61, 49, 25, 37, 145, 157, 169 and buttons MULTIACTIONBAR1–7BUTTON, the same as the planner's bars.
- Spellbook data (read 2026-11-03), built by tools/build-spellbook.py:
  - Trainer spells per class with each rank's level, active talents and racials: wowforevertalents.com (https://wowforevertalents.com/abilities/, /<class>/, /racials/), which reads the Forever client build 1.60.1.70707 and the server hotfixes of 30 October.
  - Spell IDs per rank, passive flags and race limits (for example Desperate Prayer is Dwarf-only, Fear Ward is for every priest): the Forever client's tables for build 1.60.1.70707 via wago.tools (https://wago.tools/db2/SkillLineAbility?build=1.60.1.70707, plus SpellName, Spell, SpellMisc, Talent, TalentTab).
  - Spell ID per talent rank, including talents only the hotfixes add (Water Shield, Riptide, Oath of Light): the talent calculator script on wowforevertalents.com (the `/_astro/TalentCalculator.*.js` bundle and the scripts it imports). A talent is listed when the client marks its spell as not passive; the site's cost line decides only for spells the client tables lack, since some actives (Water Shield) have no cost line.
  - Trainer ranks newer than the client tables (the top rank of Lacerate) and renamed ranks have no ID, so their tooltip is the text from wowforevertalents.com.
- Race backdrops, starting-zone screenshots from Warcraft Wiki (fetched 2026-11-01, file names in tools/fetch-backdrops.py): Human Northshire Abbey, Dwarf Kharanos, Gnome Gnomeregan Entrance, Night Elf Dolanaar, Orc Valley of Trials, Undead Tirisfal Glades, Tauren Camp Narache, Troll Durotar, Skyborne Dalaran (Zephras Isle has no screenshots on the wiki yet). Some are from later expansions, so they don't always look like the Classic client. https://warcraft.wiki.gg/images/<file>
- Original idea: Naowh's Forever action bar planner, https://naowh.gg/forever/action-bars (it only sets up bars for Naowh's own addon suite)
- Heading font: Marcellus (Google Fonts), standing in for the game's Friz Quadrata
- Spell icons load from https://wow.zamimg.com/images/wow/icons/
- Tooltips load from Wowhead's Forever database when you hover a spell, stance or item: https://nether.wowhead.com/forever/tooltip/spell/<id> (the same source as https://www.wowhead.com/forever/spell=<id>). Checked 2026-11-01: 26 of 40 sampled spells differ from Classic, e.g. Lightning Bolt has a 2.5 sec cast. General spells (Attack, racials) have no ID in the data, so they keep the planner's own tooltip.
- CurseForge files for Forever are tagged with game version 1.60.1 (seen on EUI Tweaks above and others, e.g. https://www.curseforge.com/wow/addons/wow-forever-suite/files/all). The names BarPlan (https://www.curseforge.com/wow/addons/barplan, a different Forever addon with its own `/barplan`) and BarSmith (https://www.curseforge.com/wow/addons/barsmith, retail only) are taken, hence "Barsmith Importer".
- BigWigsMods/packager v2.6.1, `release.sh`: interface 16xxx maps to game type forever (CurseForge game version type 88568), the only Forever TOC suffix it knows is `_Camelot`, and it skips WoWInterface for Forever: https://github.com/BigWigsMods/packager/blob/v2.6.1/release.sh (Forever support added in https://github.com/BigWigsMods/packager/pull/202)

The code (page, addon and tools) is under the MIT license, see [LICENSE](LICENSE). World of Warcraft and its icons and screenshots are Blizzard Entertainment's. This is a fan tool.
