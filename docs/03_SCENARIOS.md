# Scenario Definitions

All scenarios use the same core runner architecture.

## 1. Boulevard

Normal mode: `RUN`

Path:
- player stays on sidewalk;
- three invisible lanes fit entirely on sidewalk;
- buildings / storefront side and curb / street furniture side disguise boundaries.

Typical later art:
- pedestrian groups;
- A-frame signs;
- benches;
- trash cans;
- street furniture;
- sidewalk clutter.

Transition:
- collect Transition Token;
- move into curbside corridor between sidewalk and traffic, not normal street-running gameplay;
- invulnerable;
- run/jump through collectible line;
- scripted trash-can jump;
- fall into next scenario.

Transition input:
- Left/Right;
- authored jump moments as needed.

## 2. Sierra Nevada

Normal mode: `SNOWBOARD`

Path:
- downhill snow route;
- boundaries disguised using stakes, fence posts, snowbanks, rocks, pines and cliffs.

Typical later art:
- rocks;
- trees;
- fallen logs;
- narrow cliff passages;
- snow obstacles.

Transition:
- leave mountain path;
- fall onto train roof;
- train enters tunnel;
- player shifts across three roof positions collecting items;
- tunnel exits;
- player jumps from train into next scenario.

Transition input:
- primarily Left/Right.

## 3. San Francisco Bay

Normal mode: `SWIM`

Path:
- underwater corridor;
- boundaries disguised using kelp/sea grass, rock formations, wreckage and seabed geography.

Typical later art:
- rocks;
- sea arches;
- broken ships;
- sharks;
- swimmers;
- wreck beams.

Transition:
- rise to surface;
- surf a wave while riding a shark;
- collect items across wave;
- launch into next scenario.

Transition input:
- primarily Left/Right.

## 4. Sequoia National Park

Normal mode: `RUN`

Path:
- forest trail;
- boundaries disguised using redwoods, fences, bushes, rocks and terrain.

Typical later art:
- stumps;
- fallen logs;
- bears / wildlife crossers;
- hikers / background people;
- lumber work areas;
- falling trees.

Transition:
- enter cave;
- ride mining cart on three rail positions;
- switch rails;
- exit cave;
- jump into next scenario.

Transition input:
- Left/Right rail switching.

## 5. Filming Sets

Normal mode: `RUN`

Path:
- service/backlot corridor between studio buildings and production infrastructure.

Typical later art:
- barrier gates;
- traffic barriers;
- cameras;
- light stands;
- parked production vehicles;
- security/crew groups;
- equipment cases.

Transition:
- enter soundstage;
- scripted traversal through multiple surreal film sets;
- include a space/action set, a non-explicit glamorous/romantic set, then Da Vinci-style studio/workshop;
- leave through door into next scenario.

Transition input:
- mostly authored movement;
- limited steering where useful.

## 6. Golden Gate Bridge

Normal mode: `CAR`

Path:
- normal bridge traffic lanes.

Typical later art:
- cars;
- trucks;
- buses;
- roadwork barriers;
- ramps;
- maintenance obstacles.

Transition:
- leave car;
- land on snowboard;
- ride/grind bridge main cable;
- forward movement automatic;
- no left/right lane changes;
- player uses vertical actions to collect/avoid authored elements;
- launch from end into next scenario.

Transition input:
- Up/Down only.

## 7. Hollywood

Normal mode: `FLY`

Path:
- invisible aerial three-lane corridor;
- boundaries implied by buildings, balloons, billboards, clouds and aerial traffic;
- must never look like a 2D or 2.5D stage.

Typical later art:
- balloons;
- zeppelins;
- UFOs;
- skyscrapers;
- alicorns;
- cranes/billboards.

Transition:
- leave normal flying mount;
- transfer to Da Vinci-style aerial-screw bicycle;
- fly higher through transition route;
- descend/fall into next scenario.

Transition input:
- Left/Right/Up/Down.

## 8. Grass

Normal mode: `RUN`

Path:
- trail through oversized/tall grass;
- challenge is reduced visibility, never unfair hidden hazards.

Typical later art:
- dense grass;
- flowers;
- roots;
- stones;
- bent plants.

Transition:
- collect Transition Token;
- execute exaggerated super-jump;
- airborne transition into next scenario.

Transition input:
- minimal / mostly authored.

## 9. Earthquake

Normal mode: `RUN`

Path:
- damaged city street;
- corridor can curve around destruction.

Typical later art:
- cars/buses;
- running people;
- masonry/debris;
- cracks/craters;
- collapsing signs/building elements;
- damaged road.

Transition:
- jump onto/into car;
- high-speed invulnerable run through destruction;
- use ramp;
- pass through giant donut;
- character exits car midair;
- fall into next scenario.

Transition input:
- primarily Left/Right;
- ramp moment authored.

## Scenario identity

Although classes are shared, obstacle rhythm should differ:

```text
Boulevard      pedestrian/static-object weaving
Sierra Nevada  speed + natural gates
Bay            vertical avoidance
Sequoia        environmental timing
Filming Sets   clutter + moving crossers
Golden Gate    traffic
Hollywood      aerial/vertical navigation
Grass          visibility
Earthquake     rapidly changing environment
```
