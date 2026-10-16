module std::io;
import std::math;

<*
 A growable in-memory buffer that is both an InStream and an OutStream: written data can be read back in order.

 Already read data is discarded once at least `max_read` bytes have been read.
 Initialize with `init`/`tinit` (allocating, release with `free`) or `init_with_buffer`
 (fixed caller-supplied buffer).

 #### Example:
 ```
 ByteBuffer bb;
 bb.init(mem, 1024);
 defer bb.free();
 io::fprint(&bb, "abc")!!;
 char c = bb.read_byte()!!; // 'a'
 bb.pushback_byte()!!;
 char[8] data;
 sz n = bb.read(&data)!!; // 3, data[:n] is "abc"
 ```
*>
struct ByteBuffer (InStream, OutStream)
{
	Allocator allocator;
	sz max_read;
	char[] bytes;
	sz read_idx;
	sz write_idx;
	bool has_last;
}

<*
 ByteBuffer provides a streamable read/write buffer.
 max_read defines how many bytes might be kept before its internal buffer is shrunk.

 Allocates the initial buffer with the allocator, release it with `free`.

 @param allocator : "The allocator for the internal buffer"
 @param max_read : "How many read bytes to keep before compacting the buffer"
 @param initial_capacity : "The initial capacity, at least 16 is used"
 @return "The initialized ByteBuffer"
 @require self.bytes.len == 0 : "Buffer already initialized."
*>
fn ByteBuffer* ByteBuffer.init(&self, Allocator allocator, sz max_read, sz initial_capacity = 16)
{
	*self = { .allocator = allocator, .max_read = max_read };
	initial_capacity = max(initial_capacity, 16);
	self.grow(initial_capacity);
	return self;
}

<*
 Initialize the ByteBuffer using the temp allocator, see `init`.

 @param max_read : "How many read bytes to keep before compacting the buffer"
 @param initial_capacity : "The initial capacity, at least 16 is used"
 @return "The initialized ByteBuffer"
*>
fn ByteBuffer* ByteBuffer.tinit(&self, sz max_read, sz initial_capacity = 16)
{
	return self.init(tmem, max_read, initial_capacity);
}

<*
 Initialize the ByteBuffer with a fixed caller-owned buffer, without an allocator.

 The buffer cannot grow: writing more than fits panics, as there is no allocator to grow with.

 @param buf : "The buffer to use, it must outlive the ByteBuffer"
 @return "The initialized ByteBuffer"
 @require buf.len > 0
 @require self.bytes.len == 0 : "Buffer already initialized."
*>
fn ByteBuffer* ByteBuffer.init_with_buffer(&self, char[] buf)
{
	*self = { .max_read = buf.len, .bytes = buf };
	return self;
}

<*
 Free the internal buffer if it was allocated, and reset the ByteBuffer.
*>
fn void ByteBuffer.free(&self)
{
	if (self.allocator) alloc::free(self.allocator, self.bytes);
	*self = {};
}

<*
 Append bytes to the buffer, growing it as needed.

 @param [in] bytes : "The bytes to write"
 @return "The number of bytes written, always bytes.len"
*>
fn sz? ByteBuffer.write(&self, char[] bytes) @dynamic
{
	sz cap = self.bytes.len - self.write_idx;
	if (cap < bytes.len) self.grow(bytes.len);
	self.bytes[self.write_idx:bytes.len] = bytes[..];
	self.write_idx += bytes.len;
	return bytes.len;
}

<*
 Append a single byte to the buffer, growing it as needed.
*>
fn void? ByteBuffer.write_byte(&self, char c) @dynamic
{
	sz cap = self.bytes.len - self.write_idx;
	if (cap == 0) self.grow(1);
	self.bytes[self.write_idx] = c;
	self.write_idx++;
}

<*
 Read unread bytes into the buffer.

 @param [out] bytes : "The buffer to read into"
 @return "The number of bytes read, or 0 if there is no unread data"
*>
fn sz? ByteBuffer.read(&self, char[] bytes) @dynamic
{
	if (!bytes) return 0;
	sz readable = self.write_idx - self.read_idx;
	if (!readable)
	{
		self.has_last = false;
		return 0;
	}
	sz n = min(readable, bytes.len);
	bytes[:n] = self.bytes[self.read_idx:n];
	self.read_idx += n;
	self.has_last = n > 0;
	self.shrink();
	return n;
}

<*
 Read a single unread byte.

 @return "The byte read"
 @return? io::EOF : "If there is no unread data"
*>
fn char? ByteBuffer.read_byte(&self) @dynamic
{
	sz readable = self.write_idx - self.read_idx;
	if (readable == 0)
	{
		self.has_last = false;
		return io::EOF~;
	}
	char c = self.bytes[self.read_idx];
	self.read_idx++;
	self.has_last = true;
	self.shrink();
	return c;
}

<*
 Push back the last byte read, so it is read again.

 Only the last byte of a successful read can be pushed back.

 @return? io::EOF : "If the last read failed or a byte was already pushed back"
*>
fn void? ByteBuffer.pushback_byte(&self) @dynamic
{
	if (!self.has_last) return io::EOF~;
	assert(self.read_idx > 0);
	self.read_idx--;
	self.has_last = false;
}

<*
 Return the current read position in the internal buffer.

 @return "The read index, which is reset when the buffer is compacted"
*>
fn long? ByteBuffer.cursor(&self) @dynamic
{
	return self.read_idx;
}

<*
 Move the read position.

 Note that for `FROM_END` the offset is the (non-negative) distance back from the end of the written data.

 @param offset : "The offset relative to whence"
 @param whence : "Where the offset is relative to"
 @return? INVALID_POSITION : "If the position would be outside the written data"
*>
fn void? ByteBuffer.seek(&self, long offset, SeekOrigin whence = FROM_START) @dynamic
{
	switch (whence)
	{
		case FROM_START:
			if (offset < 0 || offset > self.write_idx) return INVALID_POSITION~;
			self.read_idx = (sz)offset;
		case FROM_CURSOR:
			if ((offset < 0 && self.read_idx < -offset) ||
				(offset > 0 && self.read_idx + offset > self.write_idx)) return INVALID_POSITION~;
			self.read_idx += (sz)offset;
		case FROM_END:
			if (offset < 0 || offset > self.write_idx) return INVALID_POSITION~;
			self.read_idx = self.write_idx - (sz)offset;
	}
}

<*
 Return the number of bytes written but not yet read.

 @return "The number of unread bytes"
*>
fn long? ByteBuffer.available(&self) @inline @dynamic
{
	return (long)self.write_idx - self.read_idx;
}

<*
 Grow the internal buffer by at least n bytes, rounding the capacity up to a power of 2.

 @param n : "The minimum number of bytes to add"
*>
fn void ByteBuffer.grow(&self, sz n)
{
	n = math::next_power_of_2(self.bytes.len + n);
	char* p = alloc::realloc(self.allocator, self.bytes, n);
	self.bytes = p[:n];
}

<*
 Compact the buffer once at least max_read bytes have been read, keeping the last read byte for `pushback_byte`.
*>
macro void ByteBuffer.shrink(&self)
{
	if (self.read_idx >= self.max_read)
	{
		// Drop the read data besides the last byte (for pushback_byte).
		sz readable = self.write_idx - self.read_idx;
		self.bytes[:1 + readable] = self.bytes[self.read_idx - 1:1 + readable];
		self.write_idx = 1 + readable;
		self.read_idx = 1;
	}
}
