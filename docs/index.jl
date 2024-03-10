### A Pluto.jl notebook ###
# v0.19.41

using Markdown
using InteractiveUtils

# ╔═╡ 00289434-0de8-11ef-2d46-090e108db876
# ╠═╡ show_logs = false
begin
	import Pkg
	Pkg.develop(path="..")
	Pkg.add("PlutoUI")
end

# ╔═╡ 753f58db-33ed-4d95-b1b8-f1961a1e92b8
using Pinot

# ╔═╡ 2fc12db6-b3b9-4d15-adc8-98e50a328c68
using PlutoUI

# ╔═╡ 608e97bb-c538-4f0e-9ba0-f450abe975ea
md"""
# Pinot.jl
"""

# ╔═╡ aedbe996-1c65-4c47-a1ff-4dbaf46d1615
md"""
Pinot is a Julia package to perform [Operational Transformation](https://en.wikipedia.org/wiki/Operational_transformation). That is, it offers tools to describe and reconcile plain-text edits to implement collaborative text editing features. Pinot is based on the [Delta format](https://quilljs.com/docs/delta/) to describe documents and edits. 

A Delta is a series of edits, which can be one of the following three sorts:

 - retain
 - insert
 - delete
"""

# ╔═╡ 96f3ee4e-6042-43ec-aae9-1f88defac9fa
md"""
## Describing edits
"""

# ╔═╡ e7f2f5d0-7236-4613-888d-6df27cfb247c
retain(4)

# ╔═╡ 2ee17e6c-87ea-4dce-b08f-802a1496b8bc
delete(3)

# ╔═╡ 1a361814-537c-4360-86f9-200a38bd1536
insert("ok")

# ╔═╡ 73bfd292-f5e5-4e80-a473-e75ed1034304
Docs.Binding(Pinot, :retain)

# ╔═╡ 87add6ba-5a2c-49ee-8d9e-7bddccfe66f3
let text = "Hello",
 	changes = [Pinot.retain(text)]
	Pinot.apply(text, changes)
end

# ╔═╡ 3439fb92-0784-4804-9c00-96caca2c002f
Docs.Binding(Pinot, :insert)

# ╔═╡ f984541f-40d4-46ec-8098-260401c72dd6
let text = "Hello",
 	changes = [
		Pinot.retain(5),
		Pinot.insert(" World!"),
	]
	Pinot.apply(text, changes)
end

# ╔═╡ 3f5f710c-c9b5-46ad-9aa3-ffc122c4c1c5
Docs.Binding(Pinot, :delete)

# ╔═╡ 91546608-bb22-4a8f-8cbc-aaf6d41aadd0
let text = "Hello",
	changes = [
		Pinot.delete(5),
	]
	Pinot.apply(text, changes)
end

# ╔═╡ 7a7d91d3-c3b0-4713-a10b-36b2b81f2978
md"""
!!! warning
	The length of range represents the number of utf16 codepoints.
	This is because the Delta format is meant to interoperate with Javascript which uses UTF16 encoding for its string encoding.
"""

# ╔═╡ 286712bd-0d7c-46b1-b445-e7d206a5e03b
Docs.Binding(Pinot, :Unicode)

# ╔═╡ 4471a2cb-62be-4359-8d37-9e2a81e0ea6d
md"""
Notice the difference in the following example when using the `ncodeunits(::Char)` base function which returns the number of UTF-8 codeunits. Using `Pinot.Unicode.utf16_ncodeunits(::String)` is required instead to have the right delta length.
"""

# ╔═╡ 0c941e14-0d18-4a73-9956-69893d024dfe
let text = "🍕 is great",
	changes = [
		Pinot.retain(ncodeunits('🍕')),
		Pinot.insert("🍍"),
	]
	Pinot.apply(text, changes)
end

# ╔═╡ c280a351-2afa-4f4e-8672-2a779ab78f7f
let text = "🍕 is great",
	changes = [
		Pinot.retain(Pinot.Unicode.utf16_ncodeunits('🍕')),
		Pinot.insert("🍍"),
	]
	Pinot.apply(text, changes)
end

# ╔═╡ cb211736-7844-457b-9f1d-e9a12694dce3
md"""
Throughout this section, we have been using the `Pinot.apply(::String, ::Vector{Range})::String` function which applies a set of edits to a string.
"""

# ╔═╡ ba9390df-5be6-4fe8-b5be-4f32a8392d40
Docs.Binding(Pinot, :apply)

# ╔═╡ 0a66aad8-1c36-40d8-8f40-f816e8496774
md"""
## Operational Transformation
"""

# ╔═╡ 322ed9ad-e89c-44f7-bd80-e5c56bc051a9
md"""
The main goal with Operational Transformation is to resolve conflicts between changes which have happened from the same starting documents and make all clients editing the document converge to the same final document.

Consider a document `A`, with two clients editing it concurrently. Client 1 produces `A₁` and Client 2 produces `A₂`.

```
A--C₁-->A₁
└--C₂-->A₂
```
"""

