# Pheno-Evo: the NetLogo model

## How to get it
The Pheno-Evo model is written in NetLogo. You can download the entire thing as a .nlogo file [here](https://drive.google.com/file/d/1STqcJbUCOfdHy1tS4zBdPzQlTk9pO84B/view?usp=sharing), and run it on your computer using [NetLogo](https://ccl.northwestern.edu/netlogo/). NetLogo is free to download and it's easy to learn the basics quickly. If you're new to NetLogo, there are abundant resources online for playing with simpler models and learning to code your own.

Alternatively, if you'd prefer not to run NetLogo on your computer, you can use the [NetLogo Web version of the Pheno-Evo model](https://jessicaaudreylee.github.io/pheno-evo.github.io/pheno-evo_web.html). It has everything the original has except the color-coding (because that requires an extension not available for the web format). And some of the plots might be a bit difficult to interpret until you expand them to full screen. Lastly, it will be impossible to do the kinds of in-depth experiments and parameter sweeps on the web version that you can do with the original version, as [BehaviorSpace](https://ccl.northwestern.edu/netlogo/docs/behaviorspace.html) is not available for NetLogo Web. But if you're just looking to play around, this is a great place to start.

## What it is
This model simulates the growth of microbial cells in a 2-dimensional environment where they are periodically stressed by a toxin. You could imagine this universe as a culture of bacteria growing on agar in a (very small) petri dish that experimenters flood occasionally with antibiotics, or perhaps microbes growing on your skin, which you periodically wash with soap. Cells can degrade the toxin, but degradation takes energy, so there is a tradeoff: toxin-degrading cells reproduce more slowly. Moreover, because the toxin can diffuse through space, cells that degrade toxin are helping their neighbors.

One of the key features of this model is that although the cells are all of the same population (that is, they're genetically identical*), it's possible for the individuals to have different phenotypes-- specifically, to have different abilities to degrade the toxin. This phenomenon is sometimes called "phenotypic heterogeneity," and we're interested in it because microbiologists have discovered that organisms can use phenotypic heterogeneity as a strategy for survival in stressful and unpredictable environments. It's an example of how microbes can generate more complex adaptive responses than we usually think. (Please see the [Background page](https://jessicaaudreylee.github.io/pheno-evo.github.io/background) for more information.)

The purpose of the Pheno-Evo model is to explore what the best strategy might be for the population as a whole to survive under different environmental conditions. In what cases does the population stand the best chances of surviving if all cells spend most of their energy on degrading toxin? When is it better to have some few toxin-degraders and some cells specialized at growing fast? As the experimenter, you can test different strategies and different conditions; you can also allow your population to evolve and see what solution it comes up with!

*Except in the case of mutation. If you run this model with mutation, it's important to consider both genetic diversity and phenotypic diversity at the same time.

## How to learn about it
**The Info tab**: the NetLogo model itself has an Info tab where we've tried to include as much basic information as we can about how the model works. Much of that documentation is copied right here ("What it is," "How it works," "How to use it"), but there are also some more thought-provoking questions and exercises there as well, which we hope will help you explore the model.

**The intro tutorial**: we've included [a brief tutorial here](https://jessicaaudreylee.github.io/pheno-evo.github.io/netlogomodel_tutorial) that walks you through setting up an example experiment using BehaviorSpace. 

## How it works
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
    
## How to use it
Choose your settings using the sliders, switches, chooser, and input fields to the left of the environment. Then hit **setup.** (Some parameters will update dynamically if you change them while the model is running, but it's safest to re-do setup after any changes.) Then hit **go.** You can watch it run!

That's how you run one the model once. If you want to do an experiment to test the effect of several parameters, you'll want to use BehaviorSpace. [Visit our tutorial to get started](https://jessicaaudreylee.github.io/pheno-evo.github.io/netlogomodel_tutorial).

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

## What we could have done better
There's no end to list of things that we've considered adding to the functionality of this model but haven't yet, and decisions about implementations that we're still questioning. See the "Extending the Model" section of the "Info" tab in the NetLogo file for some ideas for things you might want to add or change. We are certainly open to feedback!

We're especially aware that the model itself might already be a bit bulky; we haven't designed it for efficiency. You may find that if you run the model with the visual simulation going, it might sometimes get slow or freeze up, especially if you have "phenotype-dist" in "responsive" mode or if you have mutation turned on. This can usually be cleared up (at least for a little while) by closing NetLogo and opening again. And we haven't found it to be unexplained slowdowns to be an issue with BehaviorSpace runs. But if you know precisely what experiments you want to do and know that you can toss out some of the functionality you're not using, you may find it useful to pare down the code. Similarly, we'd urge caution when deciding what reporters to measure and save during experiments, keeping in mind that when you store data on every single cell at every timestep, file sizes can get big fast!

**[Back to home](https://jessicaaudreylee.github.io/pheno-evo.github.io/)**
