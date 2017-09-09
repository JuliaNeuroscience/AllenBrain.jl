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
    str = readstring(dataset(filename, "ontology"))
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
