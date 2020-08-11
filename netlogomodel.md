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
