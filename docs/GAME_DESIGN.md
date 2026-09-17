# Game Design — LAST SHIFT

## High concept

LAST SHIFT is a third-person open-world urban life, work and mystery game. The player inherits responsibility for a struggling garage in a fictional district inspired by contemporary Cairo. At first the problems are ordinary: rent, jobs, fuel, broken equipment, customers and deadlines. Then late-night work begins connecting the garage to a larger story.

The world should alternate between calm routine and unscripted pressure. The player is not constantly fighting. Driving across the district, doing real work, making money and meeting people makes the dangerous moments matter.

## Player fantasy

“I am trying to keep my life together in a city that remembers what I do.”

The player should feel ownership over:

- the garage;
- vehicles and their condition;
- cash flow;
- tools and upgrades;
- reputation;
- personal relationships;
- story decisions;
- what parts of the district trust or distrust them.

## Core loop

1. Wake/start a shift and review obligations.
2. Accept or discover work.
3. Travel through the district.
4. Perform a hands-on objective.
5. Deal with a complication or choice.
6. Get paid, lose resources, gain information or change a relationship.
7. Maintain the garage/player vehicle.
8. Decide what to do before the next deadline.
9. World state advances and creates new opportunities/consequences.

## World structure

The final game is open-world, but intentionally **dense**.

Proposed districts:

- **Garage Quarter** — first home base, apartments, shops, mechanic rivals.
- **Market Spine** — crowded commercial streets and delivery-heavy gameplay.
- **Industrial Yard** — warehouses, scrapyards, freight and late-night story work.
- **River Road** — faster driving route, food stands and social spaces.
- **Old Blocks** — tight alleys, rooftops and highly local character stories.
- **Outer Ring** — fuel station, highway links and higher-speed incidents.

Cells stream around the player. Each district has its own event tables, population profiles, ambient audio and traffic behavior.

## Systems of responsibility

### Garage

Persistent properties should eventually include:

- rent;
- electricity;
- tool durability;
- lift/compressor condition;
- inventory storage;
- security;
- staff;
- cleanliness;
- customer queue;
- upgrade slots.

Ignoring maintenance should not instantly “game over”. It should create believable friction: slower repairs, lost customers, debt, breakdowns and alternative story opportunities.

### Vehicle ownership

A player vehicle is a resource:

- fuel;
- engine health;
- cooling;
- battery;
- tires;
- suspension;
- body damage;
- cargo capacity;
- legal/registration state if the story needs it.

Driving should be readable and satisfying rather than a hardcore simulator. The near-player physics vehicle can use a higher-fidelity simulation while distant traffic uses cheap proxies.

### Economy

Money should have competing uses:

- rent and utilities;
- food and rest;
- fuel;
- repair parts;
- garage upgrades;
- vehicle upgrades;
- favors/debts;
- emergency story expenses.

The economy is interesting only when the player cannot buy everything immediately.

## Missions

Missions are data-driven graphs. A stage can complete from a world action and may branch into choices that set persistent flags.

Mission types:

- customer repair;
- towing/recovery;
- timed delivery;
- procurement;
- investigation;
- favor;
- emergency;
- social;
- garage defense/problem solving;
- multi-day story chain.

The game should avoid the repetitive “drive to marker, press button, leave” pattern. A mundane job can transform into a new problem while the player is already committed.

## Dynamic events

Events can require:

- chapter;
- time of day;
- weather;
- district;
- reputation;
- story flags;
- relationship thresholds;
- available world budget;
- cooldown.

Examples:

- broken-down driver;
- stalled delivery;
- argument;
- power cut;
- shop closing early;
- unexpected garage customer;
- crash;
- road closure;
- vehicle theft attempt;
- emergency repair;
- friend asking for help;
- suspicious vehicle;
- rain flooding a route;
- temporary fuel shortage.

Events should have “ignore” as a valid outcome. The world should not demand that the player solve everything.

## NPC model

Important NPC state:

```text
trust
fear
respect
debt
relationship
last_contact
knowledge_flags
schedule
home/work locations
current goal
witnessed events
```

Crowd NPCs use cheap simulation. Story NPCs can be promoted to full behavior only near the player.

## Story opening

The old owner leaves one unusual rule:

> Close the garage at 2:00 AM, whatever happens.

Several normal shifts pass.

At 1:47 AM a damaged vehicle arrives. The driver wants a trivial repair, pays too much, and says:

> Do not open the trunk.

The first vertical slice ends by making that promise the player's first meaningful branch.

## Tone

The world should feel grounded, local and human. Mystery and crime create tension, but they should not erase the everyday life layer that makes the city believable.