# ╔═╡ 8473ef3f-6262-40ca-9b41-2e32d0a48a95
Docs.Binding(Pinot, :transform)

# ╔═╡ a897ab14-cb68-4868-9be4-2495ba125450
A = "this is the initial document"

# ╔═╡ f5fcb583-0035-45e8-bf0d-e5a1f332cb1a
C₁ = [
	retain("this is the "),
	delete("initial "),
	retain("document"),
	insert(" produced by C₁"),
]

# ╔═╡ 30bf8640-67b6-4c47-ab23-ecee6f177d77
A₁ = apply(A, C₁)

# ╔═╡ 40bc82cd-bb4d-4153-abd8-3966b26a5747
C₂ = [
	retain("this is the "),
	delete("initial "),
	retain("document"),
	insert(" produced by C₂"),
]

# ╔═╡ aa02313c-1357-4058-9ec9-263fe8a8e8b9
A₂ = apply(A, C₂)

# ╔═╡ 4b6b3609-55a7-4fa1-8d41-0191e3c25f1c
md"""
Now let's consider that `C₂` sends its changes over to `C₁`, we want to transform `C₂` so that it starts from `A₁` instead of `A`.

```
A--C₁-->A₁--C₂′-->A₁₂
```

!!! note
	`transform` takes a third argument to indicate which set of edits logically happened before, this is used to prioritize one change-set over the other in ambiguous cases (ex: 2 inserts at the same position).
"""

# ╔═╡ 85d1f091-568c-4797-acd5-497df27880fd
C₂′ = transform(C₁, C₂, Pinot.Left)

# ╔═╡ 7a54928d-7062-4f14-859d-f97132b75c5a
A₁₂ = apply(A₁, C₂′)

# ╔═╡ 63a7a5a2-e88f-4115-a673-5faf8797477a
md"""
Reciprocally, `C₁` can send its changes over to `C₂` and we want to do a similar transformation to produce `A₂₁` from `C₁′`.

```
A--C₂-->A₂--C₁′-->A₂₁
```
"""

# ╔═╡ 6663a046-0a37-456a-bbbf-aa8ac5fa46fe
C₁′ = transform(C₂, C₁, Pinot.Right)

# ╔═╡ e36daba0-5c33-4ccc-bd84-4c4bb290f3a7
A₂₁ = apply(A₂, C₁′)

# ╔═╡ 49fac7e6-a0c2-447c-ba41-b73af0fe9ae9
md"""
We can now see that the transformation made the two clients converge to the same document.
"""

# ╔═╡ 56a28ee3-c0b7-4413-b03f-c330ccca1328
A₁₂ == A₂₁

# ╔═╡ 3420f9ae-4542-4de3-bff5-85b08cceea94
md"""
The `transform_position` function indicates how a position in a document would be moved after applying a set of edits.
"""

# ╔═╡ 3d37ac51-348c-4dca-b5b2-3ec832e702c8
transform_position([insert("hello")], 1)

# ╔═╡ dc112672-1745-4b8c-9d69-a59c8f0523e3
transform_position([delete(3)], 4)

# ╔═╡ 0b4cf99a-dca9-43dd-be59-020c5a49c274
transform_position([retain(10), insert("ok")], 5)

# ╔═╡ 5162f0db-8246-463c-a941-a1a7d9d300f6
Docs.Binding(Pinot, :transform_position)

# ╔═╡ d80c1335-9e40-4e2f-997e-bfe8e16a5d18
md"""
## Composition

We have seen that edits describe a change in the document and edits can be used to go from one state of a document to another. Composition can be used to combine two consecutive change-sets in a single one.
"""

# ╔═╡ a0df881d-2ed1-491b-bc18-02f6766c34c0
apply(A, compose(C₁, C₂′)) == A₁₂

# ╔═╡ 2717c757-e5b1-46cd-8454-d830b19109ce
Docs.Binding(Pinot, :compose)

# ╔═╡ f77372a7-a8ea-4bf4-bcce-bf392920149b
md"""
## Inversion

The inverse of a change set can be produce with the `invert` function which also requires the document state before this edit (so that deletes can become inserts).
"""

# ╔═╡ 1eb1a0bf-cc5e-4d4e-8a64-9b05f7965d60
apply(A₁, invert(A, C₁))

# ╔═╡ cfc29183-c12a-41c2-80b7-8a6e8a56a38a
Docs.Binding(Pinot, :invert)

# ╔═╡ 747c9f89-945f-4d5d-9b93-376f87f54818
md"""
## Compactions

Some change descriptions can contain superfluous elements which can be compacted.

Notice how the consecutive edits are merged and the trailing retain is removed as it is not required per the Delta specification:
"""

# ╔═╡ cb25b8f1-9baf-4d07-b815-bb5ff338f07c
Pinot.compact([
	Pinot.insert("a"),
	Pinot.insert("b"),
	Pinot.insert("c"),
	Pinot.delete(1),
	Pinot.delete(2),
	Pinot.retain(1),
])

