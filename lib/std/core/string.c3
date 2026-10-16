module std::core::string;
import std::io, std::math;
import std::core::string::conv;

<*
 String is a slice of UTF-8 encoded chars. It is not necessarily zero terminated.

 String literals convert to String implicitly, and are zero terminated, so a literal
 can safely be cast to a ZString.
*>
typedef String @constinit @weak = inline char[];
<*
 ZString is a pointer to a zero terminated array of chars.

 Use ZString when you need to interop with C zero terminated strings.
*>
typedef ZString @constinit = inline char*;

<*
 WString is a pointer to a zero terminated array of Char16.

 Depending on the platform, this may or may not correspond to wchar_t.
 For Windows, wchar_t is generally 16 bits, on MacOS it is 32 bits.
 However, for both MacOS and Linux, regular C strings (ZString)
 will be UTF-8 encoded, so there is no need to use the wchar_t versions
 of functions outside of encoding functions.
*>
typedef WString @constinit = inline Char16*;

<*
 Char32 is a UTF32 codepoint
*>
alias Char32 = uint;

<*
 Char16 is a UTF16 "character"
*>
alias Char16 = ushort;

<*
 Common faults used with strings
*>
excuse
{
	INVALID_UTF8, INVALID_UTF16, CONVERSION_FAILED,
	EMPTY_STRING, NEGATIVE_VALUE, MALFORMED_INTEGER,
	INTEGER_OVERFLOW, MALFORMED_FLOAT, FLOAT_OUT_OF_RANGE
}


<*
 Create a pointer to an UTF32 encoded string at compile time.

 #### Example:
 ```
 Char32* s = @wstring32("héllo");
 ```

 @param $string : "The string to encode"
 @return "A pointer to the zero terminated UTF32 data"
*>
macro Char32* @wstring32(String $string) @builtin
{
	return (Char32*)&&$$wstr32($string);
}

<*
 Create a slice of an UTF32 encoded string at compile time.

 #### Example:
 ```
 Char32[] s = @char32("héllo"); // s.len == 5
 ```

 @param $string : "The string to encode"
 @return "The UTF32 codepoints, not including the zero terminator"
*>
macro Char32[] @char32(String $string) @builtin
{
	return $$wstr32($string)[..^2];
}

<*
 Create a WString (an UTF16 encoded string) at compile time.

 #### Example:
 ```
 WString s = @wstring("hello");
 ```

 @param $string : "The string to encode"
 @return "A pointer to the zero terminated UTF16 data"
*>
macro WString @wstring(String $string) @builtin
{
	return (WString)&&$$wstr16($string);
}

<*
 Create a slice of an UTF16 encoded string at compile time.

 #### Example:
 ```
 Char16[] s = @char16("hello"); // s.len == 5
 ```

 @param $string : "The string to encode"
 @return "The UTF16 units, not including the zero terminator"
*>
macro Char16[] @char16(String $string) @builtin
{
	return $$wstr16($string)[..^2];
}

<*
 Create a compile-time formatted string constant.

 #### Example:
 ```
 String s = @sprintf("%s-%d", "abc", 3); // "abc-3"
 ```

 @param $format : "The compile-time format string"
 @return "The formatted string, computed at compile time"
*>
macro String @sprintf(String $format, ...) @builtin @const
{
	return $$sprintf($format, ...$vaarg);
}
<*
 Return a temporary ZString created using the formatting function.

 #### Example:
 ```
 ZString z = string::tformat_zstr("%d items", 3); // "3 items"
 ```

 @param [in] fmt : `The formatting string`
 @return "A zero terminated string allocated on the temp allocator"
*>
fn ZString tformat_zstr(String fmt, args...) @format(0)
{
	DString str = dstring::temp_with_capacity(fmt.len + args.len * 8);
	str.appendf(fmt, ...args);
	return str.zstr_view();
}

<*
 Return a new String created using the formatting function.

 The string is first built on the temp allocator (inside a `@pool`), then copied to `allocator`.

 #### Example:
 ```
 String s = string::format(mem, "%s=%d", "x", 42); // "x=42"
 defer free(s);
 ```

 @param [&inout] allocator : `The allocator to use`
 @param [in] fmt : `The formatting string`
 @return "The formatted string, safe to convert to a ZString"
*>
fn String format(Allocator allocator, String fmt, args...) @format(1) => @pool()
{
	DString str = dstring::temp_with_capacity(fmt.len + args.len * 8);
	str.appendf(fmt, ...args);
	return str.copy_str(allocator);
}

<*
 Return a new String created using the formatting function, writing into the given buffer.

 The result must fit the buffer, otherwise this panics. No zero terminator is added.

 #### Example:
 ```
 char[32] buf;
 String s = string::bformat(&buf, "%d + %d", 1, 2); // "1 + 2"
 ```

 @param [inout] buffer : `The buffer to use`
 @param [in] fmt : `The formatting string`
 @return "A slice of the buffer containing the formatted string"
*>
fn String bformat(char[] buffer, String fmt, args...) @format(1)
{
	Formatter f;
	OutputFn format_fn = fn void?(void* buf, char c) {
		char[]* buffer_ref = buf;
		char[] buffer = *buffer_ref;
		if (buffer.len == 0) return io::BUFFER_EXCEEDED~;
		buffer[0] = c;
		*buffer_ref = buffer[1..];
	};
	char[] buffer_copy = buffer;
	f.init(format_fn, &buffer_copy);
	sz len = f.vprintf(fmt, args)!!;
	return (String)buffer[:len];
}

<*
 Return a temporary String created using the formatting function.

 #### Example:
 ```
 String s = string::tformat("%s, %s!", "Hello", "World"); // "Hello, World!"
 ```

 @param [in] fmt : `The formatting string`
 @return "The formatted string allocated on the temp allocator"
*>
fn String tformat(String fmt, args...) @format(0)
{
	DString str = dstring::temp_with_capacity(fmt.len + args.len * 8);
	str.appendf(fmt, ...args);
	return str.str_view();
}

<*
 Check if a character is in a set.

 #### Example:
 ```
 bool b = string::char_in_set('b', "abc"); // true
 ```

 @param c : `the character to check`
 @param [in] set : `String containing the characters`
 @return `True if a character is in the set`
 @pure
*>
macro bool char_in_set(char c, String set)
{
	foreach (ch : set) if (ch == c) return true;
	return false;
}

<*
 Join together an array of strings via a "joiner" sequence, which is inserted between each element.

 An empty array yields an empty (but allocated) string.

 #### Example:
 ```
 String[] parts = { "a", "bb", "ccc" };
 String s = string::join(mem, parts, ", "); // "a, bb, ccc"
 defer s.free(mem);
 ```

 @param [&inout] allocator : "The allocator to use."
 @param [in] s : "An array of strings to join in sequence."
 @param [in] joiner : "The string used to join each element of `s`."
 @return "A single string containing the result, allocated via `allocator`, safe to convert to a ZString."
