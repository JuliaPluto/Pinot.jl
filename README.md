# Pinot.jl

An implementation of [Operational Transform](https://en.wikipedia.org/wiki/Operational_transformation) for plain text documents using the [Delta format](http://quilljs.com/docs/delta/).

### Example

```julia
using Pinot, Test

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

edits_b_a = Pinot.transform(edits_a, edits_b, Pinot.Left)

@test Pinot.apply(text_a, edits_b_a) == """
this is a cool collaborative document.
"""
```
