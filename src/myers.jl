module Diff

import ..Pinot: Delta, Unicode

"""
    diff(a::String, b::String) -> Vector{Pinot.Range}

An implementation of the Myers algorithm as proposed in [1].

[1]E. Myers (1986). "An O(ND) Difference Algorithm and Its Variations".
    Algorithmica. 1 (2): 251–266. doi:10.1007/BF01840446. S2CID 6996809.
"""
function diff(a, b)
    isempty(a) && return Delta.Range[Delta.insert(b)]
    isempty(b) && return Delta.Range[Delta.delete(Unicode.utf16_ncodeunits(a))]

    trace = ses(a, b)
    moves = backtrack(trace, a, b)
    Delta.compact(apply_edits(moves, a, b))
end

function ses(a, b)
    N = length(a)
    M = length(b)
    max = N + M

    # Trace is a path through the graph
    trace = Vector{Int}[]
    v = zeros(Int, 2*max+2)

    for d in 0:max
        push!(trace, copy(v))
        for k in -d:2:d
            x = if k == -d || (k != d && v[k+max] < v[k+2+max])
                v[k+2+max]
            else
                v[k+max]+1
            end
            y = x - k

            #TODO: this nextind perf must be high since we start from the beginning
            while x < N && y < M && a[nextind(a,1,x)] == b[nextind(b,1,y)]
                x += 1
                y += 1
            end

            v[k+max+1] = x

            if x >= N && y >= M
                return trace
            end
        end
    end
    throw("length of a ses is greater than max")
end

function backtrack(trace, a, b)
    x, y = length(a), length(b)
    max = length(a) + length(b)

    moves = Tuple{Int,Int,Int,Int}[]
    for (d,v) in Iterators.reverse(enumerate(trace))
        d = d-1
        k = x - y

        prev_k = if k == -d || (k != d && v[k+max] < v[k+2+max])
            k + 1
        else
            k - 1
        end
        prev_x = v[prev_k+1+max]
        prev_y = prev_x - prev_k

        while x > prev_x && y > prev_y
            push!(moves, (x-1, y-1, x, y))
            x, y = x - 1, y - 1
        end

        d > 0 && push!(moves, (prev_x, prev_y, x, y))

        x, y = prev_x, prev_y
    end

    moves
end

function apply_edits(moves, a, b)
    diffs = Delta.Range[]
    for (prev_x, prev_y, x, y) in reverse(moves)
        a_line = get(a, nextind(a,0,prev_x+1), a[1])
        b_line = get(b, nextind(b,0,prev_y+1), a[1])

        if x == prev_x
            push!(diffs, Delta.insert(string(b_line)))
        elseif y == prev_y
            push!(diffs, Delta.delete(Unicode.utf16_size(a_line)))
        else
            push!(diffs, Delta.retain(Unicode.utf16_size(b_line)))
        end
    end

    diffs
end

export diff

end # module Diff