*>
fn String join(Allocator allocator, String[] s, String joiner)
{
	if (!s)
	{
		return (String)alloc::new_array(allocator, char, 2)[:0];
	}
	sz joiner_len = joiner.len;
	sz total_size = joiner_len * (s.len - 1) + 1;
	foreach (String* &str : s)
	{
		total_size += str.len;
	}
	char[] data = alloc::alloc_array(allocator, char, total_size);
	sz offset = s[0].len;
	data[:offset] = s[0][:offset];
	foreach (String* &str : s[1..])
	{
		data[offset:joiner_len] = joiner[:joiner_len];
		offset += joiner_len;
		sz len = str.len;
		data[offset:len] = str.[:len];
		offset += len;
	};
	data[offset] = 0;
	return (String)data[:offset];
}

<* Alias for `string::join` using the temp allocator. *>
macro String tjoin(String[] s, String joiner) => join(tmem, s, joiner);

<*
 Replace all instances of one substring with a different string.

 #### Example:
 ```
 String s = "a-b-c".replace(mem, "-", "+"); // "a+b+c"
 defer s.free(mem);
 ```

 @param [in] self
 @param [&inout] allocator : `The allocator to use for the String`
 @param [in] needle : `The string to be replaced`
 @param [in] new_str : `The replacement string`
 @return "The new string with the elements replaced"
*>
fn String String.replace(self, Allocator allocator, String needle, String new_str) @nodiscard => @pool()
{
	Splitter s = self.tokenize_all(needle);
	DString d;
	d.init(tmem, new_str.len * 2 + self.len + 16);
	(void)d.append(s.next());
	while (try element = s.next())
	{
		d.append(new_str);
		d.append(element);
	}
	return d.copy_str(allocator);
}

<*
 Replace all instances of one substring with a different string, allocating the new string on the temp allocator.

 #### Example:
 ```
 String s = "some text, some more".treplace("some", "all"); // "all text, all more"
 ```

 @param [in] self
 @param [in] needle : `The string to be replaced`
 @param [in] new_str : `The replacement string`
 @return "The new string with the elements replaced"
*>
fn String String.treplace(self, String needle, String new_str)
{
	Splitter s = self.tokenize_all(needle);
	DString d;
	d.init(tmem, new_str.len * 2 + self.len + 16);
	(void)d.append(s.next());
	while (try element = s.next())
	{
		d.append(new_str);
		d.append(element);
	}
	return d.str_view();
}


<*
 Remove characters from the front and end of a string.

 #### Example:
 ```
 String s = "  hello\n".trim(); // "hello"
 String t = "--x--".trim("-"); // "x"
 ```

 @param [in] self : `The string to trim`
 @param [in] to_trim : `The set of characters to trim, defaults to whitespace`
 @return `a substring of the string passed in`
 @pure
*>
fn String String.trim(self, String to_trim = " \n\t\r\f\v")
{
    return self.trim_left(to_trim).trim_right(to_trim);
}

<*
 Remove characters in an ASCII charset from the front and end of a string.

 #### Example:
 ```
 String s = " \tvalue ".trim_charset(); // "value"
 ```

 @param [in] self : `The string to trim`
 @param to_trim : `The set of characters to trim, defaults to whitespace`
 @return `a substring of the string passed in`
 @pure
*>
fn String String.trim_charset(self, AsciiCharset to_trim = ascii::WHITESPACE_SET)
{
	sz start = 0;
	sz len = self.len;
	while (start < len && to_trim.contains(self[start])) start++;
	while (len > start && to_trim.contains(self[len - 1])) len--;
    return self[start..len - 1];
}

<*
 Remove characters from the front of a string.

 #### Example:
 ```
 String s = "  hello ".trim_left(); // "hello "
 ```

 @param [in] self : `The string to trim`
 @param [in] to_trim : `The set of characters to trim, defaults to whitespace`
 @return `a substring of the string passed in`
 @pure
*>
fn String String.trim_left(self, String to_trim = " \n\t\r\f\v")
{
	sz start = 0;
	sz len = self.len;
	while (start < len && char_in_set(self[start], to_trim)) start++;
	if (start == len) return self[:0];
	return self[start..];
}

<*
 Remove characters from the end of a string.

 #### Example:
 ```
 String s = "  hello ".trim_right(); // "  hello"
 ```

 @param [in] self : `The string to trim`
 @param [in] to_trim : `The set of characters to trim, defaults to whitespace`
 @return `a substring of the string passed in`
 @pure
*>
fn String String.trim_right(self, String to_trim = " \n\t\r\f\v")
{
	sz len = self.len;
	while (len > 0 && char_in_set(self[len - 1], to_trim)) len--;
	return self[:len];
}

<*
 Check if the String starts with the prefix. An empty prefix always matches.

 #### Example:
 ```
 bool b = "foobar".starts_with("foo"); // true
 ```

 @param [in] self
 @param [in] prefix
 @return `'true' if the string starts with the prefix`
 @pure
*>
fn bool String.starts_with(self, String prefix)
{
	if (prefix.len > self.len) return false;
	if (!prefix.len) return true;
	return self[:prefix.len] == prefix;
}

<*
 Compare two strings case-insensitively (ASCII only), lexicographically.

 #### Example:
 ```
 int c = "Hello".compare_to_ignore_case("hello"); // 0
 ```

 @param [in] self
 @param [in] s
 @return "-1 if self < s, 0 if equal, 1 if self > s"
 @pure
*>
fn int String.compare_to_ignore_case(self, String s)
{
	sz len = min(s.len, self.len);
	for (sz i = 0; i < len; i++)
	{
		sz sign = math::sign(self[i].to_upper() - s[i].to_upper());
		if (sign != 0) return (int)sign;
	}
	return (int)math::sign(self.len - s.len);
}

<*
 Compare two strings byte-by-byte, lexicographically. A shorter string sorts before a longer one it is a prefix of.

 #### Example:
 ```
 int c = "abc".compare_to("abd"); // -1
 ```

 @param [in] self
 @param [in] s
 @return "-1 if self < s, 0 if equal, 1 if self > s"
 @pure
*>
fn int String.compare_to(self, String s)
{
	sz len = min(s.len, self.len);
	for (sz i = 0; i < len; i++)
	{
		sz sign = math::sign(self[i] - s[i]);
		if (sign != 0) return (int)sign;
	}
	return (int)math::sign(self.len - s.len);
}

<*
 Check if the String ends with the suffix. An empty suffix always matches.

 #### Example:
 ```
 bool b = "image.png".ends_with(".png"); // true
 ```

 @param [in] self
 @param [in] suffix
 @return `'true' if the string ends with the suffix`
 @pure
*>
fn bool String.ends_with(self, String suffix)
{
	if (suffix.len > self.len) return false;
	if (!suffix.len) return true;
	return self[^suffix.len..] == suffix;
}

