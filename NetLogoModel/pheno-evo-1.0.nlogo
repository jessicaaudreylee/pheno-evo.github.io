extensions [palette] ;; this allows us to use fancy color palettes

;;;;;;;;; variables

globals [
  ;; globals that won't change
  ;; we could even eventually delete the variables and write the values into the code...
  death-threshold ;; damage level below which a turtle dies ;; set to 0.0000001
  toxin-limit ;; concentration of toxin in a patch below which it goes to 0 ;; set to 0.0000001
  pulsing? ;; boolean for pulsing ;; set to TRUE

  ;; globals we might end up using/changing
  switch-step ;; standard deviation of amount by which phenotype switching probability mutates ;; for now, 0.1
  env-step ;; standard deviation of amount by which environmental response mutates ;; for now, 0.1

  ;; globals that exist, but that we don't fiddle with
  ticks-to-pulse ;; number of ticks before next pulse of toxin; for use in deciding whether to dilute

  ;; globals that are controlled by sliders/buttons... for now, anyway
  ; toxin-conc ;; initial concentration of toxin to add ;; set to 1
  ; n ;; number of turtles to initiate population
  ; initial-switch-rate ;; probability of switching phenotype (by any means) ;; may eventually be evolved
  ; initial-response-error ;; if switching, how important is the environmental signal? ;; may eventually be evolved
  ; diff-rate ;; amount of toxin that diffuses from one cell to the next at each timestep ;; important aspect of experiment
  ; env-noise ;; variance around the environmental signal that indicates how much toxin is in a patch ;; important aspect of experiment
  ; color-code ;; whether to color-code by growth rate or by phenotype. this is for model exploration only-- not for the long run
  ; pulse-rate ;; number of timesteps between antibiotic pulses ;; for now, 20... but should depend on the spatial structure of the pulse!
  ; mutation-rate ;; chance of mutating at each timestep
  ; phenotype-dist ;; shape of phenotype distribution
  ; phenotype-parm ;; a parameter describing the stochastic phenotype distribution - could eventually be made an evolvable property of turtles
]


patches-own[
  toxin ;; toxin concentration on patch
  signal ;; how much toxin the patch *says* to the turtles it has
]


turtles-own[
  switch-rate ;; frequency of switching phenotype
  degrade-rate ;; phenotypic rate at which cell degrades toxin, drawn from the genotype distribution
  degrade-energy ;; amount of energy being spent on degradation (updated whenever phenotype is updated)
  response-error ;; genotypically encoded noise in the individual's phenotypic response to the environment. matters only if phenotype-dist = responsive
  response-energy ;; amount of energy being spent on responding to the environment (updated whenever a response is made). matters only if phenotype-dist = responsive
  growth-rate ;; this will be calculated from a turtle's health, accounting for fitness tradeoffs
  health ;; health/damage level (max growth rate before fitness tradeoffs)
  barcode ;; unique identifier of the cell lineage
  generation ;; number of generations elapsed since founding population - in case it's interesting
  x-y-dr ;; a list containing xcor, ycor, and degrade-rate, so they stay together for export
]


;;;;;;;;; small functions

to poison ;; initiate toxin in one area
   ask patches[
    set toxin toxin + toxin-conc ;; add the "toxin-conc" amount to that patch
    ]
  ; ] ;; note: if this isn't included in the "go" function, need to make sure to update patch color and signal afterward.
end


to dilute ;; simulate transfer to fresh medium
  if dilute-rate != 1 [
    let newpop-num round (count turtles / dilute-rate) ;; figure out how many turtles left after dilution
    let turtles-to-save n-of newpop-num turtles ;; choose that many random turtles from the population
    ask turtles [ ;; ask turtles whether they're part of the population to be saved
      if not member? self turtles-to-save
      [die] ;; if they aren't, ask them to die
    ]
    ask patches [ ; clear environment of any remaining toxin
      set toxin 0
    ]
    ask turtles [
      if count patches with [ not any? turtles-here] > 0 [
        move-to one-of patches with [ not any? turtles-here ] ;; redistribute the survivors randomly across the environment
      ]
    ]
  ]
end


to color-turtles ;; fancy color-coding schemes
  if color-code = "growth-rate" [
    ask turtles[
      set color palette:scale-gradient [[197 27 125][233 163 201][161 215 106][77 146 33]] growth-rate 0 1
    ]
  ]
  if color-code = "degrade-rate" [
    ask turtles[
      set color palette:scale-gradient [[165 0 38][255 255 191][49 54 149]] degrade-rate 0 1
    ]
  ]
  if color-code = "barcode" [
    ask turtles[
      set color palette:scale-gradient palette:scheme-colors "Divergent" "Spectral" 11 barcode 0 (n * 10)
    ]
  ]
