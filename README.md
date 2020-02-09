# AllenBrain

[![Build Status](https://travis-ci.org/JuliaNeuroscience/AllenBrain.jl.svg?branch=master)](https://travis-ci.org/JuliaNeuroscience/AllenBrain.jl)
[![codecov.io](http://codecov.io/github/JuliaNeuroscience/AllenBrain.jl/coverage.svg?branch=master)](http://codecov.io/github/JuliaNeuroscience/AllenBrain.jl?branch=master)

**NOTE**: this was written against Julia 0.6 and only superficially updated, just to get it to build on Julia 1.x.
Anyone wanting to use this package will likely have to fix some bugs.

AllenBrain can query the *in situ* and projection databases of the [Allen Brain Atlas](https://portal.brain-map.org/).
It can also generate 3d visualizations colored by brain region using Makie.

AllenBrain was written to create the figures for the following paper, in which you can see some of the things this package can do. Please cite it if you find AllenBrain.jl useful:

Holy, Timothy E. "The accessory olfactory system: innately specialized or microcosm of mammalian circuitry?." Annual review of neuroscience 41 (2018): 501-525.
