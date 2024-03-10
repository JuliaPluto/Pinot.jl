"""
Helpers to work with UTF-16 codepoint indices on **valid** UTF-8 backed strings.
"""
module Unicode

# Returns the number of UTF-16 codepoints associated with a Julia Char that is assumed valid UTF-8
# the core insight is that UTF-8 and UTF-16 share the same character range for 4 and 2 codepoints
# respectively. That is, 1,2 and 3 bytes characters in UTF-8 will be 1 UTF-16 codepoints whereas
# only 4 bytes UTF-8 characters are 2 UTF-16 codepoints (the range from U+010000 to U+10FFFF).
utf16_size(c) = 1 + (convert(UInt32, c) >= 0x010000)
utf16_ncodeunits(s) = sum(utf16_size, s; init=0)

function utf8_idx(s, u16)
    u16 == 0 && return u16
    i = firstindex(s)
    for c in s
        u16 -= utf16_size(c)
        u16 <= 0 && return i
        i += ncodeunits(c)
    end
    i
end

function utf16_prevind(s, idx)
    idx == 0 && return idx
    u8 = utf8_idx(s, idx)
    u8 == 0 && return 0
    u8 = prevind(s, u8)
    u8 == 0 ? 0 : idx - utf16_size(s[u8])
end

utf16_slice(s, r) = string(utf16_view(s, r))
utf16_view(s, r) = view(s, max(utf8_idx(s, first(r)),firstindex(s)):utf8_idx(s, last(r)))

end # module Unicode
