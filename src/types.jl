struct BoundingBox{N,T}
    intervals::NTuple{N,ClosedInterval{T}}
end

BoundingBox(left::NTuple{N,T}, right::NTuple{N,T}) where {N,T<:Real} =
    BoundingBox(map((l, r) -> l..r, left, right))

BoundingBox(left::CartesianIndex, right::CartesianIndex) =
    BoundingBox(left.I, right.I)

Base.:(|)(bb::BoundingBox, I::CartesianIndex) =
    BoundingBox(map((iv, i) -> min(minimum(iv), i)..max(maximum(iv), i),
                    bb.intervals, I.I))

Statistics.middle(bb::BoundingBox) = map(iv->(minimum(iv)+maximum(iv))/2, bb.intervals)

buffer(bb::BoundingBox, l) = BoundingBox(map(iv -> minimum(iv)-l .. maximum(iv)+l, bb.intervals))