# ╔═╡ 484f09f2-ed5c-449d-977a-48e211782703
Docs.Binding(Pinot, :compact)

# ╔═╡ 24037413-f4b0-4414-82a2-9120e063e705
md"""
---
"""

# ╔═╡ f7c8608a-b299-4948-84ff-59ce466490aa
TableOfContents(include_definitions=true)

# ╔═╡ dd3e5a52-32e2-4d5f-a9b4-e36eb4987adf


# ╔═╡ Cell order:
# ╟─608e97bb-c538-4f0e-9ba0-f450abe975ea
# ╠═753f58db-33ed-4d95-b1b8-f1961a1e92b8
# ╟─aedbe996-1c65-4c47-a1ff-4dbaf46d1615
# ╟─96f3ee4e-6042-43ec-aae9-1f88defac9fa
# ╠═e7f2f5d0-7236-4613-888d-6df27cfb247c
# ╠═2ee17e6c-87ea-4dce-b08f-802a1496b8bc
# ╠═1a361814-537c-4360-86f9-200a38bd1536
# ╟─73bfd292-f5e5-4e80-a473-e75ed1034304
# ╠═87add6ba-5a2c-49ee-8d9e-7bddccfe66f3
# ╟─3439fb92-0784-4804-9c00-96caca2c002f
# ╠═f984541f-40d4-46ec-8098-260401c72dd6
# ╟─3f5f710c-c9b5-46ad-9aa3-ffc122c4c1c5
# ╠═91546608-bb22-4a8f-8cbc-aaf6d41aadd0
# ╟─7a7d91d3-c3b0-4713-a10b-36b2b81f2978
# ╟─286712bd-0d7c-46b1-b445-e7d206a5e03b
# ╟─4471a2cb-62be-4359-8d37-9e2a81e0ea6d
# ╠═0c941e14-0d18-4a73-9956-69893d024dfe
# ╠═c280a351-2afa-4f4e-8672-2a779ab78f7f
# ╟─cb211736-7844-457b-9f1d-e9a12694dce3
# ╟─ba9390df-5be6-4fe8-b5be-4f32a8392d40
# ╟─0a66aad8-1c36-40d8-8f40-f816e8496774
# ╟─322ed9ad-e89c-44f7-bd80-e5c56bc051a9
# ╟─8473ef3f-6262-40ca-9b41-2e32d0a48a95
# ╠═a897ab14-cb68-4868-9be4-2495ba125450
# ╠═f5fcb583-0035-45e8-bf0d-e5a1f332cb1a
# ╠═30bf8640-67b6-4c47-ab23-ecee6f177d77
# ╠═40bc82cd-bb4d-4153-abd8-3966b26a5747
# ╠═aa02313c-1357-4058-9ec9-263fe8a8e8b9
# ╟─4b6b3609-55a7-4fa1-8d41-0191e3c25f1c
# ╠═85d1f091-568c-4797-acd5-497df27880fd
# ╠═7a54928d-7062-4f14-859d-f97132b75c5a
# ╟─63a7a5a2-e88f-4115-a673-5faf8797477a
# ╠═6663a046-0a37-456a-bbbf-aa8ac5fa46fe
# ╠═e36daba0-5c33-4ccc-bd84-4c4bb290f3a7
# ╟─49fac7e6-a0c2-447c-ba41-b73af0fe9ae9
# ╠═56a28ee3-c0b7-4413-b03f-c330ccca1328
# ╟─3420f9ae-4542-4de3-bff5-85b08cceea94
# ╠═3d37ac51-348c-4dca-b5b2-3ec832e702c8
# ╠═dc112672-1745-4b8c-9d69-a59c8f0523e3
# ╠═0b4cf99a-dca9-43dd-be59-020c5a49c274
# ╟─5162f0db-8246-463c-a941-a1a7d9d300f6
# ╟─d80c1335-9e40-4e2f-997e-bfe8e16a5d18
# ╠═a0df881d-2ed1-491b-bc18-02f6766c34c0
# ╟─2717c757-e5b1-46cd-8454-d830b19109ce
# ╟─f77372a7-a8ea-4bf4-bcce-bf392920149b
# ╠═1eb1a0bf-cc5e-4d4e-8a64-9b05f7965d60
# ╟─cfc29183-c12a-41c2-80b7-8a6e8a56a38a
# ╟─747c9f89-945f-4d5d-9b93-376f87f54818
# ╠═cb25b8f1-9baf-4d07-b815-bb5ff338f07c
# ╟─484f09f2-ed5c-449d-977a-48e211782703
# ╟─24037413-f4b0-4414-82a2-9120e063e705
# ╟─00289434-0de8-11ef-2d46-090e108db876
# ╟─2fc12db6-b3b9-4d15-adc8-98e50a328c68
# ╟─f7c8608a-b299-4948-84ff-59ce466490aa
# ╟─dd3e5a52-32e2-4d5f-a9b4-e36eb4987adf
