module std::io;

<*
 An InStream that buffers reads from a wrapped stream, using a caller-supplied buffer.

 It does not allocate and does not own the buffer or the wrapped stream, but `close`
 closes the wrapped stream.

 #### Example:
 ```
 ByteReader src; // Typically a File
 src.init("hello\nworld");
 char[16] buf;
 ReadBuffer rb;
 rb.init(&src, &buf);
 char[5] word;
 io::read_all(&rb, &word)!!; // word is "hello"
 char c = rb.read_byte()!!; // '\n'
 String rest = rb.str_view(); // "world" (already buffered)
 ```
*>
struct ReadBuffer (InStream)
{
	CachedInStream wrapped_stream;
	char[] buffer;
	sz read_idx;
	sz write_idx;
}

<*
 Buffer reads from a stream.

 @param [inout] self
 @param wrapped_stream : "The stream to read from"
 @param buffer : "The buffer to use, it must outlive the ReadBuffer"
 @return "The initialized ReadBuffer"
 @require buffer.len > 0 : "The buffer must be at least 1 byte"
 @require !self.buffer.len : "Init may not run on already initialized data"
*>
fn ReadBuffer* ReadBuffer.init(&self, InStream wrapped_stream, char[] buffer)
{
	*self = { .wrapped_stream = wrapped_stream.cached_stream(), .buffer = buffer };
	return self;
}

<*
 Return the buffered data that has not been read yet, as a String.

 @return "A view into the internal buffer, valid until the next read"
*>
fn String ReadBuffer.str_view(&self) @inline
{
	return (String)self.buffer[self.read_idx:self.write_idx - self.read_idx];
}

<*
 Return the buffered data that has not been read yet.

 @return "A view into the internal buffer, valid until the next read"
*>
fn char[] ReadBuffer.array_view(&self) @inline
{
	return self.buffer[self.read_idx:self.write_idx - self.read_idx];
}

<*
 Close the wrapped stream, if it supports closing.
*>
fn void? ReadBuffer.close(&self) @dynamic
{
	if (&self.wrapped_stream.close) self.wrapped_stream.close()!;
}

<*
 Read bytes into the buffer, refilling the internal buffer from the wrapped stream when empty.

 If nothing has been buffered yet and `buffer` is at least as large as the internal
 buffer, the data is read directly from the wrapped stream.

 @param [out] buffer : "The buffer to read into"
 @return "The number of bytes read, or 0 if the end of the stream is reached"
 @require buffer.len > 0 : "The buffer must be non-zero"
*>
fn sz? ReadBuffer.read(&self, char[] buffer) @dynamic
{
	if (self.read_idx == self.write_idx)
	{
		if (self.read_idx == 0 && buffer.len >= self.buffer.len)
		{
			// Read directly into the input buffer.
			return self.wrapped_stream.read(buffer)!;
		}
		readbuffer_refill(self)!;
	}
	sz n = min(self.write_idx - self.read_idx, buffer.len);
	buffer[:n] = self.buffer[self.read_idx:n];
	self.read_idx += n;
	return n;
}

<*
 Read a single byte, refilling the internal buffer from the wrapped stream when empty.

 @return "The byte read"
 @return? io::EOF : "If the end of the stream is reached"
*>
fn char? ReadBuffer.read_byte(&self) @dynamic
{
	if (self.read_idx == self.write_idx) readbuffer_refill(self)!;
	if (self.read_idx == self.write_idx) return io::EOF~;
	char c = self.buffer[self.read_idx];
	self.read_idx++;
	return c;
}

fn void? readbuffer_refill(ReadBuffer* self) @local @inline
{
	self.read_idx = 0;
	self.write_idx = self.wrapped_stream.read(self.buffer)!;
}

<*
 An OutStream that buffers writes to a wrapped stream, using a caller-supplied buffer.

 Data is written to the wrapped stream when the buffer is full, on `flush`, or directly
 for writes at least as large as the buffer.
 It does not allocate and does not own the buffer or the wrapped stream, but `close`
 closes the wrapped stream (without flushing first).

 #### Example:
 ```
 ByteWriter out; // Typically a File
 out.tinit();
 char[64] buf;
 WriteBuffer wb;
 wb.init(&out, &buf);
 io::fprint(&wb, "hello")!!;
 // out.str_view() is still "", the data is buffered
 wb.flush()!!;
 // out.str_view() is now "hello"
 ```
*>
struct WriteBuffer (OutStream)
{
	CachedOutStream wrapped_stream;
	char[] buffer;
	sz index;
}

<*
 Buffer writes to a stream. Call `flush` when done writing to the buffer.

 @param [inout] self
 @param wrapped_stream : "The stream to write to"
 @param buffer : "The buffer to use, it must outlive the WriteBuffer"
 @return "The initialized WriteBuffer"
 @require buffer.len > 0 : "Non-empty buffer required"
 @require self.buffer.len == 0 : "Init may not run on already initialized data"
*>
fn WriteBuffer* WriteBuffer.init(&self, OutStream wrapped_stream, char[] buffer)
{
	*self = { .wrapped_stream = wrapped_stream.cached_stream(), .buffer = buffer };
	return self;
}

<*
 Return the pending data that has not been written to the wrapped stream yet.

 @return "A view into the internal buffer, valid until the next write"
*>
fn String WriteBuffer.str_view(&self) @inline
{
	return (String)self.buffer[:self.index];
}

<*
 Close the wrapped stream, if it supports closing. Pending data is not flushed, call `flush` first.
*>
fn void? WriteBuffer.close(&self) @dynamic
{
	if (&self.wrapped_stream.close) return self.wrapped_stream.close();
}

<*
 Write all pending data to the wrapped stream, then flush the wrapped stream if it supports it.

 @return? INCOMPLETE_WRITE : "If the wrapped stream did not accept all pending data"
*>
fn void? WriteBuffer.flush(&self) @dynamic
{
	write_buffer_write_pending(self)!;
	if (&self.wrapped_stream.flush) self.wrapped_stream.flush()!;
}

<*
 Write bytes to the buffer, writing pending data to the wrapped stream when it fills up.

 Writes at least as large as the buffer go directly to the wrapped stream.

 @param [in] bytes : "The bytes to write"
 @return "The number of bytes written"
 @return? INCOMPLETE_WRITE : "If the wrapped stream did not accept all pending data"
*>
fn sz? WriteBuffer.write(&self, char[] bytes) @dynamic
{
	sz n = self.buffer.len - self.index;
	if (bytes.len < n)
	{
		// Enough room in the buffer.
		self.buffer[self.index:bytes.len] = bytes[..];
		self.index += bytes.len;
		return bytes.len;
	}
	write_buffer_write_pending(self)!;
	if (bytes.len >= self.buffer.len)
	{
		// Write directly to the stream.
		return self.wrapped_stream.write(bytes);
	}
	// Buffer the data.
	self.buffer[:bytes.len] = bytes[..];
	self.index = bytes.len;
	return bytes.len;
}

<*
 Write a single byte to the buffer, writing pending data to the wrapped stream if it is full.

 @return? INCOMPLETE_WRITE : "If the wrapped stream did not accept all pending data"
*>
fn void? WriteBuffer.write_byte(&self, char c) @dynamic
{
	sz n = self.buffer.len - self.index;
	if (n == 0)
	{
		write_buffer_write_pending(self)!;
	}
	self.buffer[self.index] = c;
	self.index += 1;
}

fn void? write_buffer_write_pending(WriteBuffer* self) @local
{
	self.index -= self.wrapped_stream.write(self.buffer[:self.index])!;
	if (self.index != 0) return INCOMPLETE_WRITE~;
}
