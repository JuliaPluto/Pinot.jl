module Delta
# References
# https://github.com/codemirror/collab/blob/main/src/collab.ts
# https://codemirror.net/examples/collab/
# https://github.com/livebook-dev/livebook/blob/main/lib/livebook/delta.ex
# https://www.npmjs.com/package/quill-delta

import ..Unicode

@enum RangeType Insert Retain Delete

"""
    retain(n) -> Range
    insert(s) -> Range
    delete(n) -> Range

The primitive type to describe a change. A vector of `Range`
represents a [Delta](https://www.npmjs.com/package/quill-delta).

!!! warning
    The length of range represents the number of utf16 codepoints.
    This is because the Delta format is meant to interoperate with Javascript which uses
    UTF16 encoding for its string encoding.
"""
struct Range
    type::RangeType
    length::UInt32
    insert::Union{Nothing,String} # for inserts
end

"""
    retain(l::Integer) -> Range

Retains `l` utf16 codepoints in the starting document.
"""
retain(l) = Range(Retain, l, nothing)

"""
    retain(s::String) -> Range

Creates a range that retains the same length as `s`.
"""
retain(s::Union{String,SubString{String}}) = retain(Unicode.utf16_ncodeunits(s))

"""
    insert(s::String) -> Range

Insertions of string `s`.
"""
insert(s) = Range(Insert, Unicode.utf16_ncodeunits(s), s)

"""
    delete(l::Integer) -> Range

Deletes `l` utf16 codepoints from the starting document.
"""
delete(l) = Range(Delete, l, nothing)

"""
    delete(s::String) -> Range

Creates a range that deletes the same length as `s`.
"""
delete(s::Union{String,SubString{String}}) = delete(Unicode.utf16_ncodeunits(s))

Base.show(io::IO, r::Delta.Range) = begin
    if r.type == Delta.Insert
        show(io, Delta.insert)
        print(io, "(")
        show(io, r.insert)
        print(io, ")")
    else
        show(io, r.type == Delta.Retain ? Delta.retain : Delta.delete)
        print(io, "(")
        show(io, r.length)
        print(io, ")")
    end
end

function retain!(ranges, n)
    if !isempty(ranges) && last(ranges).type == Retain
        ranges[end] = retain(ranges[end].length + n)
    else
        push!(ranges, retain(n))
    end
    ranges
end

"""
    invert(text, ops::Vector{Range}) -> Vector{Range}

Given a set of edits on a text, produce the inverse set of edits.

```julia
Pinot.apply(Pinot.apply(text, edits), Pinot.inverse(edits)) == text
``` 
"""
function invert(text, ops::Vector{Range})
    out = similar(ops)

    offset = firstindex(text)
    for (i, op) in enumerate(ops)
        if op.type == Retain
            out[i] = retain(op.length)
            offset += op.length
        elseif op.type == Insert
            out[i] = delete(op.length)
        elseif op.type == Delete
            r = offset:Unicode.utf16_prevind(text, offset+op.length)
            text_to_insert = Unicode.utf16_slice(text, r)
            out[i] = insert(text_to_insert)
            offset += op.length
        end
    end

    out
end

# ---

struct OpIterator
    r::Vector{Range}
    i::UInt32 # op index
    ℓ::UInt32 # consumed length in r[i]
end
OpIterator(r) = OpIterator(r, firstindex(r), zero(UInt32))

function peek_length(it::OpIterator)
    it.i > lastindex(it.r) && return typemax(UInt32)
    op = it.r[it.i]
    op.length - it.ℓ
end
function peek_type(it::OpIterator)
    it.i > lastindex(it.r) && return Retain
    op = it.r[it.i]
    op.type
end

function has_next(it::OpIterator)
    it.i <= lastindex(it.r)
end

function next(it::OpIterator, ℓ=nothing)
    it.i > lastindex(it.r) && return Range(Retain, something(ℓ, typemax(UInt32)), nothing), it
    op = it.r[it.i]
    if op.type == Insert
        ℓ = isnothing(ℓ) ? peek_length(it) : ℓ
        new_insert = Unicode.utf16_slice(op.insert, 1+it.ℓ:it.ℓ+ℓ)
        r = insert(new_insert)

        ni, nℓ = it.i, it.ℓ + ℓ
        if it.ℓ + ℓ == op.length # move to next
            ni += 1
            nℓ = 0
        end
        return r, OpIterator(it.r, ni, nℓ)
    end
    ty = op.type
    ℓ = isnothing(ℓ) ? peek_length(it) : ℓ
    ni, nℓ = it.i, it.ℓ + ℓ
    r = Range(ty, ℓ, nothing)
    if it.ℓ + ℓ == op.length # move to next
        ni += 1
        nℓ = 0
    end
    r, OpIterator(it.r, ni, nℓ)
end

# ---

@enum Priority Left Right

