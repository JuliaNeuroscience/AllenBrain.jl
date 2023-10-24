"""
    q = query_reference2image(sectiondataset, x, y, z)

Given a `sectiondataset`, find a point in a 2d slice image closest to
the specified `x`, `y`, `z` location in the reference atlas (specified
in microns).
"""
function query_reference2image(sectiondataset::Dict, x, y, z)
    id = sectiondataset["id"]
    refspace = sectiondataset["reference_space_id"]
    xr, yr, zr = inmicrons(x), inmicrons(y), inmicrons(z)
    str = "http://api.brain-map.org/api/v2/reference_to_image/$refspace.json?x=$xr&y=$yr&z=$zr&section_data_set_ids=$id"
    rq = HTTP.request("GET", str)
    data = JSON.parse(String(rq.data))
    data["msg"][1]["image_sync"]
end

"""
    p, i, r = query_image2reference(sectionimageid, x, y)

Given a particular slice `sectionimageid` and pixel location `x`, `y`,
return the posterior, inferior, right coordinates `p`, `i`, `r` in microns.
"""
function query_image2reference(sectionimageid::Integer, x, y)
    str = "http://api.brain-map.org/api/v2/image_to_reference/$sectionimageid.json?x=$x&y=$y"
    rq = HTTP.request("GET", str)
    data = JSON.parse(String(rq.data))
    ret = data["msg"]["image_to_reference"]
    ret["x"], ret["y"], ret["z"]
end

"""
    sectionimage(secdata, w, h, filename; downsample=0)

Download a section image specified by `secdata`, where `secdata` comes
from [`query_reference2image`](@ref). Width `w` and height `h` are expressed
in pixels prior to downsampling (shrinking horizontal and vertical by
a factor of `2^downsample`). Image is saved to `filename`.
"""
function sectionimage(secdata::Dict, w, h, filename; downsample=0)
    id = secdata["section_image_id"]
    x, y = secdata["x"], secdata["y"]
    download("http://api.brain-map.org/api/v2/image_download/$id?downsample=$downsample&left=$x&top=$y&width=$w&height=$h", filename)
end

"""
    splice_sectionimages(dirname, Δplane)

Combine a series of section images into a 3d volume.  Adjacent planes
will be spaced by `Δplane`, expressed in microns. The resolution
within the slice plane is determined by the raw images.

Uses interpolation along the slicing axis where appropriate, but
otherwise this takes a conservative approach and marks pixels with NaN
whenever data are missing. Data can be missing for at least two
reasons:

* Adjacent available slices are separated by more than `2Δplane`, so
  that some intermediate plane is more distant than `Δplane` from any
  available image;

* Some individual images do not cover the entire region expressed by
  the within-plane components of the BoundingBox used to extract the
  slices (stored in the metadata file in `dirname`). This can happen
  when the relevant structure lies near the tissue boundary.

## Note

Currently this assumes that the image is in PIR coordinates and that
these are coronal slices, so that the first axis is the slicing axis.
"""
function splice_sectionimages(dirname, Δplane)
    cd(dirname) do
        md = load("metadata.jld2")
        pos = md["sectionposition"]
        ds = md["downsample"]
        fn = md["filenames"]
        bb = md["boundingbox"]
        res = md["sectiondataset"]["section_images"][1]["resolution"]*μm*2^ds
        ivx, ivy, ivz = bb.intervals               # in "Allen Coordinates"
        xrange = minimum(ivx):Δplane:maximum(ivx)  # the slice axis (assumes coronal)
        sz2d = map(x->round(Int, x/res), IntervalSets.width.((ivy, ivz)))
        img1 = load(first(fn))
        frames = Vector{typeof(img1)}(length(fn))
        frames[1] = img1
        for i = 2:length(fn)
            frames[i] = load(fn[i])
        end
        C = base_colorant_type(eltype(img1)){Float32}
        img = Array{C}(sz2d..., length(xrange))
        fill!(img, nan(RGB{Float32}))
        computeframes!(img, bb, xrange, frames, pos, ds)
        imgaa = AxisArray(img, (:I, :R, :P), (res, res, Δplane))
        save("spliced.nhdr", imgaa; props=Dict("datafile"=>"spliced.raw"))
    end
end

function computeframes!(img, bb, xrange, frames, pos, ds)
    slicepos = [p[1]*μm for p in pos]
    for (j, x) in enumerate(xrange)
        # Find the nearest slices to this particular "x" (slice) position
        im = findfirst(y->y>=x, slicepos) # nearest slice "below"
        ip = im+1                         # nearest slice "above"
        # The available data might be too far away to reasonably
        # interpolate, in which case it's better to leave this plane
        # as NaN to mark it as missing data.
        m_inrange = isinrange(im, slicepos, x, step(xrange))
        p_inrange = isinrange(ip, slicepos, x, step(xrange))
        m_inrange || p_inrange || continue
        if !m_inrange
            computeframe!(view(img, :, :, j), bb, ds, frames[ip], pos[ip])
        elseif !p_inrange
            computeframe!(view(img, :, :, j), bb, ds, frames[im], pos[im])
        else  # both are in range, use linear interpolation along the slice dimension
            f = (x - slicepos[im])/(slicepos[ip] - slicepos[im])
            computeframe!(view(img, :, :, j), bb, ds, frames[im], pos[im], frames[ip], pos[ip], f)
        end
    end
    img
end

"Copy frame data, compensating if needed for a shift in the slice plane"
function computeframe!(dest, bb, downsample, src, pos)
    sa = extrapolant(eltype(dest), bb, downsample, src, pos)
    for i in CartesianRange(indices(dest))
        dest[i] = sa[i]
    end
    dest
end

"Interpolate frame data, compensating if needed for a shift in the slice plane"
function computeframe!(dest, bb, downsample, src1, pos1, src2, pos2, f)
    sa1 = extrapolant(eltype(dest), bb, downsample, src1, pos1)
    sa2 = extrapolant(eltype(dest), bb, downsample, src2, pos2)
    for i in CartesianRange(indices(dest))
        dest[i] = (1-f)*sa1[i] + f*sa2[i]
    end
    dest
end

"""
Correct for an integer-pixel shift in the frame. We could use subpixel
interpolation, but given that the resolution in the slice plane is so
much better than the resolution along the slice axis, there seems
little point in being more sophisticated.
"""
function extrapolant(::Type{T}, bb, downsample, src, pos) where T
    d1, d2 = inmicrons(minimum(bb.intervals[2])), inmicrons(minimum(bb.intervals[3]))
    s1, s2 = pos[2], pos[3]
    mag = 2^downsample
    Δ1, Δ2 = round(Int, (s1-d1)/mag), round(Int, (s2-d2)/mag)
    inds1, inds2 = offsetindex(indices(src, 1), Δ1), offsetindex(indices(src, 2), Δ2)
    extrapolate(interpolate(view(src, inds1, inds2), NoInterp(), OnGrid()), nan(T))
end

offsetindex(inds, Δ) = OffsetArray(inds, inds+Δ)

function isinrange(idx, pos, x, Δx)
    1 <= idx <= length(pos) || return false
    abs(pos[idx] - x) <= Δx
end
