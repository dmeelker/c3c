module std::core::string::iterator;
import std::math;

<*
 StringIterator walks a UTF-8 encoded string one codepoint at a time.
 Create one with `String.iterator()`.

 #### Example:
 ```
 StringIterator it = "añ".iterator();
 Char32 a = it.next()!!; // 'a'
 Char32 p = it.peek()!!; // 0xF1 (ñ), without advancing
 Char32 n = it.next()!!; // 0xF1
 bool more = it.has_next(); // false
 ```
*>
struct StringIterator
{
	String utf8;
	sz current;
}

<*
 Reset the iterator back to the start of the string, so `next()` starts over.

 @param [&inout] self
*>
fn void StringIterator.reset(&self)
{
	self.current = 0;
}

<*
 Advance the iterator and return the next codepoint.
 On invalid UTF-8 the iterator does not advance, so repeated calls keep returning the fault.

 @param [&inout] self
 @return "The next codepoint"
 @return? NO_MORE_ELEMENT : "if there are no more codepoints"
 @return? string::INVALID_UTF8 : "if the string contained an invalid UTF-8 sequence"
*>
fn Char32? StringIterator.next(&self)
{
	sz len = self.utf8.len;
	sz current = self.current;
	if (current >= len) return NO_MORE_ELEMENT~;
	sz read = math::min(len - current, (sz)4);
	Char32 res = conv::utf8_to_char32(&self.utf8[current], &read)!;
	self.current += read;
	return res;
}

<*
 Return the next codepoint without advancing the iterator.

 @param [&in] self
 @return "The next codepoint"
 @return? NO_MORE_ELEMENT : "if there are no more codepoints"
 @return? string::INVALID_UTF8 : "if the string contained an invalid UTF-8 sequence"
*>
fn Char32? StringIterator.peek(&self)
{
	sz len = self.utf8.len;
	sz current = self.current;
	if (current >= len) return NO_MORE_ELEMENT~;
	sz read = math::min(len - current, (sz)4);
	Char32 res = conv::utf8_to_char32(&self.utf8[current], &read)!;
	return res;
}

<*
 Check whether there are more codepoints left to read.

 @param [&in] self
 @return "true if there are more bytes left to decode"
*>
fn bool StringIterator.has_next(&self)
{
	return self.current < self.utf8.len;
}
