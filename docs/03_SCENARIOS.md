# Scenario Definitions

All scenarios use the same core runner architecture. Normal gameplay uses the movement mode listed for the scenario.

The first Boulevard visit is established by the frontend `RUN_INTRO`: the selected character remains visually continuous while the camera resolves the Boulevard environment, moves around/past the character, and settles into the normal third-person gameplay camera before input and the run timer begin. This presentation choreography is not owned by Boulevard gameplay or `RunnerController`.

Every Transition Token starts a non-interactive, scripted real-time 3D cinematic. On collection, normal gameplay stops, gameplay input locks, invulnerability begins, normal generation stops, the configurable default `+1000` bonus is awarded exactly once, and a centered `BONUS` overlay appears. The cinematic has no playable lanes, controls, collectibles, obstacles, or failure conditions. It completes automatically and hands off through the shared transition framework.

## 1. Boulevard

Normal mode: `RUN`

Path:

- player stays on sidewalk;
- three invisible lanes fit entirely on sidewalk;
- buildings/storefront side and curb/street-furniture side disguise boundaries.

Typical later art:

- pedestrian groups;
- A-frame signs;
- benches;
- trash cans;
- street furniture;
- sidewalk clutter.

Scripted transition cinematic:

- character enters a curbside corridor between sidewalk and traffic;
- character performs a deterministic trash-can jump;
- character falls into the next scenario.

## 2. Sierra Nevada

Normal mode: `SNOWBOARD`

Path:

- downhill snow route;
- boundaries disguised using stakes, fence posts, snowbanks, rocks, pines, and cliffs.

Typical later art:

- rocks;
- trees;
- fallen logs;
- narrow cliff passages;
- snow obstacles.

Scripted transition cinematic:

- character leaves the mountain path and falls onto a train roof;
- the train enters and crosses a tunnel sequence;
- the character jumps away from the train into the next scenario.

## 3. San Francisco Bay

Normal mode: `SWIM`

Path:

- underwater corridor;
- boundaries disguised using kelp/sea grass, rock formations, wreckage, and seabed geography.

Typical later art:

- rocks;
- sea arches;
- broken ships;
- sharks;
- swimmers;
- wreck beams.

Scripted transition cinematic:

- character rises to the surface;
- a shark-wave sequence carries the character forward;
- the wave launches the character into the next scenario.

## 4. Sequoia National Park

Normal mode: `RUN`

Path:

- forest trail;
- boundaries disguised using redwoods, fences, bushes, rocks, and terrain.

Typical later art:

- stumps;
- fallen logs;
- bears/wildlife crossers;
- hikers/background people;
- lumber work areas;
- falling trees.

Scripted transition cinematic:

- character enters a cave and boards a mining cart;
- the cart follows a fully authored cave route;
- the character exits the cart and jumps into the next scenario.

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

Scripted transition cinematic:

- character enters a soundstage;
- the cinematic crosses, in order, a space/action set, a non-explicit glamorous/romantic set, and a Da Vinci-style studio/workshop;
- the character leaves through a door into the next scenario.

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

Scripted transition cinematic:

- character leaves the car and lands on a snowboard;
- the snowboard grinds the bridge's main cable along an authored path;
- the character launches from the cable into the next scenario.

## 7. Hollywood

Normal mode: `FLY`

Path:

- invisible aerial three-lane corridor;
- boundaries implied by buildings, balloons, billboards, clouds, and aerial traffic;
- must never look like a 2D or 2.5D stage.

Typical later art:

- balloons;
- zeppelins;
- UFOs;
- skyscrapers;
- alicorns;
- cranes/billboards.

Scripted transition cinematic:

- character transfers to a Da Vinci-style aerial-screw craft;
- the craft follows an authored climb;
- the character descends into the next scenario.

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

Scripted transition cinematic:

- character executes an exaggerated giant jump;
- the authored airborne sequence carries the character into the next scenario.

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

Scripted transition cinematic:

- character enters a car for a high-speed route through destruction;
- the car uses a ramp and passes through a giant donut;
- the character exits the car in midair and falls into the next scenario.

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
