using JSON3, Deno_jll

function send_command!(p, cmd)
    write(p, JSON3.write(cmd))
    write(p, '\n')
    JSON3.read(readuntil(p, '\n'))
end

launch() = open(`$(deno()) run $(joinpath(@__DIR__, "quill.js"))`; write=true, read=true)
function quill_transform(p, text, a, b; priority=:left)
    res = send_command!(p, (;
        header="transform", priority=priority === Delta.Left,
        text, a=Delta.to_obj(a), b=Delta.to_obj(b)))
    res[:newtext], Delta.from_obj(res[:ops])
end

@testset "Delta - JS interop" begin
    p = launch()

    edits_a = [Delta.retain(5)]
    edits_b = [Delta.delete(2)]

    edits_b_a = Delta.transform(edits_a, edits_b, :right)

    text = "hello"
    newtext, expected = quill_transform(p, text, edits_a, edits_b)
    @test newtext == Pinot.apply(Pinot.apply(text, edits_a), edits_b_a)
    @test expected == Delta.compact(edits_b_a)

    text = "🌅 this is operational transform"
    text_a = "this is optimal transport 🚚"
    text_b = "there is operational transform 🌐"

    edits_a = Pinot.diff(text, text_a)
    edits_b = Pinot.diff(text, text_b)

    edits_b_a = Pinot.transform(edits_a, edits_b, Delta.Left) |> Pinot.compact
    newtext, expected = quill_transform(p, text, edits_a, edits_b; priority=Pinot.Delta.Left)
    @test newtext == Pinot.apply(text_a, edits_b_a)
    @test Delta.compact(edits_b_a) == expected
end