<*
 Strip the front of the string if the prefix exists.

 #### Example:
 ```
 String s = "0x1F".strip_prefix("0x"); // "1F"
 ```

 @param [in] self
 @param [in] prefix
 @return `the substring with the prefix removed, or the string itself if it lacks the prefix`
 @pure
*>
fn String String.strip_prefix(self, String prefix)
{
	if (!prefix.len || !self.starts_with(prefix)) return self;
	return self[prefix.len..];
}

<*
 Strip the end of the string if the suffix exists.

 #### Example:
 ```
 String s = "file.txt".strip_suffix(".txt"); // "file"
 ```

 @param [in] self
 @param [in] suffix
 @return `the substring with the suffix removed, or the string itself if it lacks the suffix`
 @pure
*>
fn String String.strip_suffix(self, String suffix)
{
	if (!suffix.len || !self.ends_with(suffix)) return self;
	// Note that this is the safe way if we want to support zero length.
	return self[:(self.len - suffix.len)];
}

<*
 Split a string into parts, e.g "a|b|c" split with "|" yields { "a", "b", "c" }

 Only the `String[]` is allocated; the elements are slices of the original string.
 When `max` is reached, the last element holds the unsplit remainder.

 #### Example:
 ```
 String[] parts = "a|b|c".split(mem, "|"); // { "a", "b", "c" }
 defer free(parts);
 String[] two = "a|b|c".split(mem, "|", max: 2); // { "a", "b|c" }
 defer free(two);
 ```

 @param [in] self
 @param [&inout] allocator : "The allocator to use for the String[]"
 @param [in] delimiter
 @param max : "Max number of elements, 0 means no limit, defaults to 0"
 @param skip_empty : "True to skip empty elements"
 @return "The parts of the string"
 @require delimiter.len > 0 : "The delimiter must be at least 1 character long"
 @ensure return.len > 0 || skip_empty
*>
fn String[] String.split(self, Allocator allocator, String delimiter, sz max = 0, bool skip_empty = false)
{
	sz capacity = 16;
	sz i = 0;
	String* holder = alloc::alloc_array(allocator, String, capacity);
	bool no_more = false;
	while (!no_more)
	{
		sz? index = i == max - 1 ? NOT_FOUND~ : self.index_of(delimiter);
		String res @noinit;
		if (try index)
		{
			res = self[:index];
			self = self[index + delimiter.len..];
		}
		else
		{
			res = self;
			no_more = true;
		}
		if (!res.len && skip_empty)
        {
        	continue;
        }

		if (i == capacity)
		{
			capacity *= 2;
			holder = alloc::realloc(allocator, holder, String::size * capacity);
		}
		holder[i++] = res;
	}
	return holder[:i];
}


<*
 This function is identical to String.split, but implicitly uses the
 temporary allocator.

 @param [in] s
 @param [in] delimiter
 @param max : "Max number of elements, 0 means no limit, defaults to 0"
 @param skip_empty : "True to skip empty elements"
 @return "The parts of the string, in a temp allocated slice"
*>
fn String[] String.tsplit(s, String delimiter, sz max = 0, bool skip_empty = false) => s.split(tmem, delimiter, max, skip_empty) @inline;

<* Returned by `String.split_to_buffer` when the parts do not fit the buffer. *>
excuse BUFFER_EXCEEDED;

<*
 Split a string into parts, writing them into the given buffer instead of allocating,
 e.g "a|b|c" split with "|" yields { "a", "b", "c" }

 #### Example:
 ```
 String[4] buf;
 String[] parts = "a|b|c".split_to_buffer("|", &buf)!!; // { "a", "b", "c" }
 ```

 @param [in] s
 @param [in] delimiter
 @param [inout] buffer : "The buffer to store the parts in"
 @param max : "Max number of elements, 0 means no limit, defaults to 0"
 @param skip_empty : "True to skip empty elements"
 @return "A slice of the buffer holding the parts"
 @return? BUFFER_EXCEEDED : `If there are more elements than would fit the buffer`
 @require delimiter.len > 0 : "The delimiter must be at least 1 character long"
 @ensure return.len > 0 || skip_empty
*>
fn String[]? String.split_to_buffer(s, String delimiter, String[] buffer, sz max = 0, bool skip_empty = false)
{
	sz max_capacity = buffer.len;
	sz i = 0;
	bool no_more = false;
	while (!no_more)
	{
		sz? index = i == max - 1 ? NOT_FOUND~ : s.index_of(delimiter);
		String res @noinit;
		if (try index)
		{
			res = s[:index];
			s = s[index + delimiter.len..];
		}
		else
		{
			res = s;
			no_more = true;
		}
		if (!res.len && skip_empty)
		{
			continue;
		}
		if (i == max_capacity)
		{
			return BUFFER_EXCEEDED~;
		}
		buffer[i++] = res;
	}
	return buffer[:i];
}

<*
 Check if a substring is found in the string. An empty substring is always found.

 #### Example:
 ```
 bool b = "hello world".contains("o w"); // true
 ```

 @param [in] s
 @param [in] substr : "The string to look for."
 @return "true if the string contains the substring, false otherwise"
 @pure
*>
fn bool String.contains(s, String substr)
{
	return @ok(s.index_of(substr));
}

<*
 Check if a character is found in the string.

 @param [in] s
 @param character : "The character to look for."
 @return "true if the string contains the character, false otherwise"
 @pure
*>
fn bool String.contains_char(s, char character)
{
	return @ok(s.index_of_char(character));
}

<*
 Check how many non-overlapping instances of a substring there is.

 If the substring has zero length, the number of matches is zero.

 #### Example:
 ```
 sz n = "aaaa".count("aa"); // 2
 ```

 @param [in] self : "The string to search"
 @param [in] substr : "The string to look for."
 @return "The number of times matched"
 @pure
*>
fn sz String.count(self, String substr)
{
	sz count = 0;
	sz needed = substr.len;
	if (needed == 0) return 0;
    char first = substr[0];
    while OUTER: (self.len >= needed)
    {
    	foreach (i, c: self[..^needed])
    	{
    		if (c == first && self[i : needed] == substr)
    		{
    		    count++;
    		    self = self[i + needed..];
    		    continue OUTER;
    		}
    	}
    	break;
    }
    return count;
}

<*
 Find the index of the first incidence of a character.

 #### Example:
 ```
 sz i = "hello".index_of_char('l')!!; // 2
 ```

 @param [in] self
 @param character : "The character to look for"
 @return "the index of the character"
 @return? NOT_FOUND : "if the character cannot be found"
 @ensure return < self.len
 @pure
*>
fn sz? String.index_of_char(self, char character)
{
	foreach (i, c : self)
	{
		if (c == character) return i;
	}
	return NOT_FOUND~;
}

