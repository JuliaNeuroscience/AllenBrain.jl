function append_depthfirst!(g, lookup, node)
    push!(lookup, node)
    pv = nv(g)
    for c in node["children"]
        add_vertex!(g)
        add_edge!(g, pv, nv(g))
        append_depthfirst!(g, lookup, c)
    end
    g, lookup
end

"""
    g, vertexlist = ontology(filename)
    g, vertexlist = ontology("mouse")

Return the structure graph `g` and list `vertexlist` of metadata for nodes.
"""
function ontology(filename)
    str = read(dataset(filename, "ontology"), String)
    hierarchy = JSON.parse(str)
    g = DiGraph()
    add_vertex!(g)  # for the root node
    vertexlist = Dict{String,Any}[]
    append_depthfirst!(g, vertexlist, hierarchy)
    g, vertexlist
end

"""
    matches = findvertices(pat, vertexlist, field="acronym")

Return the list of vertices that Regex-match to `pat` for the
specified field ( `"acronym"` or `"name"`) of each node listed in `vertexlist`.
"""
findvertices(pat, vertexlist, field="acronym") = find(x->ismatch(pat, x[field]), vertexlist)

"""
    ids = structureids(v, vertexlist)

Return the structure_id associated with each vertex in `v`.
"""
structureids(v, vertexlist) = map(i->vertexlist[i]["id"], v)
structureids(pat::Regex, vertexlist, field="acronym") =
    structureids(findvertices(pat, vertexlist, field), vertexlist)

function annotation(resolution=50; species="mouse")
    anno = load(dataset(species, "annotation_"*string(resolution)))
    # The NRRD header is incorrect, we should fix the orientation
    r = resolution*μm
    return AxisArray(anno.data, (:P, :I, :R), (r, r, r))
end

function download_annotation(resolution=50; species="mouse", year=2016)
    dest = joinpath(mousedir, "annotation_$resolution.nrrd")
    download("http://download.alleninstitute.org/informatics-archive/current-release/$(species)_ccf/annotation/ccf_$year/annotation_$resolution.nrrd", dest)
end

"""
    bbleft, bbright = boundingbox(f, annotated)

Return the BoundingBoxes encapsulating structure(s) for which
`f(annotated[i])` returns `true`, separately for the two hemispheres
of the brain. `annotated` is a labeled volume. Units of `bb` are
microns.
"""
function boundingbox(f, annotated)
    scalebb(bx, px) = BoundingBox(map((iv, s) -> minimum(iv)*s .. maximum(iv)*s, bx.intervals, ps))
    local bb
    isfirst = true
    # Search only the left half of the volume
    inds = mapfilter(i->first(i):(first(i)+last(i))÷2, indices(annotated),
                     Axis{:R}, axes(annotated))
    for i in CartesianRange(inds)
        if f(annotated[i])
            if isfirst
                bb = BoundingBox(i, i)
                isfirst = false
            else
                bb |= i
            end
        end
    end
    dim = find(x->x==:R, axisnames(annotated))[1]
    bbr = BoundingBox(ntuple(ndims(annotated)) do d
        iv = bb.intervals[d]
        if d == dim
            id = indices(annotated, d)
            l = first(id) + last(id)
            l-maximum(iv) .. l-minimum(iv)
        else
            iv
        end
    end)
    ps = pixelspacing(annotated)
    scalebb(bb, ps), scalebb(bbr, ps)
end
