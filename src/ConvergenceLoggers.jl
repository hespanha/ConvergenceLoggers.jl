module ConvergenceLoggers

export TimeSeriesLogger, plotLogger!, plotLogger

using Statistics
using ElasticArrays
using Plots

"""
Structure used to store convergence data for plotting.

    logger=TimeSeriesLogger{T,D}(N; maxPoints,xlabel,ylabel,legend,ylimits)

# Fields:
+ `time::ElasticVector{T}`: time vector
+ `data::ElasticMatrix{D}`: matrix with data to plot, with one time instant per column and one time
        series per row
+ `maxPoints::Int`: maximum number of points to plot. When the number of time instants is larger
        than this value, multiple time instants are "aggregates" and represented by their mean, min,
        and max values.
+ `xlabel::String="time"`: label for the x axis
+ `ylabel::String="data"`: label for the y axis
+ `legend::Vector{String}=string.(1:N)`: legend for the different time series
+ `ylimits::Vector{Float64}=[-NaN64, NaN64]`: limits for the y axis

# Constructor parameters:
+ `T::Type`: type of the time variable
+ `D::Type`: type of the data variables
+ `N::Int`: number of time series
+ `maxPoints::Int`: maximum number of points to plot. When the number of time instants is larger
        than this value, multiple time instants are "aggregates" and represented by their mean, min,
        and max values.
+ `xlabel::String="time"`: label for the x axis
+ `ylabel::String="data"`: label for the y axis
+ `xaxis::Symbol`: scale for the x-axis, can be :identity, :ln, :log2, :log10, :asinh, :sqrt
+ `yaxis::Symbol`: scale for the y-axis, can be :identity, :ln, :log2, :log10, :asinh, :sqrt
+ `legend::Vector{String}=string.(1:N)`: legend for the different time series
+ `ylimits::Vector{Float64}=[-NaN64, NaN64]`: limits for the y axis
"""
struct TimeSeriesLogger{T,D}
    time::ElasticVector{T}
    data::ElasticMatrix{D}
    maxPoints::Int
    xlabel::String
    ylabel::String
    xaxis::Symbol
    yaxis::Symbol
    legend::Vector{String}
    ylimits::Vector{Float64}
    function TimeSeriesLogger{T,D}(
        N::Int;
        maxPoints::Int=200,
        xlabel::String="time",
        ylabel::String="data",
        xaxis::Symbol=:identity,
        yaxis::Symbol=:identity,
        legend::Vector{String}=string.(1:N),
        ylimits::Vector{Float64}=[-NaN64, NaN64],
    ) where {T,D}
        time::ElasticVector{T} = ElasticVector{T}(undef, 0)
        data::ElasticMatrix{D} = ElasticMatrix{D}(undef, N, 0)
        return new{T,D}(time, data, maxPoints,
            xlabel, ylabel, xaxis, yaxis, legend, ylimits)
    end
end

"""
Add one data point to the logger.

# Parameters:
+ `logger::TimeSeriesLogger{T,D}`: logger
+ `t::T`: time 
+ `d::AbstractVector{D}`: values
"""
function Base.append!(
    logger::TimeSeriesLogger{T,D},
    t::T,
    d::AbstractVector{D},
) where {T,D}
    append!(logger.time, t)
    append!(logger.data, d)
    return nothing
end
Base.append!(
    logger::TimeSeriesLogger{T,D},
    t::T,
    d::D,
) where {T,D} = append!(logger, t, [d])


"""
Plot array of loggers, each in one subplot of a given plot.

# Parameters:
+ `plt::Union{Plots.Plot,Plots.Subplot}`: Plot, typically with multiple subplots
+ 'subplot::AbstractVector{Int}': Optional vector with the indices of the subplots to use. When
        missing, the first subplots are used.
+ `logger::Vector{TimeSeriesLogger{T,D}}`: Vector of loggers to plot
+ `colors::Symbol=:glasbey_category10_n256`: color scheme to use in palette(). 
        Typical values include:
        + `:tab20` - good for categorical data with few categories (20 or less)
        + `:glasbey_category10_n256` - good for categorical data with many categories
        + `:viridis` - progressive palette from purple to yellow
        + `:hot` - progressive palette from black to yellow
        + `:lajolla` - progressive palette from yellow to black
        + `:temperaturemap` - progressive palette from blue to red
        See [https://docs.juliaplots.org/latest/generated/colorschemes/]
"""
function plotLogger!(
    plt::Union{Plots.Plot,Plots.Subplot},
    logger::Vector{TimeSeriesLogger{T,D}};
    kwargs...
) where {T,D}
    for i in eachindex(logger)
        plotLogger!(plt, i, logger[i], kwargs...)
    end
    return nothing
end
function plotLogger!(
    plt::Union{Plots.Plot,Plots.Subplot},
    subplots::AbstractVector{Int},
    logger::Vector{TimeSeriesLogger{T,D}};
    kwargs...
) where {T,D}
    for i in eachindex(subplots, logger)
        plotLogger!(plt, subplots[i], logger[i], kwargs...)
    end
    return nothing
end
function plotLogger!(
    plt::Union{Plots.Plot,Plots.Subplot},
    logger::TimeSeriesLogger{T,D}
) where {T,D}
    return plotLogger!(plt, 1, logger)