"""
    transform(a::Vector{Range}, b::Vector{Range}, priority=Left) -> Vector{Range}

Produces a version of `b` transformed over `a` such that:

```julia
Pinot.apply(Pinot.apply(text, a), Pinot.transform(a, b, Pinot.Left)) ==
    Pinot.apply(Pinot.apply(text, b), Pinot.transform(b, a, Pinot.Right))
```

`priority` is used to indicate which change happened before in conflict resolution.
"""
function transform(a, b, priority=Left)
    out = Range[]

    before = priority === Left

    itA = OpIterator(a)
    itB = OpIterator(b)

    while has_next(itA) || has_next(itB)
        if peek_type(itA) == Insert && (before || peek_type(itB) != Insert)
            ca, itA = next(itA)
            retain!(out, Unicode.utf16_ncodeunits(ca.insert))
        elseif peek_type(itB) == Insert
            cb, itB = next(itB)
            push!(out, cb)
        else
            # ca, cb are either Retain or Delete
            ℓ = min(peek_length(itA), peek_length(itB))

            if peek_type(itA) == Delete
                # our delete either makes their delete redundant or removes their retain
            elseif peek_type(itB) == Delete
                push!(out, delete(ℓ))
            else
                # ca and cb are Retain
                retain!(out, ℓ)
            end

            _, itA = next(itA, ℓ)
            _, itB = next(itB, ℓ)
        end
    end

    out
end

"""
    compose(a::Vector{Range}, b::Vector{Range}) -> Vector{Range}

Returns a set of changes equivalent to sequentially applying `a` then `b`.

```julia
Pinot.apply(Pinot.apply(text, a), b) ==
    Pinot.apply(text, Pinot.compose(a, b))
```
"""
function compose(a, b)
    out = Range[]

    itA = OpIterator(a)
    itB = OpIterator(b)

    while has_next(itA) || has_next(itB)
        if peek_type(itB) == Insert # inserts in B are unconditional
            cb, itB = next(itB)
            push!(out, cb)
        elseif peek_type(itA) == Delete # deletes in A are unconditional
            ca, itA = next(itA)
            push!(out, ca)
        else
            ℓ = min(peek_length(itA), peek_length(itB))
            ca, itA = next(itA, ℓ)
            cb, itB = next(itB, ℓ)
            if cb.type == Retain
                push!(out, ca)
            elseif cb.type == Delete && ca.type == Retain
                push!(out, cb)
            end
        end
    end

    out
end

"""
    apply(text::String, ranges::Vector{Range}) -> String

Applies the changes to a text.
"""
function apply(s::String, ranges::Vector{Range})
    out = SubString{String}[]
    current_pos = firstindex(s)

    N = Unicode.utf16_ncodeunits(s)

    for r in ranges
        if r.type == Retain
            i = min(N, Unicode.utf16_prevind(s, current_pos + r.length))
            # @show s N i current_pos
            v = Unicode.utf16_view(s, current_pos:i)
            # @show v current_pos i r.length
            push!(out, v)
            current_pos += r.length
        elseif r.type == Delete
            current_pos += r.length
        elseif r.type == Insert
            push!(out, r.insert)
        end
    end

    # retain the end
    if current_pos <= N
        push!(out, Unicode.utf16_view(s, current_pos:N))
    end

    join(out)
end

"""
    transform_position(ops::Vector{Range}, pos) -> Int

Returns a new value for position after applying the changes
described by `ops`. We move the position to the right of an
insert.

```julia
julia> Pinot.transform_position([retain(1), insert("a")], 1) == 2
true
```
"""
function transform_position(ops::Vector{Range}, pos)
    # offset is current position in delta.
    offset = 0
    for op in ops
        offset > pos && return pos

        if op.type == Delete
            pos = max(pos - op.length, offset)
        elseif op.type == Retain
            # does not affect position
            offset += op.length
        elseif op.type == Insert
            # affects both position and offset in delta
            pos += op.length
            offset += op.length
        end
    end

    pos
end

"""
    compact(ops::Vector{Range}) -> Vector{Range}

Returns a compacted set of changes which has the same effects
as `ops`.
"""
function compact(ops::Vector{Range})
    isempty(ops) && return copy(ops)

    out = Vector{Range}()

    i = firstindex(ops)
    while i <= lastindex(ops)
        op = ops[i]

        if !isempty(out)
            prev = last(out)
            if op.type == Retain && prev.type == Retain
                out[end] = retain(prev.length + op.length)
            elseif op.type == Delete && prev.type == Delete
                out[end] = delete(prev.length + op.length)
            elseif op.type == Insert && prev.type == Insert
                out[end] = insert(prev.insert * op.insert)
            elseif op.type == Insert && prev.type == Delete
                # Normalize by putting inserts before deletes
                out[end] = op
                push!(out, prev)
            else
                push!(out, op)
            end
        else
            push!(out, op)
        end

        i = nextind(ops, i)
    end

    while !isempty(out) && last(out).type == Retain
        pop!(out)
    end

    out
end

# --- Js serialization ---

function to_obj(op::Range)
    if op.type == Retain
        (; retain=op.length)
    elseif op.type == Delete
        (; delete=op.length)
    elseif op.type == Insert
        (; insert=op.insert::String)
    end
end

function to_obj(ops::Vector{Range})
    ops = map(to_obj, ops)
    (; ops=ops)
end

function from_obj(obj)
    ops = obj["ops"]
    map(ops) do op
        if haskey(op, "retain")
            retain(op["retain"])
        elseif haskey(op, "delete")
            delete(op["delete"])
        elseif haskey(op, "insert")
            insert(op["insert"])
        else
            error("invalid op $op")
        end
    end
end

export apply, invert, delete, retain, insert, compose, transform, transform_position, compact

end # module Delta
