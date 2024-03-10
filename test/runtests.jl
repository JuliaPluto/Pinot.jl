using Test, Pinot
using Pinot: Delta

include("./quill.jl")

@testset "Delta - compact" begin
    @testset "should remove trailing remain" begin
        @test isempty(Delta.compact([Delta.retain(10)]))
    end

    @testset "should fuse inserts" begin
        @test Delta.compact([
            Delta.insert("hello"),
            Delta.insert(" "),
            Delta.insert("world"),
        ]) == [Delta.insert("hello world")]
    end

    @testset "should fuse deletes" begin
        @test Delta.compact([
            Delta.delete(10),
            Delta.delete(4),
            Delta.retain(5),
        ]) == [Delta.delete(14)]
    end

    @testset "should put inserts before deletes" begin
        @test Delta.compact([
            Delta.delete(2),
            Delta.insert("ok"),
        ]) == [Delta.insert("ok"), Delta.delete(2)]
    end
end

@testset "Delta - apply" begin
    for (sa, sb) in [
        ("hello", "hola"),
        ("🍕", "🍍"),
        ("ok🍍ok🍕", "odsql🍍, sdkdq"),
        ("i like pizza", "you like mezze"),
        ("", "ok"),
        ("ok", ""),
    ]
        ops = Pinot.diff(sa, sb)
        res = Pinot.apply(sa, ops)

        @test res == sb
    end

    @testset "apply empty" begin
        @test Pinot.apply("hello!", Delta.Range[]) == "hello!"
    end

    @test Pinot.apply("a", Pinot.Range[retain(1)]) == "a"
    @test Pinot.apply("", Pinot.Range[]) == ""
    @test Pinot.apply("", [Pinot.retain(0)]) == ""
    @test Pinot.apply("", [Pinot.retain(typemax(UInt32))]) == ""

    @test Pinot.apply("🍕s", [Pinot.retain(3), insert("x")]) == "🍕sx"
end

@testset "Delta - transform position" begin
    text = "hello |how are you?"

    edits = [
        Delta.retain(3),
        Delta.insert("lo"),
        Delta.delete(2),
        Delta.insert(" bob,"),
    ]

    pos = findfirst(==('|'), text)
    text_no_pos = filter(!=('|'), text)

    new_pos = Delta.transform_position(edits, pos)

    new_text = Delta.apply(text_no_pos, edits)
    @test new_text == "hello bob, how are you?"

    new_text_with_pos = new_text[begin:prevind(new_text,new_pos)] * '|' * new_text[new_pos:end]
    @test new_text_with_pos == "hello bob, |how are you?"

    @test Delta.transform_position(Delta.Range[], 0) == 0
    @test Delta.transform_position(Delta.Range[insert("a")], 0) == 1
    @test Delta.transform_position(Delta.Range[retain(1), delete(1), insert("a")], 2) == 2
end

@testset "Delta - invert" begin
    text = "hello"
    edits = [
        Delta.retain(4),
        Delta.delete(1),
        Delta.insert("a"),
    ]
    new_text = Delta.apply(text, edits)
    @test text == Delta.apply(new_text, Delta.invert(text, edits))
end

@testset "Delta - internal OpIterator" begin
    it = Delta.OpIterator([Delta.insert("hello")])
    op, new_it = Delta.next(it, 3)

    @test op.type == Delta.Insert
    @test op.insert == "hel"
    
    op, new_it = Delta.next(new_it)
    @test op.type == Delta.Insert
    @test op.insert == "lo"

    @test Delta.peek_type(new_it) == Delta.Retain
end

@testset "README.md example" begin
    initial_text = """
    this is a shared document.
    """

    edits_a = [
        Pinot.retain(10),
        Pinot.insert("cool "),
    ]

    text_a = Pinot.apply(initial_text, edits_a)

    @test text_a == """
    this is a cool shared document.
    """

    edits_b = [
        Pinot.retain(10),
        Pinot.delete(6),
        Pinot.insert("collaborative"),
    ]

    @test Pinot.apply(initial_text, edits_b) == """
    this is a collaborative document.
    """

    edits_b_a = Pinot.transform(edits_a, edits_b, Delta.Left)

    final_text = """
    this is a cool collaborative document.
    """
    @test Pinot.apply(text_a, edits_b_a) == final_text

    @test Pinot.apply(initial_text, Delta.compose(edits_a, edits_b_a)) == final_text
end

@testset "Fuzz" begin
    for i in 1:10
        @testset let l = rand(10:30),
            l1 = rand(10:30),
            l2 = rand(10:30),
            s = join(rand(('a':'z') ∪ ('A':'Z') ∪ ('🍍':'😎') ∪ ('γ':-1:'α'), l)),
            s1 = join(rand(('a':'z') ∪ ('A':'Z') ∪ ('🍍':'😎') ∪ ('γ':-1:'α'), l1)),
            s2 = join(rand(('a':'z') ∪ ('A':'Z') ∪ ('🍍':'😎') ∪ ('γ':-1:'α'), l2)),
            e1 = Pinot.diff(s,s1),
            e2 = Pinot.diff(s,s2)
 
            @test s1 == Pinot.apply(s, e1)
            @test s2 == Pinot.apply(s, e2)
            @test Pinot.apply(s1, Pinot.transform(e1,e2,Pinot.Left)) ==
                  Pinot.apply(s2, Pinot.transform(e2,e1,Pinot.Right))
        end
    end
end