end


to choose-phenotype
  if phenotype-dist = "binary" [
    ifelse random-float 1 < phenotype-parm [set degrade-rate 0]
    [set degrade-rate 1]
  ]
  if phenotype-dist = "normal" [
    set degrade-rate random-normal phenotype-parm 0.1
  ]
  if phenotype-dist = "uniform" [
    set degrade-rate random-float 1
  ]
  if phenotype-dist = "exponential" [
    set degrade-rate random-exponential phenotype-parm
  ]
  if phenotype-dist = "one-value" [
    set degrade-rate phenotype-parm
  ]
  if phenotype-dist = "responsive" [
    set degrade-rate [signal] of patch-here + random-float response-error - 0.5 * response-error
    if degrade-rate < 0 [set degrade-rate 0]
    if degrade-rate > 1 [set degrade-rate 1]
    set response-energy (1 - abs ([signal] of patch-here - degrade-rate)) / 2
  ]
end


;;;;;; important functions

to make-environment
  set death-threshold 0.0000001
  set toxin-limit 0.0000001
  set pulsing? TRUE
  set switch-step 0.2
  set env-step 0.2
  ask patches[ ;; initiate patches
    set toxin 0
    set signal toxin
    set pcolor white
  ]
end


to add-cells
  crt n [ ;; make cells
    setxy random max-pxcor random max-pycor ;; scatter randomly
    set size 1
    set shape "bacterium" ;; this is unnecessary but fun - may want to check at some point whether it slows things down
    set generation 1
    set switch-rate initial-switch-rate
    set response-error initial-response-error
    set response-energy 0 ; note that this will get rewritten by choose-phenotype if phenotype is responsive
    choose-phenotype
    ifelse degrade-rate < 0 [set degrade-rate 0] [if degrade-rate > 1 [set degrade-rate 1]] ;; brute-force way to keep degrade-rate between 0 and 1
    set degrade-energy degrade-rate / 2
    set health 1 ;; everyone starts healthy
    set growth-rate health * (1 - degrade-energy - response-energy) ;; this is the fitness tradeoff between growth and degradation, and response (if responding to environment)
    set barcode random n * 10 ;; assign a random barcode to help identify the lineage
    set x-y-dr list xcor ycor ;; set spatial phenotype data
    set x-y-dr lput degrade-rate x-y-dr ;; set spatial phenotype data
  ]
    color-turtles ;; color-code turtles by growth rate or phenotype
end


to setup
  clear-all
  make-environment
  add-cells
  reset-ticks
end


;;;;;;; making the model go

