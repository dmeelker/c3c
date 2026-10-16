module std::io;

<*
 An InStream that reads at most `limit` bytes from a wrapped stream, then reports end of stream.

 It does not allocate or own the wrapped stream, but `close` closes the wrapped stream.

 #### Example:
 ```
 ByteReader src;
 src.init("hello world");
 LimitReader lr;
 lr.init(&src, 5);
 char[16] buf;
 sz n = io::read_buffer_to_end(&lr, &buf).len!!; // 5, buf[:n] is "hello"
 ```
*>
struct LimitReader (InStream)
{
	InStream wrapped_stream;
	long limit;
}

<*
 Initialize the reader to read at most limit bytes from the wrapped stream.

 @param [&inout] wrapped_stream : "The stream to read from"
 @param limit : "The max limit to read"
 @return "The initialized LimitReader"
*>
fn LimitReader* LimitReader.init(&self, InStream wrapped_stream, long limit)
{
	*self = { .wrapped_stream = wrapped_stream, .limit = limit };
	return self;
}

<*
 Close the wrapped stream, if it supports closing.
*>
fn void? LimitReader.close(&self) @dynamic
{
	if (&self.wrapped_stream.close) return self.wrapped_stream.close();
}

<*
 Read bytes from the wrapped stream, at most the remaining limit.

 @param [out] buffer : "The buffer to read into"
 @return "The number of bytes read, or 0 if the limit or the end of the stream is reached"
*>
fn sz? LimitReader.read(&self, char[] buffer) @dynamic
{
	long m = min(buffer.len, self.limit);
	if (!m) return 0;
	long n = self.wrapped_stream.read(buffer[:m])!;
	self.limit -= n;
	return (sz)n;
}

<*
 Read a single byte from the wrapped stream.

 @return "The byte read"
 @return? io::EOF : "If the limit or the end of the stream is reached"
*>
fn char? LimitReader.read_byte(&self) @dynamic
{
	if (self.limit == 0) return io::EOF~;
	defer try self.limit--;
	return self.wrapped_stream.read_byte();
}

<*
 Return the number of bytes left before the limit is reached.

 This is the remaining limit, the wrapped stream may have fewer bytes left.

 @return "The remaining limit"
*>
fn long? LimitReader.available(&self) @inline @dynamic
{
	return self.limit;
}