end

"""
Plot one logger in one subplot of a given plot.

# Parameters:
+ `plt::Union{Plots.Plot,Plots.Subplot}`: Plot, typically with multiple subplots
+ 'subplot::Int': Index of the subplots to use.
+ `logger::TimeSeriesLogger{T,D}`: logger to plot
"""
function plotLogger!(
    plt::Union{Plots.Plot,Plots.Subplot},
    subplot::Int,
    logger::TimeSeriesLogger{T,D};
    #colors::Symbol=:viridis, # progressive
    colors::Symbol=:glasbey_category10_n256, # categorical
) where {T,D}
    plt[subplot].series_list = [] # new one to erase old points
    #color_series = palette(:tab20, size(me, 2))
    (nD, nPoints) = size(logger.data)
    color_series = palette(colors, nD)
    (t::Vector{T}, me::Matrix{Float64}, mn::Matrix{Float64}, mx::Matrix{Float64}) = subSample(logger)
    ylimits = copy(logger.ylimits)
    if true
        # autoscale
        mmx = maximum(m for m in mx if isfinite(m); init=-Inf)
        mmn = minimum(m for m in mn if isfinite(m); init=+Inf)
        if !isnan(mmx) && !isnan(mmn) && mmx > mmn && isfinite(mmx) && isfinite(mmn)
            if isnan(ylimits[1])
                ylimits[1] = mmn - 0.05 * (mmx - mmn)
                if ylimits[1] <= 0 && logger.yaxis in [:ln, :log2, :log10]
                    # log-scale cannot get negative
                    ylimits[1] = mmn > 0 ? mmn : NaN
                end
            end
            if isnan(ylimits[2])
                ylimits[2] = mmx + 0.05 * (mmx - mmn)
            end
        end
    end
    if true
        # plot band from mn to mx
        for d in axes(me, 2)
            k = isfinite.(mn[:, d]) .&& isfinite.(mx[:, d]) # exclude nan and inf
            if any(k)
                Plots.plot!(plt[subplot], t[k], mn[k, d], fillrange=mx[k, d],
                    ylimits=ylimits,
                    xaxis=logger.xaxis, yaxis=logger.yaxis,
                    linecolor=color_series[d], linewidth=0, linealpha=0.0,
                    c=color_series[d], fillalpha=0.1,
                    label="")
            end
        end
    end
    if true
        # plot mean
        if nPoints < 50
            for d in axes(me, 2)
                if any(isfinite.(me[:, d])) # exclude series with only nan and inf
                    Plots.plot!(plt[subplot], t, me[:, d],
                        linecolor=color_series[d], linewidth=1, linealpha=1.0,
                        ylimits=ylimits,
                        xlabel=logger.xlabel, ylabel=logger.ylabel,
                        xaxis=logger.xaxis, yaxis=logger.yaxis,
                        labels=logger.legend[d],
                        markershape=:circle, markerstrokewidth=0, markercolor=color_series[d],
                        grid=true, legend=:topleft)
                end
            end
        else
            for d in axes(me, 2) # exclude series with only nan and inf
                if any(isfinite.(me[:, d]))
                    Plots.plot!(plt[subplot], t, me[:, d],
                        linecolor=color_series[d], linewidth=1, linealpha=1.0,
                        ylimits=ylimits,
                        xlabel=logger.xlabel, ylabel=logger.ylabel,
                        xaxis=logger.xaxis, yaxis=logger.yaxis,
                        labels=logger.legend[d],
                        grid=true, legend=:topleft)
                end
            end
        end
    end
    return plt
end
"""
Plot one logger in a new plot.

# Parameters:
+ `logger::TimeSeriesLogger{T,D}`: logger to plot
"""
function plotLogger(
    logger::TimeSeriesLogger{T,D}
) where {T,D}
    return plotLogger!(Plots.plot(), 1, logger)
end

"""Subsample logger times to the desired number of points."""
function subSample(
    logger::TimeSeriesLogger{T,D},
) where {T,D}
    time = logger.time
    data = logger.data
    if !issorted(time)
        k = sortperm(time)
        time = time[k]
        data = data[:, k]
    end
    (nD, nPoints) = size(data)
    maxPoints = min(logger.maxPoints, nPoints)
    t = Vector{T}(undef, maxPoints)
    me = Matrix{Float64}(undef, maxPoints, nD)
    mn = Matrix{Float64}(undef, maxPoints, nD)
    mx = Matrix{Float64}(undef, maxPoints, nD)
    stp::Int = ceil(nPoints / maxPoints)
    i = 1
    for j in eachindex(t)
        t[j] = time[min(i, nPoints)]
        for k in 1:nD
            iData = @view data[k, i:min(i + stp - 1, nPoints)]
            noNaN = Iterators.filter(!isnan, iData)
            # do not use mean in case T is "small" and causes overflow
            me[j, k] = sum(iData; init=zero(Float64)) / length(iData)
            mn[j, k] = minimum(noNaN; init=+Inf64)
            mx[j, k] = maximum(noNaN; init=-Inf64)
        end
        i += stp
    end
    return (t, me, mn, mx)
end

end