<*
 Find the index of the first character in the string that is one of the given chars.

 #### Example:
 ```
 sz i = "key=value;".index_of_chars("=;")!!; // 3
 ```

 @param [in] self
 @param [in] characters : "The characters to look for"
 @return "the index of the first matching character"
 @return? NOT_FOUND : "if none of the characters can be found"
 @ensure return < self.len
 @pure
*>
fn sz? String.index_of_chars(String self, char[] characters)
{
    foreach (i, c : self)
    {
        foreach (j, pin : characters)
        {
            if (c == pin) return i;
        }
    }

    return NOT_FOUND~;
}

<*
 Find the index of the first incidence of a character, starting at `start_index`.

 #### Example:
 ```
 sz i = "a.b.c".index_of_char_from('.', 2)!!; // 3
 ```

 @param [in] self
 @param character : "The character to look for"
 @param start_index : "The index to start with, may exceed max index."
 @return "the index of the character"
 @return? NOT_FOUND : "if the character cannot be found starting from the start_index"
 @ensure return < self.len
 @pure
*>
fn sz? String.index_of_char_from(self, char character, sz start_index)
{
	sz len = self.len;
	if (len <= start_index) return NOT_FOUND~;
	for (sz i = start_index; i < len; i++)
	{
		if (self[i] == character) return i;
	}
	return NOT_FOUND~;
}

<*
 Find the index of the last incidence of a character, searching from the end.

 #### Example:
 ```
 sz i = "a/b/c".rindex_of_char('/')!!; // 3
 ```

 @param [in] self
 @param character : "the character to find"
 @return "the index of the character"
 @return? NOT_FOUND : "if the character cannot be found"
 @ensure return < self.len
 @pure
*>
fn sz? String.rindex_of_char(self, char character)
{
	foreach_r (i, c : self)
	{
		if (c == character) return i;
	}
	return NOT_FOUND~;
}

<*
 Find the index of the first incidence of a string. An empty substring is found at index 0.

 #### Example:
 ```
 sz i = "hello world".index_of("world")!!; // 6
 ```

 @param [in] self
 @param [in] substr
 @return "the index of the substring"
 @return? NOT_FOUND : "if the substring cannot be found"
 @ensure (!substr && return == 0) || return < self.len
 @pure
*>
fn sz? String.index_of(self, String substr)
{

	sz needed = substr.len;
	if (!needed) return 0;
	if (self.len < needed) return NOT_FOUND~;
	if (needed == 1) return self.index_of_char(substr[0]) @inline;
	char first = substr[0];
	foreach (i, c: self[..^needed])
	{
		if (c == first && self[i : needed] == substr) return i;
	}
	return NOT_FOUND~;
}

<*
 Find the index of the last incidence of a string. An empty substring is found at `self.len`.

 #### Example:
 ```
 sz i = "abcabc".rindex_of("bc")!!; // 4
 ```

 @param [in] self
 @param [in] substr
 @return "the index of the substring"
 @return? NOT_FOUND : "if the substring cannot be found"
 @ensure (substr.len == 0 && return == self.len) || return < self.len
 @pure
*>
fn sz? String.rindex_of(self, String substr)
{
	sz needed = substr.len;
	if (needed == 0) return self.len;
	if (self.len >= needed)
	{
		char first = substr[0];
		foreach_r (i, c: self[..^needed])
		{
			if (c == first && self[i : needed] == substr) return i;
		}
	}
	return NOT_FOUND~;
}

<*
 Compare two ZStrings for byte-for-byte equality, stopping at the first zero terminator.
 A null ZString is considered different from any non-null ZString.

 #### Example:
 ```
 ZString a = "abc";
 ZString b = "abc";
 bool same = a == b; // true
 ```

 @param [in] self
 @param [in] other
 @return "true if both ZStrings have the same content"
 @pure
*>
fn bool ZString.eq(self, ZString other) @operator(==)
{
	char* a = self;
	char* b = other;
	if (a == b) return true;
	if (!a || !b) return false;
	for (;; a++, b++)
	{
		char c = *a;
		if (c != *b) return false;
		if (!c) return true;
	}
}

<*
 View a ZString as a String, without copying.

 @param [&own] self
 @return "A String view of the same memory, not including the zero terminator"
*>
fn String ZString.str_view(self)
{
	return (String)(self[:self.len()]);
}

<*
 Count the number of UTF-8 codepoints in a zero-terminated string.

 #### Example:
 ```
 ZString z = "héllo";
 sz n = z.char_len(); // 5, while z.len() is 6
 ```

 @param [&in] str
 @return "The number of UTF-8 codepoints, which may be fewer than the byte length"
 @pure
*>
fn sz ZString.char_len(str)
{
	sz len = 0;
	char* ptr = (char*)str;
	while (char c = ptr++[0])
	{
		if (c & 0xC0 != 0x80) len++;
	}
	return len;
}

<*
 Return the length of the ZString in bytes. This scans the string for the terminator.

 @param [&in] self
 @return "The number of bytes before the zero terminator"
 @pure
*>
fn sz ZString.len(self)
{
	sz len;
	for (char* ptr = (char*)self; *ptr; ptr++) len++;
	return len;
}

<*
 Return the length of the WString in UTF-16 units. This scans the string for the terminator.

 @param [&in] self
 @return "The number of Char16 units before the zero terminator"
 @pure
*>
fn sz WString.len(self)
{
	sz len;
	for (Char16* ptr = (Char16*)self; *ptr; ptr++) len++;
	return len;
}

<*
 Copy this string into a newly allocated, zero-terminated ZString.

 #### Example:
 ```
 ZString z = "hello".zstr_copy(mem);
 defer free(z);
 ```

 @param [in] self
 @param [&inout] allocator
 @return "A zero terminated copy of the string"
*>
fn ZString String.zstr_copy(self, Allocator allocator)
{
	sz len = self.len;
	char* str = alloc::malloc(allocator, len + 1);
	mem::copy(str, self.ptr, len);
	str[len] = 0;
	return (ZString)str;
}

<*
 Concatenate two strings into a newly allocated string.

 #### Example:
 ```
 String s = "foo".concat(mem, "bar"); // "foobar"
 defer s.free(mem);
 ```

 @param [in] self
 @param [&inout] allocator
 @param [in] s2 : "The string to append after self"
 @return "A new zero-terminated string containing self followed by s2"
*>
fn String String.concat(self, Allocator allocator, String s2)
{
	sz full_len = self.len + s2.len;
	char* str = alloc::malloc(allocator, full_len + 1);
	sz self_len = self.len;
	mem::copy(str, self.ptr, self_len);
	mem::copy(str + self_len, s2.ptr, s2.len);
	str[full_len] = 0;
	return (String)str[:full_len];
}

<* Alias for `String.concat` using the temp allocator. *>
fn String String.tconcat(self, String s2) => self.concat(tmem, s2);


