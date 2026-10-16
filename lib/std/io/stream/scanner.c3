module std::io;

<*
 Scanner splits a stream into chunks separated by a pattern, such as lines.

 It reads into a caller-supplied buffer and does not allocate. It does not own the
 buffer or the wrapped stream, but `close` closes the wrapped stream.

 #### Example:
 ```
 ByteReader src;
 src.init("one\ntwo\nthree");
 char[64] buf;
 Scanner scanner;
 scanner.init(&src, &buf);
 while (try line = scanner.scan())
 {
 	io::printn((String)line); // "one", then "two"
 }
 String rest = (String)scanner.flush(); // "three"
 ```
*>
struct Scanner (InStream)
{
	CachedInStream wrapped_stream;
	char[] buf;
	sz pattern_idx;
	sz read_idx;
}

<*
 Scanner provides a way to read delimited data (with newlines as the default).
 The supplied buffer must be at least as large as the expected data length
 including its pattern.

 @param [&in] stream : "The stream to read data from."
 @param buffer : "The buffer to scan in, it must outlive the Scanner"
 @require buffer.len > 0 : "Non-empty buffer required."
*>
fn void Scanner.init(&self, InStream stream, char[] buffer)
{
	*self = { .wrapped_stream = stream.cached_stream(), .buf = buffer };
}


<*
 Return and clear any remaining unscanned data.

 Use it to get the trailing data after `scan` returns NOT_FOUND.

 @return "A view into the scan buffer, valid until the next scan or read"
*>
fn char[] Scanner.flush(&self) @dynamic
{
	assert(self.read_idx >= self.pattern_idx);
	sz n = self.read_idx - self.pattern_idx;
	char[] buf = self.buf[self.pattern_idx:n];
	self.pattern_idx = 0;
	self.read_idx = 0;
	return buf;
}

<*
 Close the wrapped stream, if it supports closing.
*>
fn void? Scanner.close(&self) @dynamic
{
	if (&self.wrapped_stream.close) return self.wrapped_stream.close();
}

<*
 Scan the stream for the next split character and return data up to the match.

 The pattern itself is consumed but not included in the result.

 @param pattern : "The separator to split on, defaults to a newline"
 @return "The data before the pattern, a view into the scan buffer valid until the next scan"
 @return? NOT_FOUND : "If the pattern was not found before the end of the stream, or the data does not fit in the buffer"
 @require pattern.len > 0 : "Non-empty pattern required."
 @require self.buf.len > pattern.len : "Pattern too large."
*>
fn char[]? Scanner.scan(&self, String pattern = "\n")
{
	if (self.read_idx == 0)
	{
		// First read.
		assert(self.buf);
		self.read_idx = _scanner_refill(self, self.buf)!;
		self.pattern_idx = 0;
	}
	assert(self.read_idx >= self.pattern_idx);
	sz n = self.read_idx - self.pattern_idx;
	char[] buf = self.buf[self.pattern_idx:n];
	if (try i = _scanner_find(self, buf, pattern))
	{
		self.pattern_idx += i + pattern.len;
		return buf[:i];
	}
	if (self.pattern_idx == 0 || self.read_idx < self.buf.len)
	{
		// Split pattern not found with maximized search, abort.
		// Split pattern not found and already read as much as possible.
		return NOT_FOUND~;
	}
	// Split pattern not found: maximize the search and try one more time.
	self.buf[:n] = buf[..];
	self.pattern_idx = 0;

	buf = self.buf[n..];
	sz p = _scanner_refill(self, buf)!;
	self.read_idx = n + p;

	buf = buf[:p];
	sz i = _scanner_find(self, buf, pattern)!;
	self.pattern_idx = n + i + pattern.len;

	return self.buf[:n + i];
}

macro sz? _scanner_find(Scanner* self, buf, pattern) @private
{
	return ((String)buf).index_of(pattern);
}

macro sz? _scanner_refill(Scanner* self, buf) @private
{
	sz n = read_buffer_to_end(self.wrapped_stream, buf).len!;
	return n ?: NOT_FOUND~;
}

<*
 Read bytes, first from the unscanned buffered data and then from the wrapped stream.

 @param [out] buffer : "The buffer to read into"
 @return "The number of bytes read, or 0 if the end of the stream is reached"
*>
fn sz? Scanner.read(&self, char[] buffer) @dynamic
{
	sz n;
	if (self.pattern_idx < self.read_idx)
	{
		n = min(buffer.len, self.read_idx - self.pattern_idx);
		buffer[:n] = self.buf[self.pattern_idx:n];
		self.pattern_idx += n;
		buffer = buffer[n..];
	}
	n += self.wrapped_stream.read(buffer)!;
	return n;
}

<*
 Read a single byte, first from the unscanned buffered data and then from the wrapped stream.

 @return "The byte read"
 @return? io::EOF : "If the end of the stream is reached"
*>
fn char? Scanner.read_byte(&self) @dynamic
{
	if (self.pattern_idx < self.read_idx)
	{
		return self.buf[self.pattern_idx++];
	}
	return self.wrapped_stream.read_byte();
}
