function colorize(ano, default::Colorant, id_color::Pair...)
    dest = similar(ano, Int32)
    colorize!(dest, ano, default, id_color...)
end

function colorize(ano::AxisArray, default::Colorant, id_color::Pair...)
    dest = similar(parent(ano), Int32)
    cdest = colorize!(dest, ano, default, id_color...)
    AxisArray(cdest, axes(ano))
end

colorize!(ano, default::Colorant, id_color::Pair...) =
    colorize!(ano, ano, default, id_color...)

function colorize!(ano::AxisArray, default::Colorant, id_color::Pair...)
    dest = colorize!(parent(ano), parent(ano), default, id_color...)
    AxisArray(dest, axes(ano))
end

function colorize!(dest::AbstractArray{T}, ano, default::Colorant, id_color::Pair...) where T
    colorlist = [RGBA{Float32}(0,0,0,0)]   # background (not inside brain)
    relabeldict = Dict{eltype(ano),eltype(dest)}(0=>1)
    # Add the default
    push!(colorlist, default)
    for (ks, v) in id_color
        push!(colorlist, v)
        for k in ks
            relabeldict[k] = length(colorlist)
        end
    end
    colorize!(dest, ano, relabeldict, colorlist)
end

function colorize!(dest::AbstractArray{To}, ano::AbstractArray{Ti},
                   relabeldict::Dict{Ti,To},
                   colorlist::AbstractVector{C}) where {To<:Integer, Ti<:Integer,C<:Colorant}
    indices(dest) == indices(ano) || throw(DimensionMismatch("inputs must match, got $(indices(dest)) and $(indices(ano))"))
    @inbounds for i in CartesianRange(indices(dest))
        dest[i] = get(relabeldict, ano[i], To(2))
    end
    IndirectArray(dest, colorlist)
end

@require GLVisualize begin
    function visualize_volume(volumedata)
        window = GLVisualize.glscreen()
        volume = GLVisualize.visualize(volumedata, :absorption)
        GLVisualize._view(volume, window)
        @schedule GLVisualize.renderloop(window)
    end
end