<* Alias for `String.zstr_copy` using the temp allocator. *>
fn ZString String.zstr_tcopy(self) => self.zstr_copy(tmem) @inline;

<*
 Copy this string, by duplicating the string, always adding a zero byte
 sentinel, so that it safely can be converted to a ZString by a
 cast.

 #### Example:
 ```
 String s = "hello".copy(mem);
 defer s.free(mem);
 ZString z = (ZString)s.ptr;
 ```

 @param [in] self
 @param [&inout] allocator
 @return "The copy of the string"
*>
fn String String.copy(self, Allocator allocator)
{
	sz len = self.len;
	char* str = alloc::malloc(allocator, len + 1);
	mem::copy(str, self.ptr, len);
	str[len] = 0;
	return (String)str[:len];
}

<*
 Free a string previously allocated via `String.copy` (or similar) using the given allocator.
 A string with a null `ptr` is left untouched.

 @param [&inout] self
 @param [&inout] allocator : "The allocator that allocated the string"
*>
fn void String.free(&self, Allocator allocator)
{
	if (!self.ptr) return;
	alloc::free(allocator, self.ptr);
	*self = "";
}

<* Alias for `String.copy` using the temp allocator. *>
fn String String.tcopy(self) => self.copy(tmem) @inline;

<*
 Copy the ZString's content into a newly allocated String.

 @param [&in] self
 @param [&inout] allocator
 @return "A new String, safe to convert to a ZString"
*>
fn String ZString.copy(self, Allocator allocator)
{
	return self.str_view().copy(allocator) @inline;
}

<*
 Alias for `ZString.copy` using the temp allocator.

 @param [&in] self
*>
fn String ZString.tcopy(self)
{
	return self.str_view().copy(tmem) @inline;
}

<*
 Convert an UTF-8 string to UTF-16. The result is zero terminated.

 #### Example:
 ```
 Char16[] w = "héllo".to_utf16(mem)!!; // w.len == 5
 defer free(w);
 ```

 @param [in] self
 @param [&inout] allocator
 @return "The UTF-16 string as a slice, allocated using the given allocator"
 @return? INVALID_UTF8 : "If the string contained an invalid UTF-8 sequence"
*>
fn Char16[]? String.to_utf16(self, Allocator allocator)
{
	sz len16 = conv::utf16len_for_utf8(self);
	Char16* data = alloc::alloc_array_try(allocator, Char16, len16 + 1)!;
	conv::utf8to16_unsafe(self, data)!;
	data[len16] = 0;
	return data[:len16];
}

<* Alias for `String.to_utf16` using the temp allocator. *>
fn Char16[]? String.to_temp_utf16(self) => self.to_utf16(tmem);

<*
 Convert an UTF-8 string to a zero-terminated UTF-16 WString.

 #### Example:
 ```
 WString w = "hello".to_wstring(mem)!!;
 defer free(w);
 ```

 @param [in] self
 @param [&inout] allocator
 @return "The WString, allocated using the given allocator"
 @return? INVALID_UTF8 : "If the string contained an invalid UTF-8 sequence"
*>
fn WString? String.to_wstring(self, Allocator allocator)
{
	return (WString)self.to_utf16(allocator).ptr;
}

<* Alias for `String.to_wstring` using the temp allocator. *>
fn WString? String.to_temp_wstring(self) => self.to_wstring(tmem);

<*
 Convert an UTF-8 string to UTF-32. The result is zero terminated.

 #### Example:
 ```
 Char32[] cps = "héllo".to_utf32(mem)!!; // cps.len == 5, cps[1] == 0xE9
 defer free(cps);
 ```

 @param [in] self
 @param [&inout] allocator
 @return "The UTF-32 string as a slice, allocated using the given allocator"
 @return? INVALID_UTF8 : "If the string contained an invalid UTF-8 sequence"
*>
fn Char32[]? String.to_utf32(self, Allocator allocator)
{
	sz codepoints = conv::utf8_codepoints(self);
	Char32* data = alloc::alloc_array_try(allocator, Char32, codepoints + 1)!;
	conv::utf8to32_unsafe(self, data)!;
	data[codepoints] = 0;
	return data[:codepoints];
}

<* Alias for `String.to_utf32` using the temp allocator. *>
fn Char32[]? String.to_temp_utf32(self) => self.to_utf32(tmem);

<*
 Convert a string to ASCII lower case in place. The string must be writable, so not a literal.

 #### Example:
 ```
 String s = "HeLLo".tcopy();
 s.convert_to_lower(); // s == "hello"
 ```

 @param [inout] self
 @pure
*>
fn void String.convert_to_lower(self)
{
	foreach (&c : self) if (c.is_upper() @pure) *c += 'a' - 'A';
}

<*
 Returns a string converted to ASCII lower case.

 #### Example:
 ```
 String s = "HeLLo".to_lower_copy(mem); // "hello"
 defer s.free(mem);
 ```

 @param [in] self
 @param [&inout] allocator
 @return `a new String converted to ASCII lower case.`
*>
fn String String.to_lower_copy(self, Allocator allocator)
{
	String copy = self.copy(allocator);
	copy.convert_to_lower();
	return copy;
}

<* Alias for `String.to_lower_copy` using the temp allocator. *>
fn String String.to_lower_tcopy(self)
{
	return self.to_lower_copy(tmem);
}

<*
 Convert a string to ASCII upper case in place. The string must be writable, so not a literal.

 #### Example:
 ```
 String s = "HeLLo".tcopy();
 s.convert_to_upper(); // s == "HELLO"
 ```

 @param [inout] self
 @pure
*>
fn void String.convert_to_upper(self)
{
	foreach (&c : self) if (c.is_lower() @pure) *c -= 'a' - 'A';
}

<*
 Returns a string converted to ASCII upper case.

 #### Example:
 ```
 String s = "HeLLo".to_upper_copy(mem); // "HELLO"
 defer s.free(mem);
 ```

 @param [in] self
 @param [&inout] allocator
 @return `a new String converted to ASCII upper case.`
*>
fn String String.to_upper_copy(self, Allocator allocator)
{
	String copy = self.copy(allocator);
	copy.convert_to_upper();
	return copy;
}

<*
 Returns a copy of the string with the first character converted to ASCII upper case.

 #### Example:
 ```
 String s = "hello world".capitalize_copy(mem); // "Hello world"
 defer s.free(mem);
 ```

 @param [in] self
 @param [&inout] allocator
 @return `a new String with the first character converted to ASCII upper case.`
*>
fn String String.capitalize_copy(self, Allocator allocator)
{
	String s = self.copy(allocator);
	if (s.len > 0 && s[0].is_lower())
	{
		s[0] &= (char)~0x20;
	}
	return s;
}

