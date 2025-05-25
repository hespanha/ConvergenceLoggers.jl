# ConvergenceLoggers.jl

This julia package provides utilities to log and display the convergence of iterative processes
arising, e.g., in the training of Neural Networks, Reinforcement Learning, etc.

## Usage


### Basic use

To gather data, we start by creating a `TimeSeriesLogger` object, where the data to be
logger is stored.

```julia
using ConvergenceLoggers
clog = TimeSeriesLogger{Int,Float64}( # Int time stamps and Float64 values
    3;   # number of variables to log
    legend= ["top", "middle", "bottom"], 
    yaxis=:log10, 
    xlabel="episode number",
    ylabel="",
    )
```

This creates a single logger that 
+ stores 3 variables, each of type `Float64`
+ each sample of the 5 variables is time-stamped with an `Int`
+ in plots:
  + the 5 variables will be labeled with the name given by the `legend` keyword parameter
  + the x-axis will have the label in the `xlabel` keyword parameter
  + the y-axis will use a log-10 scale (`:log10`) and will have no label (`ylabel=""`)

For more options check

```julia
?TimeSeriesLogger
```

Data is stored into the logger with the `append!` command. Typically, this takes place in a loop:

```julia
for t in 1:1000
    data=(2 * rand(3) .+ [1.0, 5, 10]) ./ t
    append!(clog, t, data)
end
```

The logged data can be visualized using `plotLogger`:

```julia
plt=plotLogger(clog)
display(plt)
savefig("figures/example1.png") # only needed if you want to save the figure
```

![example1](figures/example1.png)

> [!Tip]
> plotLogger! will limit the number of points displayed (by default to 200, but this can be changed
> with the `maxPoints` keyword argument).
> 
> When the logger has more data than what is displayed, it
> uses a *shaded area* to show the full range of values in the logger and a *solid line* to show the average.
> This typically looks much nicer (and is much faster) than trying to plot thousands-millions of points.

### Iterative plots

Often one wants to see progress as the iteration converges.

In such cases, to minimize overhead one should create a `Plots.plot` object before the loop starts
and then use `plotLogger!` inside the loop, which updates the time series of an existing plot,
rather than recreating the plot at each iteration. 

The following code shows a typically use of `ConvergenceLoggers` within a loop:

```julia
begin
# create logger
using ConvergenceLoggers
clog = TimeSeriesLogger{Int,Float64}( # Int time stamps and Float64 values
    3;   # number of variables to log
    legend= ["top", "middle", "bottom"], 
    yaxis=:log10, 
    xlabel="episode number",
    ylabel="",
    )

# create plot 
using Plots
plts=Plots.plot(size=[800,400])

# main loop
tNextPlot=time()
anim= @animate for t in 1:500
    global tNextPlot

    # hopefully your code will create data that is not random ;-)
    data=(2 * rand(3) .+ [1.0, 5, 10]) ./ t
    append!(clog, t, data)

    if time()>=tNextPlot || t==500 
        plotLogger!(plts, clog)
        display(plts)
        tNextPlot=time()+2 # update plot every 2 seconds & at end
    end
end
gif(anim,"figures/example2.gif",fps=30)
end
```

![example2](figures/example2.gif)

> [!Tip]
> 
> Creating an animation is obviously not needed, but good to show how it looks.

### Multiple loggers

Often one wants to monitor multiple variables that do not fit well in the same plot. In this case,
one can create arrays of loggers, which can be displayed with a single `plotLogger` command.

The following code shows how this would be done within a loop:

```julia
begin
# create logger
using ConvergenceLoggers
clogs = [
    # first logger
    TimeSeriesLogger{Int,Float64}( # Int time stamps and Float64 values
    1;
    legend=[""], 
    yaxis=:log10, 
    xlabel="episode number",
    ylabel="NN residual",
    ),
    # second logger
    TimeSeriesLogger{Int,Float64}( # Int time stamps and Float64 values
    2;
    legend=["reward for player 1", "reward for player 2"], 
    yaxis=:log10, 
    xlabel="episode number",
    ylabel="RL",
    ),
]

# create plot with 2 subplots 
using Plots
plts=Plots.plot(layout=@layout[a b],size=[800,400], margin=15Plots.pt)

# main loop
tNextPlot=time()
anim= @animate for t in 1:500
    global tNextPlot

    # hopefully your code will create data that is not random ;-)
    residual=(rand(Float64)+.1)./t
    rewards=(2 * rand(1) .+ [1.0, 5.0]) ./ t
    append!(clogs[1], t, residual)
    append!(clogs[2], t, rewards)

    if time()>=tNextPlot || t==500 
        plotLogger!(plts, clogs)
        display(plts)
        tNextPlot=time()+2 # update plot every 2 seconds & at end
    end
end
gif(anim,"figures/example3.gif",fps=30)
end
```

![example3](figures/example3.gif)