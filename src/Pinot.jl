module Pinot

include("./unicode.jl")
include("./delta.jl")
include("./myers.jl")

using .Unicode: utf16_ncodeunits
using .Delta: retain, insert, delete, apply, compact, invert,
              compose, transform, transform_position, Left, Right, Range,
              to_obj, from_obj
using .Diff: diff

export retain, insert, delete, apply, compact, invert, compose, transform, transform_position
# public Range, Left, Right, to_obj, from_obj

end # module Pinot