to go

  ;;;; to make toxin get added in periodic pulses
  ;if pulsing? [ ;; for now, got rid of the "if" statement because we're always pulsing
    if ticks-to-pulse <= 0 [ ;; check the ticks-to-pulse counter. if it's at zero...
      poison ;; add a toxin pulse...
    ifelse pulsing-random?
    [set ticks-to-pulse random-float (pulse-rate * 2)]
    [set ticks-to-pulse pulse-rate]
    ]
    set ticks-to-pulse (ticks-to-pulse - 1) ;; if the counter isn't yet at zero, subtract one
  ;]

  ;; diffuse toxin; manage toxin levels
  diffuse toxin diff-rate
  ask patches[
    if toxin < toxin-limit [set toxin 0] ;; if toxin goes below threshold, make it zero
    ;; signal to the world how much toxin each patch has (with some noise):
    set signal toxin + random-float env-noise - 0.5 * env-noise
    ifelse signal < 0 [set signal 0]
    [if signal > 1 [set signal 1]]
    ;; color-code patches by toxin concentration: grayscale on log scale with low = light and high = dark:
    ifelse toxin > 0 [set pcolor scale-color gray (log toxin 10) 1 (log toxin-limit 10)]
    [set pcolor white]
  ]

  ;;; turtles have a chance to switch phenotype. do this first so that other behaviors can work according to phenotype
  ask turtles[
    if random-float 1 < switch-rate[ ;; first, decide whether to switch. if switching,
      ;; set degrade-rate to match environmental signal, plus a stochastic amount of wrongness determined by genetic propensity for wrongness
      choose-phenotype
      ifelse degrade-rate < 0 [set degrade-rate 0] [if degrade-rate > 1 [set degrade-rate 1]]
      set degrade-energy degrade-rate / 2
    ]
  ]

  ;;; effect of turtles on toxin
  ask turtles[
    if [toxin] of patch-here > 0 [ ;; check whether toxin is present
      let dr degrade-rate ;; if health > death-threshold, start degrading toxin
        ask patch-here [
          set toxin (toxin - dr) ;; degrade some of it by according to phenotype. note there's no coefficient on dr
          if toxin < toxin-limit [set toxin 0]
      ]
    ]
  ]

  ;;; effect of toxin on turtles
  ask turtles[
    if [toxin] of patch-here > 0 [ ;; check whether toxin is present
      set health (health - toxin) ;; subtract health by amount equal to toxin level. note there's no coefficient on toxin
      if health < death-threshold [die] ;; then, check whether health is below threshold; if it is, die.
    ]
  ]

  ;;;; color-code turtles by phenotype or growth rate
  color-turtles

  ;;; reproduction and mutation
  ask turtles[
    ;;; first, figure out growth rate based on how much energy was spent on other activities
    set growth-rate health * (1 - degrade-energy - response-energy)
    ;if growth-rate < 0 [set growth-rate 0]
    ;;; then, make new cells
    if (count neighbors with [not any? turtles-here]) > 0 [ ;; only reproduce if there's space
      if random-float 1 < growth-rate [ ;; higher growth rate -> higher probability of reproducing
        let growth-space patch-set neighbors with [not any? turtles-here] ;; find patches with no turtles
        let one-space one-of growth-space ;; choose one of those patches to populate
        hatch 1[ ;; by default, the daughter cell inherits parent's (self's) characteristics... so now we change some of them:
          setxy [pxcor] of one-space [pycor] of one-space ;; move the baby next door
          if mutation-rate != 0 [ ;; only bother mutating if parent's mutation rate isn't 0
            if random-float 1 < mutation-rate [ ;; do a random draw to see whether it's time to mutate
              set switch-rate [switch-rate] of self + random-float switch-step - 0.5 * switch-step ;; draw from normal distribution centered on 0 with sd=switch-step
              ifelse switch-rate < 0 [set switch-rate 0] [if switch-rate > 1 [set switch-rate 1]] ; make sure things stay bounded between 0 and 1
              if phenotype-dist = "responsive"[ ;; only if in a regime where organisms respond to the environment,
                set response-error [response-error] of self + random-float env-step - 0.5 * env-step ;; mutate response-error
                ifelse response-error < 0 [set response-error 0] [if response-error > 1 [set response-error 1]]
              ]
            ]
          ] ; end mutation
          set health 1
          set generation [generation] of self + 1
          choose-phenotype
          set x-y-dr list xcor ycor  ;; update spatial phenotype data
          set x-y-dr lput degrade-rate x-y-dr ;; update spatial phenotype data
          ]
        ]
      ]
    ] ; end reproduction
  ;]

  ;;;; dilute the population whenever the universe fills up. make dilute-rate=0 to turn off.
  if count turtles >= count patches [dilute]


  ;;;; time elapses
  tick

  if count turtles = 0 [
    stop
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
258
10
776
529
-1
-1
10.0
1
10
1
1
1
0
0
0
1
0
50
0
50
1
1
1
ticks
30.0

BUTTON
13
10
79
43
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
16
490
79
523
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
13
44
63
104
n
200.0
1
0
Number

PLOT
781
11
968
131
Total cell population
Time
# cells
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles"

PLOT
974
11
1142
131
Average toxin per patch
Time
Toxin
0.0
100.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [toxin] of patches"

PLOT
780
376
968
496
Phenotype: degrade-rate
degrade-rate
# cells
-0.1
1.1
0.0
10.0
true
false
"" ""
PENS
"default" 0.01 1 -16777216 true "" "histogram [degrade-rate] of turtles"

SLIDER
15
227
181
260
initial-switch-rate
initial-switch-rate
0
1
0.5
.1
1
NIL
HORIZONTAL

SLIDER
14
383
182
416
initial-response-error
initial-response-error
0
1
0.5
.1
1
NIL
HORIZONTAL

SLIDER
15
191
178
224
diff-rate
diff-rate
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
14
347
181
380
env-noise
env-noise
0
1
0.5
0.1
1
NIL
HORIZONTAL

CHOOSER
13
107
178
152
color-code
color-code
"growth-rate" "degrade-rate" "barcode"
1

PLOT
983
133
1143
253
Growth rates
growth-rate
# cells
-0.1
1.1
0.0
10.0
true
false
"" ""
PENS
"default" 0.01 1 -16777216 true "" "histogram [growth-rate] of turtles"

INPUTBOX
64
44
128
104
pulse-rate
20.0
1
0
Number

SLIDER
15
418
182
451
mutation-rate
mutation-rate
0
0.1
0.05
0.01
1
NIL
HORIZONTAL

PLOT
970
255
1143
375
Genotype: switch-rate
switch-rate
# cells
-0.1
1.1
0.0
10.0
true
false
"" ""
PENS
"default" 0.01 1 -16777216 true "" "histogram [switch-rate] of turtles"

PLOT
781
254
966
374
Genotype: response-error
response-error
# cells
-0.1
1.1
0.0
10.0
true
false
"" ""
PENS
"default" 0.01 1 -16777216 true "" "histogram [response-error] of turtles"

INPUTBOX
130
45
197
105
toxin-conc
1.0
1
0
Number

SLIDER
16
454
182
487
dilute-rate
dilute-rate
1
100
10.0
1
1
NIL
HORIZONTAL

SWITCH
14
156
178
189
pulsing-random?
pulsing-random?
1
1
-1000

PLOT
781
133
979
253
Maximum generations lived
Time
Generations
0.0
10.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot max [generation] of turtles"

CHOOSER
15
264
182
309
phenotype-dist
phenotype-dist
"binary" "normal" "uniform" "exponential" "one-value" "responsive"
5

SLIDER
15
312
182
345
phenotype-parm
phenotype-parm
0
1
0.5
.1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?
This model simulates the growth of microbial cells in a 2-dimensional environment where they are periodically stressed by a toxin. You could imagine this universe as a culture of bacteria growing on agar in a (very small) petri dish that experimenters flood occasionally with antibiotics, or perhaps microbes growing on your skin, which you periodically wash with soap. Cells can degrade the toxin, but degradation takes energy, so there is a tradeoff: toxin-degrading cells reproduce more slowly. Moreover, because the toxin can diffuse through space, cells that degrade toxin are helping their neighbors.

One of the key features of this model is that although the cells are all of the same population (that is, they're genetically identical*), it's possible for the individuals to have different phenotypes-- specifically, to have different abilities to degrade the toxin. This phenomenon is sometimes called "phenotypic heterogeneity," and we're interested in it because microbiologists have discovered that organisms can use phenotypic heterogeneity as a strategy for survival in stressful and unpredictable environments. It's an example of how microbes can generate more complex adaptive responses than we usually think. (Please see the References section for more information.)

The purpose of the Pheno-Evo model is to explore what the best strategy might be for the population as a whole to survive under different environmental conditions. In what cases does the population stand the best chances of surviving if all cells spend most of their energy on degrading toxin? When is it better to have some few toxin-degraders and some cells specialized at growing fast? As the experimenter, you can test different strategies and different conditions; you can also allow your population to evolve and see what solution it comes up with!

*Except in the case of mutation. If you run this model with mutation, it's important to consider both genetic diversity and phenotypic diversity at the same time.


## HOW IT WORKS
We start with **n** microbial cells randomly distributed across the environment, one cell per patch. At each timestep, the following happens:

1. Toxin is added to the environment and diffuses according to the parameters **pulse-rate,** **toxin-conc,** **pulsing-random?** and **diff-rate**. Patches are color-coded by toxin concentration, a gradient from white = 0 to black = 1.

2. Cells get the chance to change their phenotype, according to the regime set by the user.
This may entail drawing from a distribution of potential phenotype values, as determined by **phenotype-dist,** and **phenotype-parm.** Or, if **phenotype-parm** = "responsive," cells sense and respond to the environmental conditions according to **env-noise** and **initial-response-error** (see below for details.) Sensing and responding accurately takes energy and therefore decreases a cell's reproduction rate.

3. Cells degrade the toxin in their patch according to their phenotypic ability (**degrade-rate**). Degrading toxin also takes energy and therefore decreases reproduction rate.

4. The remaining toxin injures the cells, decreasing their overall **health**. Cells with low health have a lower reproductive rate (**growth-rate**), and when health falls below a certain threshold, they die.

5. Cells get the chance to reproduce onto a nearby patch; as mentioned above, reproduction capacity depends on health, and on how much energy is spent on degrading toxin and sensing the environment. Reproduction occurs only if a nearby patch is empty. Daughter cells inherit all the genotypic properties of their parents, but may mutate some of those values according to **mutation-rate.** Phenotype is not heritable.

6. If the environment gets filled up with cells, the population is diluted: a random set of cells are removed and the survivors are redistributed across the environment. The fraction of survivors may be chosen by the **dilute-rate** parameter.


Each cell has:

  1. A phenotype: rules for behavior that are not heritable, and can be changed. This consists solely of:
    * **degrade-rate** = the rate at which the cell degrades toxin in its patch. At each timestep, the value of degrade-rate is subtracted from the concentration of the toxin
  2. A genotype: rules for behavior that are heritable, and are fixed except in the case of mutation. This consists of:
    * **switch-rate** = the probability of switching phenotype at each timestep
    * **response-error** = if we're in a regime where cells sense the environment (**phenotype-dist** = "responsive), response-error describes how lax the cell is in its response. 
    * **barcode** = this is just an identity marker indicating who the cell's founding ancestor was, in case it's of interest. It has no impact on behavior.
    * **generation** = a number indicating how far descended this cell is from the original ancestor; when a cell reproduces, the daughter inherits the parent's generation and adds 1. Generation has no impact on behavior.
  3. A physiology: characteristics of the cell that change with conditions
    * **health** = how well the cell is doing, generally. Toxin exposure reduces health
    * **growth-rate** = the probability the cell will reproduce at each timestep. This is recalculated each timestep based on the cell's health and the energy it is spending on sensing its environment and degrading toxin.


## HOW TO USE IT
Choose your settings using the sliders, switches, chooser, and input fields to the left of the environment. Then hit **setup.** (Some parameters will update dynamically if you change them while the model is running, but it's safest to re-do setup after any changes.) Then hit **go.** 

What the parameter settings do:

* **n**: the number of cells in the initial population
* **pulse-rate**: number of ticks that elapse between each time the toxin is added to the environment. Set at 1 for constant toxin influx.
* **toxin-conc**: the concentration of toxin added to each patch, when toxin is added to the environment. This does not need to be bounded, but we typically work between 0 and 1.0.
* **initial-switch-rate**: the probability that each cell in the population will switch phenotype at each timestep. If there is no evolution (**mutation-rate** = 0), all cells retain the **initial-switch-rate** as their **switch-rate**, and it remains constant for all cells all the time. If there is evolution (**mutation-rate** > 0), **initial-switch-rate** is the value that all cells start with, but their **switch-rate** values may evolve away from it over time.
* **initial-response-error**: if **phenotype-dist** = "responsive," then when cells switch phenotype, they try to choose a phenotype value that matches the concentration of toxin they sense on their patch (**signal** of the patch). But they're not perfect: they actually draw from a normal distribution, where **signal** is the mean and **response-error** is the standard deviation. So the bigger **response-error** is, the worse the organisms are at responding to their environment. 
Also, the bigger **response-error** is, the less energy the cells spend on sensing their environment (leaving more energy for reproduction).
If there is no evolution (**mutation-rate** = 0), then **response-error** for all cells is the same all the time, and it's equal to **initial-response-error**. If there is evolution (**mutation-rate** > 0), then the population begins with **response-error** = **initial-response-error**, but may evolve away from it.
* **env-noise**: In this universe, it is possible that it might be difficult for any organism to detect how much toxin there is, regardless of how much energy the cells put into reducing their * **response-error**. We model such an environment by allowing each patch a **signal** that it sends out to organisms. The **signal** is drawn from a normal distribution for which the mean is **toxin** (the actual concentration of toxin in the patch) and the standard deviation is **env-noise.** The larger **env-noise** is, the harder it is for organisms to understand what's going on in their environment.
* **diff-rate**: The rate at which toxin diffuses from one patch to its neighboring patches. **diff-rate** = 0 means no diffusion at all. **diff-rate** = x means that x*100% of the toxin in the patch is distributed equally among its 8 neighboring patches. Note that the lower **diff-rate** is, the less the toxin-degrading activity of a cell is able to affect the concentration of toxin in neighboring patches.
* **color-code**: The cells in the model are color-coded to indicate something about them, and you can choose what color code you'd like using this drop-down menu. 
  * "growth-rate": this is a gradient from pink = low to green = high
  * "degrade-rate": this is a gradient from red = low to blue = high
  * "barcode": each cell in the founding population starts with a distinct **barcode** and its progeny all share the same barcode-- so you can easily see which lineages beat out other lineages. each barcode receives a distinct randomly-chosen color. 
* **mutation-rate**: the probability that a cell will mutate in any given timestep. If the cell mutates, it mutates both switch-rate and response-error at the same time. **mutation-rate** = 0 means no evolution.
* **dilute-rate**: the divisor by which the population is reduced, when dilution step takes place. * **dilute-rate** = 0 means no dilution; cells are only removed from the environment when they die due to toxin exposure. **dilute-rate** = 5 means 1/5 of the population is retained. **dilute-rate** = 100 means 1/100 of the population is retained.
* **pulsing-random? ** "Off" = toxin pulses come at regular intervals determined by pulse-rate. "On" = toxin pulses come at random intervals, where intervals are chosen from a uniform distribution with mean of **pulse-rate**.
* **phenotype-parm**: parameter contributing to phenotype distribution. Its precise meaning depends on phenotype-dist.
* **phenotype-dist**: the shape of the distribution from which **degrade-rate** is drawn when organisms switch phenotype. This is true for the entire population. Options are as follows:
  * "binary": a binary distribution where cells can have only values of 0 or 1. The fraction of cells with 0 is equal to **phenotype-parm**.
  * "normal": a normal distribution with mean **phentotype-parm** and standard deviation 0.1
  * "uniform": a uniform distribution between 0 and 1
  * "exponential": an exponential distribution with mean **phenotype-parm**
  * "one-value": all cells have a single degrade-rate, equal to **phenotype-parm**
  * "responsive": cells sense the toxin concentration in their patch and switch their **degrade-rate** to match that value, with the caveats that they are actually sensing **signal**, which might not be equal to the real **toxin** value, and how accurately they are able to match their **degrade-rate** to the **signal** depends on their **response-error**.


## THINGS TO NOTICE
* Under **color-code,** select **degrade-rate** to color your microbial cells by their phenotypic toxin degrading capacity. Observe the patches of colored cells and see which colors expand fastest and which slowest, and which ones survive when there is a pulse of toxin. Notice what's going on in the spots where the toxin disappears most quickly.

* Under **color-code,** select **barcode** to color your microbial cells by their family lineage. Watch as each founding cell gives rise to a colony of descendants, and observe whether any founders win over any other founders. Observe the difference it makes when there is bottlenecking (**dilute-rate** > 0) and when there is not (**dilute-rate** = 0). Are there cases in which just a single founder wins out? Does it make a difference whether there is evolution (**mutation-rate** >0) or not?

* The dilution step is programmed so that the population gets diluted only if the number of turtles is equal to or greater than the number of patches. This means that, even when dilute-rate > 0, there are some situations in which dilution does not happen. As you run the model, notice whether you encounter any such situations. What causes it?  

## THINGS TO TRY
This is a complicated model, with a lot of bells and whistles! It's fun to change them all at once, but perhaps not very informative. We recommend doing controlled experiments by turning several of the options to 0 and changing just one or two things at a time. Here are some examples:

### No evolution: which phenotype distribution is the best?
* Set the following to 0: mutation-rate, initial-response-error, env-noise. Set pulsing-random to Off.
* Pick your favorite values for the following parameters and hold them constant: pulse-rate, toxin-conc, initial-switch-rate, dilute-rate.
* Run the model several times, choosing a different option for phenotype-dist each time. You may also change phenotype-parm each time. Which distributions are able to survive indefinitely? Which ones have the highest growth rates, or reach the highest number of generations in the shortest amount of time? Which ones fizzle and die?
* Now, pick one of the variables you previously kept constant (pulse-rate, toxin-conc, initial-switch-rate, dilute-rate) and change it, and see how that changes your results. For instance, does the concentration of toxin in the environment affect whether a one-value distribution is more successful than a uniform distribution?
* Advanced: Just because you set the distribution of phenotypes that the population can draw from, that doesn't mean the population will actually fall into that distribution at steady state once environmental selection has taken its toll. This is most apparent when cells aren't able to switch from one phenotype to another very fast. To observe this, set initial-switch-rate to 0, dilute-rate to 100, and phenotype-dist to "uniform." Try running with toxin-conc = 1. Check out the _Phenotype: degrade rate_ histogram. Does that actually look like a uniform distribution? Repeat with toxin-conc = 0.
Now imagine these organisms lived out in the wild, and you were a microbial ecologist studying them through observation. From your observations of their behaviors, what would you infer about these organisms' underlying genetic capacity for degrading toxin, and for reproducing? Would you be right? 

### With evolution: how do organisms deal when the environment is unpredictable?
* Set the following parameters to your favorite value (not 0) and keep constant: pulse-rate, toxin-conc, diff-rate, mutation-rate, dilute-rate.
* Set pulsing-random? "Off" and phenotype-dist "responsive"
* Set initial-switch-rate and initial-response-error to 0.5
* Run the model several times, and vary env-noise between 0 and 1. Switch-rate and response-error will evolve over time; watch what happens to them in the plot windows, and/or export data in a spreadsheet and analyze in R.
* When env-noise = 0, organisms are able to sense their environment-- that is, they can tell how much toxin is in their patch. But when env-noise = 1, the signal that organisms get from their environment is random and has no connection to the actual value of the toxin in their patch.
We hypothesize that it is a good strategy for organisms to switch their phenotype to match the toxin in their patch: if the toxin is high, they stand the best chances of surviving if they switch to a high degrade-rate so that they can degrade the toxin quickly, before it kills them. If the toxin is low, they should switch to a low degrade-rate because the pressure to degrade toxin is not as strong, and they can use the extra energy to reproduce more quickly. Therefore, in a world where it is possible for organisms to sense their environment perfectly (env-noise = 0), they will probably evolve toward being able to make that switch with accuracy (response-error = 0), even if it means spending more energy on being accurate. However, in a world where organisms are unable to tell what the toxin concentration is no matter how hard they try (env-noise = 1), it is not worth spending energy on accurate sensing mechanisms, so they will evolve toward making their switch randomly (response-error = 1).
You can test whether this hypothesis is correct!


### Other things to try
* Does it matter whether toxin pulses are periodic or aperiodic? Toggle **pulsing-random?** on and off. Keep in mind that you may also need to change **pulse-rate** for a fair comparison between the two.

* What happens when organisms can't influence each others' environment at all? Turn **diffusion-rate** down to zero to find out.

* How big a difference does dilution make? This is especially interesting when you have evolution turned on (mutation-rate > 0). Without dilution, population turnover is slow, because there are no new births until cells clear space by dying from toxin exposure. With dilution, turnover is constant, so there are many more generations-- but the individuals that survive the bottleneck from one dilution to the next are chosen at random, so there is a distinct possibility for drift. Try carrying out the same experiment without dilution (dilute-rate = 0) or with it (say, dilute-rate = 100), or change the bottleneck size by playing with the value of dilute-rate. Observe the maximum number of generations over time in the built-in plot window, or export your data and use our R script to analyze the average number of generations over time in each experiment.

## EXTENDING THE MODEL
The dynamics in this model are based roughly on biological principles, but there are many reasonable alternative ways of executing things, and changing those details could change the way the model behaves. Here are just three examples:

* We tried to scale most variables between 0 and 1, but it might make more sense for them not all to be on the same scale. For instance, you could allow toxin-conc to go up to 10 even if degrade-rate still only goes up to 1.
* We've chosen to make the fitness trade-offs equal and additive: the energy spent on environment sensing and toxin degradation can each take up to 50% of an organism's energy. You may choose to change the way that works.
* We don't explicitly model the consumption of a growth substrate-- we assume that it's unlimited. But you could add a growth substrate and have individuals compete for that resource, perhaps introducing a fitness tradeoff between substrate utilization and the ability to degrade toxin.

In an effort to avoid going completely over the top in complexity, we've kept the options for evolution in this model somewhat limited. We initiate the population with individuals that are all identical. And if you allow evolution (mutation-rate > 0), organisms can only evolve their switch rate and response error, and both must evolve at the same time. If you're very interested in the evolutionary dynamics, you are welcome to change that. Some things to try might include:

* Initiate with a mixed population (not all genotypes identical) and look at the results of competition
* Allow switch rate and response error to evolve at different rates
* Allow phenotype-parm to evolve

Finally, it's likely you'll want to monitor some variables that are different from what is shown in our built-in plot windows. You can add any plot windows you like; to learn how, check out the NetLogo manual.


## NETLOGO FEATURES
To get a true understanding of how the model behaves and to do some real experiments, we recommend using BehaviorSpace to run parameter sweeps that explore sets of parameters you're interested in.

Then, output your data as a table and use our R package to analyze and visualize your results! Visit our website to download the package.


## RELATED MODELS


## CREDITS AND REFERENCES
This model was written by: Jessica Audrey Lee, Ritwika Vallomparambath PanikkasserySugasree, Kirtus Leyba, Adam Reynolds, Daniel Borrero, and Pam Mantri.
It is a product of the Santa Fe Institute Complex Systems Summer School, 2019.
If you use it, we'd appreciate it if you'd cite us as:
Lee, JA et al. (2020) The Pheno-Evo model: Evolution of microbial phenotypic diversity in 2D space. 
Please visit our website, xyz, for more background on the science of phentoypic heterogeneity in microorganisms.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

bacterium
true
0
Polygon -7500403 true true 135 30 165 30 195 45 195 195 165 210 135 210 105 195 105 45
Line -7500403 true 150 210 150 210
Line -7500403 true 150 210 150 210
Line -7500403 true 150 210 150 240
Line -7500403 true 150 240 135 255
Line -7500403 true 135 255 150 285

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment_190830" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>count turtles</metric>
    <metric>mean [toxin] of patches</metric>
    <metric>[toxin] of patches</metric>
    <metric>[degrade-rate] of turtles</metric>
    <enumeratedValueSet variable="toxin-conc">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-response-error">
      <value value="0"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="env-noise">
      <value value="0"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pulse-rate">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-switch-rate">
      <value value="0"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation-rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="color-code">
      <value value="&quot;degrade-rate&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diff-rate">
      <value value="0"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n">
      <value value="200"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment_200116" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>count turtles</metric>
    <metric>mean [toxin] of patches</metric>
    <metric>[degrade-rate] of turtles</metric>
    <metric>[switch-rate] of turtles</metric>
    <metric>[response-error] of turtles</metric>
    <metric>[barcode] of turtles</metric>
    <enumeratedValueSet variable="toxin-conc">
      <value value="0"/>
      <value value="0.2"/>
      <value value="0.4"/>
      <value value="0.6"/>
      <value value="0.8"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-response-error">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="env-noise">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pulse-rate">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-switch-rate">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation-rate">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diff-rate">
      <value value="0"/>
      <value value="0.2"/>
      <value value="0.4"/>
      <value value="0.6"/>
      <value value="0.8"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n">
      <value value="200"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment_200117" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>count turtles</metric>
    <metric>mean [toxin] of patches</metric>
    <metric>[degrade-rate] of turtles</metric>
    <metric>[switch-rate] of turtles</metric>
    <metric>[response-error] of turtles</metric>
    <metric>[barcode] of turtles</metric>
    <enumeratedValueSet variable="toxin-conc">
      <value value="0"/>
      <value value="0.2"/>
      <value value="0.4"/>
      <value value="0.6"/>
      <value value="0.8"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diff-rate">
      <value value="0"/>
      <value value="0.2"/>
      <value value="0.4"/>
      <value value="0.6"/>
      <value value="0.8"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment_200214" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>count turtles</metric>
    <metric>mean [toxin] of patches</metric>
    <metric>[degrade-rate] of turtles</metric>
    <metric>[switch-rate] of turtles</metric>
    <metric>[response-error] of turtles</metric>
    <metric>[barcode] of turtles</metric>
    <enumeratedValueSet variable="toxin-conc">
      <value value="0"/>
      <value value="0.2"/>
      <value value="0.4"/>
      <value value="0.6"/>
      <value value="0.8"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diff-rate">
      <value value="0"/>
      <value value="0.2"/>
      <value value="0.4"/>
      <value value="0.6"/>
      <value value="0.8"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment_200216" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>count turtles</metric>
    <metric>mean [toxin] of patches</metric>
    <metric>[degrade-rate] of turtles</metric>
    <metric>[switch-rate] of turtles</metric>
    <metric>[response-error] of turtles</metric>
    <metric>[barcode] of turtles</metric>
    <enumeratedValueSet variable="toxin-conc">
      <value value="0"/>
      <value value="0.2"/>
      <value value="0.4"/>
      <value value="0.6"/>
      <value value="0.8"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="env-noise">
      <value value="0"/>
      <value value="0.2"/>
      <value value="0.4"/>
      <value value="0.6"/>
      <value value="0.8"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment_200303" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>count turtles</metric>
    <metric>mean [toxin] of patches</metric>
    <metric>[degrade-rate] of turtles</metric>
    <metric>[switch-rate] of turtles</metric>
    <metric>[response-error] of turtles</metric>
    <enumeratedValueSet variable="toxin-conc">
      <value value="0"/>
      <value value="0.2"/>
      <value value="0.4"/>
      <value value="0.6"/>
      <value value="0.8"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="env-noise">
      <value value="0"/>
      <value value="0.2"/>
      <value value="0.4"/>
      <value value="0.6"/>
      <value value="0.8"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment_200804_tutorial" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <metric>mean [toxin] of patches</metric>
    <metric>[degrade-rate] of turtles</metric>
    <metric>[switch-rate] of turtles</metric>
    <metric>[response-error] of turtles</metric>
    <metric>[barcode] of turtles</metric>
    <metric>[generation] of turtles</metric>
    <metric>[x-y-dr] of turtles</metric>
    <enumeratedValueSet variable="toxin-conc">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="env-noise">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
