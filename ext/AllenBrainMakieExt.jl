module AllenBrainMakieExt

using AllenBrain, Makie

# NOTE: this was written against GLVisualize which is deprecated for
# Makie. The code below likely needs updating.
function AllenBrain.visualize_volume(volumedata)
    window = Makie.glscreen()
    volume = Makie.visualize(volumedata, :absorption)
    Makie._view(volume, window)
    @schedule Makie.renderloop(window)
end

end