<*
 Convert a string from `snake_case` to PascalCase. Repeated, leading and trailing `_` are dropped.

 #### Example:
 ```
 String s = "foo_bar".snake_to_pascal_copy(mem); // "FooBar"
 defer s.free(mem);
 ```

 @param [in] self
 @param [&inout] allocator
 @return `The PascalCase string, the resulting pointer may safely be cast to ZString.`
*>
fn String String.snake_to_pascal_copy(self, Allocator allocator)
{
	Splitter splitter = self.tokenize("_");
	char[] new_string = alloc::alloc_array(allocator, char, self.len + 1);
	sz index = 0;
	while (try s = splitter.next())
	{
		assert(s.len > 0);
		char c = s[0];
		if (c.is_lower()) c = c.to_upper();
		new_string[index++] = c;
		s = s[1..];
		new_string[index:s.len] = s[..];
		index += s.len;
	}
	new_string[index] = 0;
	return (String)new_string[:index];
}

<*
 Modifies the current string in place from `snake_case` to PascalCase, shortening it as needed.
 The string must be writable, so not a literal.

 #### Example:
 ```
 String s = "foo_bar".tcopy();
 s.convert_snake_to_pascal(); // s == "FooBar"
 ```

 @param [&inout] self
*>
fn void String.convert_snake_to_pascal(&self)
{
	Splitter splitter = self.tokenize("_");
	String new_string = *self;
	sz index = 0;
	while (try s = splitter.next())
	{
		assert(s.len > 0);
		char c = s[0];
		if (c.is_lower()) c = c.to_upper();
		new_string[index++] = c;
		s = s[1..];
		new_string[index:s.len] = s[..];
		index += s.len;
	}
	*self = new_string[:index];
}

<*
 Convert a string from `PascalCase` to `snake_case`. Runs of capitals are kept together as one word.

 #### Example:
 ```
 String s = "HTTPServerError".pascal_to_snake_copy(mem); // "http_server_error"
 defer s.free(mem);
 ```

 @param [in] self
 @param [&inout] allocator
 @return `The snake_case string, the resulting pointer may safely be cast to ZString.`
*>
fn String String.pascal_to_snake_copy(self, Allocator allocator) => @pool()
{
	DString d;
	d.init(tmem, (sz)(self.len * 1.5));
	foreach (i, c : self)
	{
		if (c.is_upper())
		{
			if (i > 0 && ((self[i - 1].is_lower() || self[i - 1].is_digit()) || (i < self.len - 1 && self[i + 1].is_lower())))
            {
                d.append_char('_');
            }
			d.append_char(c.to_lower());
			continue;
		}
		d.append_char(c);
	}
	return d.copy_str(allocator);
}


<*
 Create an iterator that decodes the string's UTF-8 codepoints one at a time.

 #### Example:
 ```
 StringIterator it = "hé".iterator();
 while (try c = it.next())
 {
 	io::printfn("%d", c); // 104, then 233
 }
 ```

 @param [own] self
 @return "An iterator over the string's codepoints"
*>
fn StringIterator String.iterator(self)
{
	return { self, 0 };
}

<*
 Alias for `String.to_upper_copy` using the temp allocator.

 @param [in] self
 @return `a temporary String converted to ASCII upper case.`
*>
fn String String.to_upper_tcopy(self)
{
	return self.to_upper_copy(tmem);
}

<*
 Convert an UTF-32 string to UTF-8. The codepoints are not validated. The result is zero terminated.

 #### Example:
 ```
 Char32[] cps = { 'a', 0xE9 };
 String s = string::from_utf32(mem, cps)!!; // "aé"
 defer s.free(mem);
 ```

 @param [&inout] allocator
 @param [in] utf32
 @return "The UTF-8 string, allocated using the given allocator"
*>
fn String? from_utf32(Allocator allocator, Char32[] utf32)
{
	sz len = conv::utf8len_for_utf32(utf32);
	char* data = alloc::malloc_try(allocator, len + 1)!;
	defer catch alloc::free(allocator, data);
	conv::utf32to8_unsafe(utf32, data, $unaligned: false, $byteswap: false);
	data[len] = 0;
	return (String)data[:len];
}

<*
 Convert raw UTF-32 bytes (not necessarily aligned) to UTF-8. The codepoints are not validated.
 Trailing bytes that do not form a whole codepoint are ignored.

 @param [&inout] allocator
 @param [in] utf32 : "The raw bytes making up the UTF-32 codepoints"
 @param swap_endianess : "Set to true if the bytes are in the non-native endianness"
 @return "The UTF-8 string, allocated using the given allocator"
*>
fn String? from_utf32_bytes(Allocator allocator, char[] utf32, bool swap_endianess)
{
	sz len = conv::utf8len_for_utf32_bytes(utf32, swap_endianess);
	char* data = alloc::malloc_try(allocator, len + 1)!;
	defer catch alloc::free(allocator, data);
	bool is_aligned = (uptr)utf32.ptr % 4 == 0;
	Char32[] unaligned = ((Char32*)utf32.ptr)[:utf32.len / 4];
	switch
	{
		case is_aligned && !swap_endianess:
			conv::utf32to8_unsafe(unaligned, data, $unaligned: false, $byteswap: false);
		case !is_aligned && !swap_endianess:
			conv::utf32to8_unsafe(unaligned, data, $unaligned: true, $byteswap: false);
		case is_aligned && swap_endianess:
			conv::utf32to8_unsafe(unaligned, data, $unaligned: false, $byteswap: true);
		default:
			conv::utf32to8_unsafe(unaligned, data, $unaligned: true, $byteswap: true);
	}
	data[len] = 0;
	return (String)data[:len];
}

<*
 Convert an UTF-16 string to UTF-8. The result is zero terminated.

 #### Example:
 ```
 String s = string::from_utf16(mem, @char16("hello"))!!; // "hello"
 defer s.free(mem);
 ```

 @param [&inout] allocator
 @param [in] utf16
 @return "The UTF-8 string, allocated using the given allocator"
 @return? INVALID_UTF16 : "If the string contained an invalid UTF-16 sequence"
*>
fn String? from_utf16(Allocator allocator, Char16[] utf16)
{
	sz len = conv::utf8len_for_utf16(utf16);
	char* data = alloc::malloc_try(allocator, len + 1)!;
	defer catch alloc::free(allocator, data);
	conv::utf16to8_unsafe(utf16, data, $unaligned: false, $byteswap: false)!;
	data[len] = 0;
	return (String)data[:len];
}

<*
 Convert raw UTF-16 bytes (not necessarily aligned) to UTF-8.
 A trailing odd byte is ignored.

 @param [&inout] allocator
 @param [in] utf16 : "The raw bytes making up the UTF-16 units"
 @param swap_endianess : "Set to true if the bytes are in the non-native endianness"
 @return "The UTF-8 string, allocated using the given allocator"
 @return? INVALID_UTF16 : "If the string contained an invalid UTF-16 sequence"
