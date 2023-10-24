using AllenBrain
using Test

@testset "AllenBrain" begin
    # These are only "does it run" tests?
    species = "mouse"
    resolution = 50
    g, vertexlist = ontology(species)
    if !isfile(AllenBrain.dataset(species, "annotation_"*string(resolution)))
        download_annotation(resolution; species)
    end
    a = annotation(resolution; species)
    download_projection(293546902, tempname())
end