*>
fn String? from_utf16_bytes(Allocator allocator, char[] utf16, bool swap_endianess)
{
	sz len = conv::utf8len_for_utf16_bytes(utf16, swap_endianess);
	char* data = alloc::malloc_try(allocator, len + 1)!;
	defer catch alloc::free(allocator, data);

	bool is_aligned = (uptr)utf16.ptr % 2 == 0;
	Char16[] unaligned = ((Char16*)utf16.ptr)[:utf16.len / 2];
	switch
	{
		case is_aligned && !swap_endianess:
			conv::utf16to8_unsafe(unaligned, data, $unaligned: false, $byteswap: false)!;
		case !is_aligned && !swap_endianess:
			conv::utf16to8_unsafe(unaligned, data, $unaligned: true, $byteswap: false)!;
		case is_aligned && swap_endianess:
			conv::utf16to8_unsafe(unaligned, data, $unaligned: false, $byteswap: true)!;
		default:
			conv::utf16to8_unsafe(unaligned, data, $unaligned: true, $byteswap: true)!;
	}
	data[len] = 0;
	return (String)data[:len];
}

<*
 Convert a zero-terminated UTF-16 WString to UTF-8.

 #### Example:
 ```
 String s = string::from_wstring(mem, @wstring("hello"))!!; // "hello"
 defer s.free(mem);
 ```

 @param [&inout] allocator
 @param [&in] wstring
 @return "The UTF-8 string, allocated using the given allocator"
 @return? INVALID_UTF16 : "If the string contained an invalid UTF-16 sequence"
*>
fn String? from_wstring(Allocator allocator, WString wstring)
{
	sz utf16_len;
	while (wstring[utf16_len] != 0) utf16_len++;
	Char16[] utf16 = wstring[:utf16_len];
	return from_utf16(allocator, utf16);
}

<* Alias for `from_wstring` using the temp allocator. *>
fn String? tfrom_wstring(WString wstring) => from_wstring(tmem, wstring) @inline;
<* Alias for `from_utf16` using the temp allocator. *>
fn String? tfrom_utf16(Char16[] utf16) => from_utf16(tmem, utf16) @inline;

<*
 Count the number of UTF-8 codepoints in the string. The string is not validated.

 #### Example:
 ```
 sz n = "héllo".utf8_codepoints(); // 5, while the byte length is 6
 ```

 @param [in] s
 @return "The number of UTF-8 codepoints in the string, which may be fewer than the byte length"
 @pure
*>
fn sz String.utf8_codepoints(s)
{
	sz len = 0;
	foreach (char c : s)
	{
		if (c & 0xC0 != 0x80) len++;
	}
	return len;
}

<*
 Parse a string as an integer of type `IntType`, in the given base.

 An optional `+` or `-` sign is accepted. When the base is 10 (the default), a `0x`, `0o`
 or `0b` prefix switches the base to 16, 8 or 2. Blanks (spaces and tabs) before and
 after the number are skipped.

 #### Example:
 ```
 int a = string::to_integer{int}(" -42 ")!!; // -42
 uint b = string::to_integer{uint}("0xFF")!!; // 255
 int c = string::to_integer{int}("777", 8)!!; // 511
 ```

 @param [in] self
 @param base : "The base to parse the number in"
 @return "The parsed integer"
 @return? MALFORMED_INTEGER : "When the value has some illegal character"
 @return? INTEGER_OVERFLOW : "If the value does not fit in the given type"
 @return? EMPTY_STRING : "If the string was empty or only blanks"
 @return? NEGATIVE_VALUE : "If the type was unsigned, and the value had a - prefix"
 @require base > 0 && base <= 16 : "Unsupported base"
*>
fn IntType? to_integer(String self, int base = 10) <IntType>
{
	sz len = self.len;
	sz index = 0;
	char* ptr = self.ptr;
	while (index < len && ptr[index].is_blank()) index++;
	if (len == index) return EMPTY_STRING~;
	bool is_negative;
	switch (self[index])
	{
		case '-':
			$if IntType::min == 0:
				return NEGATIVE_VALUE~;
			$else
				is_negative = true;
				index++;
			$endif
		case '+':
			index++;
		default:
			break;
	}
	if (len == index) return MALFORMED_INTEGER~;
	char curr = self[index];
	// + / - followed by ' '
	if (curr.is_blank()) return MALFORMED_INTEGER~;
	IntType base_used = (IntType)base;
	if (curr == '0' && base == 10)
	{
		index++;
		if (index == len) return (IntType)0;
		switch (self[index])
		{
			case 'x':
			case 'X':
				base_used = 16;
				index++;
			case 'b':
			case 'B':
				base_used = 2;
				index++;
			case 'o':
			case 'O':
				base_used = 8;
				index++;
			default:
				break;
		}
		if (len == index) return MALFORMED_INTEGER~;
	}
	IntType value = 0;
	while (index != len)
	{
		curr = self[index++];
		// Handle ending space.
		if (curr.is_blank())
		{
			while (index != len) if (!self[index++].is_blank()) return MALFORMED_INTEGER~;
			break;
		}
		char c = ascii::HEX_VALUE[curr];
		if (c >= (int)base_used) return MALFORMED_INTEGER~;
		do
		{
			if (is_negative)
			{
				value = value.overflow_mul(base_used).overflow_sub((IntType)c) ?? INTEGER_OVERFLOW~!;
				break;
			}
			value = value.overflow_mul(base_used).overflow_add((IntType)c) ?? INTEGER_OVERFLOW~!;
		};
	}
	return value;
}

<* Alias for `to_integer{int128}`. See `to_integer` for parameters and faults. *>
fn int128? String.to_int128(self, int base = 10) => to_integer{int128}(self, base) @inline;
<* Alias for `to_integer{long}`. See `to_integer` for parameters and faults. *>
fn long? String.to_long(self, int base = 10) => to_integer{long}(self, base) @inline;
<* Alias for `to_integer{int}`. See `to_integer` for parameters and faults. *>
fn int? String.to_int(self, int base = 10) => to_integer{int}(self, base) @inline;
<* Alias for `to_integer{short}`. See `to_integer` for parameters and faults. *>
fn short? String.to_short(self, int base = 10) => to_integer{short}(self, base) @inline;
<* Alias for `to_integer{ichar}`. See `to_integer` for parameters and faults. *>
fn ichar? String.to_ichar(self, int base = 10) => to_integer{ichar}(self, base) @inline;

<* Alias for `to_integer{uint128}`. See `to_integer` for parameters and faults. *>
fn uint128? String.to_uint128(self, int base = 10) => to_integer{uint128}(self, base) @inline;
<* Alias for `to_integer{ulong}`. See `to_integer` for parameters and faults. *>
fn ulong? String.to_ulong(self, int base = 10) => to_integer{ulong}(self, base) @inline;
<* Alias for `to_integer{uint}`. See `to_integer` for parameters and faults. *>
fn uint? String.to_uint(self, int base = 10) => to_integer{uint}(self, base) @inline;
<* Alias for `to_integer{ushort}`. See `to_integer` for parameters and faults. *>
fn ushort? String.to_ushort(self, int base = 10) => to_integer{ushort}(self, base) @inline;

<* Alias for `to_integer{char}`, parsing a number in the range 0-255. See `to_integer` for parameters and faults. *>
fn char? String.to_char(self, int base = 10) => to_integer{char}(self, base) @inline;

<*
 Parse a string as a double.

 Surrounding whitespace is ignored. Accepts an optional sign, decimal notation with an
 optional exponent, hex floats with a `0x` prefix, and `infinity`/`nan` (all lower or all upper case).

 #### Example:
 ```
 double d = "-1.5e3".to_double()!!; // -1500.0
 ```

 @param [in] self
 @return "The parsed value"
 @return? MALFORMED_FLOAT : "When the value has some illegal character"
 @return? FLOAT_OUT_OF_RANGE : "If the value does not fit in a double"
*>
fn double? String.to_double(self) => _string_to_real(self, double);
<*
 Parse a string as a float. Accepts the same formats as `String.to_double`.

 #### Example:
 ```
 float f = " 0.25 ".to_float()!!; // 0.25
 ```

 @param [in] self
 @return "The parsed value"
 @return? MALFORMED_FLOAT : "When the value has some illegal character"
 @return? FLOAT_OUT_OF_RANGE : "If the value does not fit in a float"
*>
fn float? String.to_float(self) => _string_to_real(self, float);


<*
 Create a Splitter to track tokenizing of a string. Tokenize will turn "foo:bar::baz" into
 "foo", "bar" and "baz", if you want the empty string to be present, use `tokenize_all`
 instead. The tokens are slices of the original string, nothing is allocated.

 #### Example:
 ```
 Splitter sp = "foo:bar::baz".tokenize(":");
 while (try s = sp.next())
 {
 	io::printn(s); // foo, bar, baz
 }
 ```

 @param [in] self
 @param [in] split : "The string to use for splitting"
 @return "A Splitter to track the state"
*>
fn Splitter String.tokenize(self, String split)
{
	return { .string = self, .split = split, .type = TOKENIZE };
}

<*
 Create a Splitter to track tokenizing of a string, keeping empty tokens. This will turn
 "foo:bar::baz:" into "foo", "bar", "", "baz" and "". Use `tokenize` to skip empty tokens.

 #### Example:
 ```
 Splitter sp = "a::b:".tokenize_all(":", skip_last: true);
 while (try s = sp.next())
 {
 	io::printn(s); // a, (empty), b
 }
 ```

 @param [in] self
 @param [in] split : "The string to use for splitting"
 @param skip_last : "Set to true to not include the last empty token if present (default: false)"
 @return "A Splitter to track the state"
*>
fn Splitter String.tokenize_all(self, String split, bool skip_last = false)
{
	return {
		.string = self,
		.split = split,
		.type = skip_last ? TOKENIZE_ALL_SKIP_LAST : TOKENIZE_ALL
	};
}


<*
 Create a string description of a struct (or any value), as printed by `io::print`.

 A struct without a `to_format` method is printed member by member,
 e.g. `{ x: 1, name: abc }`.

 #### Example:
 ```
 int[3] values = { 1, 2, 3 };
 String s = string::from_struct(mem, values); // "[1, 2, 3]"
 defer s.free(mem);
 ```

 @param [&inout] allocator : "The allocator to use"
 @param x : "The struct to create a description of"
 @return "The description of the value"
*>
macro String from_struct(Allocator allocator, x)
{
	DString s;
	@stack_mem(512; Allocator mem)
	{
		s.init(allocator: mem);
		io::fprint(&s, x)!!;
		return s.copy_str(allocator);
	};
}

<*
 Alias for `string::from_struct` using the temp allocator.

 @param x : "The struct to create a description of"
 @return "The description of the value"
*>
macro String tfrom_struct(x) => from_struct(tmem, x);

const uint SURROGATE_OFFSET @private = 0x10000;
const uint SURROGATE_GENERIC_MASK @private = 0xF800;
const uint SURROGATE_MASK @private = 0xFC00;
const uint SURROGATE_CODEPOINT_MASK @private = 0x03FF;
const uint SURROGATE_BITS @private = 10;
const uint SURROGATE_LOW_VALUE @private = 0xDC00;
const uint SURROGATE_HIGH_VALUE @private = 0xD800;

<* How a `Splitter` treats empty tokens, see `String.tokenize` and `String.tokenize_all`. *>
enum SplitterType
{
	TOKENIZE,
	TOKENIZE_ALL,
	TOKENIZE_ALL_SKIP_LAST
}

<*
 Splitter handles tokenizing strings. Create one with `String.tokenize` or `String.tokenize_all`.
*>
struct Splitter
{
	String string;
	String split;
	sz current;
	SplitterType type;
	int last_index;
}

<*
 Reset the splitter back to the start of the string, so `next()` starts over.

 @param [&inout] self
*>
fn void Splitter.reset(&self)
{
	self.current = 0;
}

<*
 Check whether the splitter is exhausted, i.e. `next()` has returned the final token.

 If the string ends with the delimiter and the trailing empty token is skipped (`tokenize`, or
 `tokenize_all` with `skip_last`), this stays false even after `next()` returns `NO_MORE_ELEMENT`.

 @param [&in] self
 @return "true once `next()` has no more tokens to produce"
*>
fn bool Splitter.at_end(&self)
{
	return self.current > self.string.len;
}

<*
 Advance the splitter and return the next token.

 #### Example:
 ```
 Splitter sp = "a,b".tokenize(",");
 String first = sp.next()!!; // "a"
 String second = sp.next()!!; // "b"
 bool done = @catch(sp.next()) == NO_MORE_ELEMENT; // true
 ```

 @param [&inout] self
 @return "The next token"
 @return? NO_MORE_ELEMENT : "if there are no more tokens"
*>
fn String? Splitter.next(&self)
{
	while (true)
	{
		sz len = self.string.len;
		sz current = self.current;
		if (current > len) return NO_MORE_ELEMENT~;
		if (current == len)
		{
			if (self.type != TOKENIZE_ALL) return NO_MORE_ELEMENT~;
			self.current++;
			return self.string[current:0];
		}

		sz? next;
		if (self.split.len == 1)
		{
			next = self.string.index_of_char_from(self.split[0], current) @inline;
		}
		else
		{
			next = self.string[current..].index_of(self.split) @inline + current;
		}

		if (try next)
		{
			String res = self.string[current : next - current];
			self.current = next + self.split.len;
			if (!res.len && self.type == TOKENIZE) continue;
			return res;
		}

		self.current = len + 1;
		return self.string[current..];
	}
}
