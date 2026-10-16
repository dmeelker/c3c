module std::io;
import std::math;

<*
 An OutStream that writes into a byte buffer, either growable (with an allocator) or fixed size.

 With `init`/`tinit` the buffer is allocated and grown as needed; release it with `destroy`.
 With `init_with_buffer` the caller's buffer is used, and writing past its end fails with OUT_OF_SPACE.

 #### Example:
 ```
 ByteWriter writer;
 writer.init(mem);
 defer (void)writer.destroy();
 io::fprintf(&writer, "%d-%s", 42, "abc")!!;
 String s = writer.str_view(); // "42-abc"
 ```
*>
struct ByteWriter (OutStream)
{
	char[] bytes;
	sz index;
	Allocator allocator;
}

<*
 Initialize a growable ByteWriter, release its memory with `destroy`.

 @param [&inout] self
 @param [&inout] allocator
 @param reserve : "The bytes to reserve up front, defaults to 0"
 @return "The initialized ByteWriter"

 @require self.bytes.len == 0 : "Init may not run on already initialized data"
 @ensure (bool)allocator, self.index == 0
*>
fn ByteWriter* ByteWriter.init(&self, Allocator allocator, sz reserve = 0)
{
	*self = { .bytes = {}, .allocator = allocator };
	if (reserve > 0) self.ensure_capacity(reserve)!!;
	return self;
}

<*
 Initialize a growable ByteWriter using the temp allocator.

 @param [&inout] self
 @param reserve : "The bytes to reserve up front, defaults to 0"
 @return "The initialized ByteWriter"

 @require self.bytes.len == 0 : "Init may not run on already initialized data"
 @ensure self.index == 0
*>
fn ByteWriter* ByteWriter.tinit(&self, sz reserve = 0)
{
	return self.init(tmem, reserve) @inline;
}

<*
 Initialize a ByteWriter that writes into a fixed caller-owned buffer and never allocates.

 @param data : "The buffer to write into, it must outlive the writer"
 @return "The initialized ByteWriter"
*>
fn ByteWriter* ByteWriter.init_with_buffer(&self, char[] data)
{
	*self = { .bytes = data, .allocator = null };
	return self;
}

<*
 Free the buffer if it was allocated by the writer, and reset it. Does nothing for `init_with_buffer` writers.
*>
fn void? ByteWriter.destroy(&self) @dynamic
{
	if (!self.allocator) return;
	if (void* ptr = self.bytes.ptr) alloc::free(self.allocator, ptr);
	*self = { };
}

<*
 Return the bytes written so far.

 @return "A view into the buffer, invalidated by further writes or destroy"
*>
fn char[] ByteWriter.array_view(self) @inline
{
	return self.bytes[:self.index];
}

<*
 Return the bytes written so far as a String.

 @return "A view into the buffer, invalidated by further writes or destroy"
*>
fn String ByteWriter.str_view(&self) @inline
{
	return (String)self.bytes[:self.index];
}

<*
 Make sure the buffer can hold at least len bytes in total, growing it to a power of 2 (minimum 16) if needed.

 @param len : "The total capacity required"
 @return? OUT_OF_SPACE : "If the buffer is too small and the writer has no allocator"
 @return? mem::OUT_OF_MEMORY : "If growing the buffer fails"
*>
fn void? ByteWriter.ensure_capacity(&self, sz len) @inline
{
	if (self.bytes.len >= len) return;
	if (!self.allocator) return OUT_OF_SPACE~;
	if (len < 16) len = 16;
	sz new_capacity = math::next_power_of_2(len);
	char* new_ptr = alloc::realloc_try(self.allocator, self.bytes.ptr, new_capacity)!;
	self.bytes = new_ptr[:new_capacity];
}

<*
 Append bytes, growing the buffer if needed.

 @param [in] bytes : "The bytes to write"
 @return "The number of bytes written, always bytes.len"
 @return? OUT_OF_SPACE : "If a fixed buffer is full"
*>
fn sz? ByteWriter.write(&self, char[] bytes) @dynamic
{
	if (!bytes.len) return 0;
	self.ensure_capacity(self.index + bytes.len)!;
	mem::copy(&self.bytes[self.index], bytes.ptr, bytes.len);
	self.index += bytes.len;
	return bytes.len;
}

<*
 Append a single byte, growing the buffer if needed.

 @return? OUT_OF_SPACE : "If a fixed buffer is full"
*>
fn void? ByteWriter.write_byte(&self, char c) @dynamic
{
	self.ensure_capacity(self.index + 1)!;
	self.bytes[self.index++] = c;
}

<*
 Read everything from an InStream until its end and append it to the buffer.

 @param [&inout] self
 @param reader : "The stream to read from"
 @return "The number of bytes appended"
 @return? OUT_OF_SPACE : "If a fixed buffer is full"
*>
fn long? ByteWriter.read_from(&self, InStream reader) @dynamic
{
	sz start_index = self.index;
	if (&reader.available)
	{
		while (long available = reader.available()!)
		{
			if (available > sz::max) return OUT_OF_SPACE~;
			self.ensure_capacity(self.index + (sz)available)!;
			assert(self.bytes.len > self.index);
			sz read = read_buffer(reader, self.bytes[self.index..])!;
			if (!read) break;
			self.index += read;
		}
		return (long)self.index - start_index;
	}
	if (self.bytes.len == 0)
	{
		self.ensure_capacity(256)!;
	}
	while (true)
	{
		// See how much we can read.
		sz len_to_read = self.bytes.len - self.index;
		// Less than 16 bytes? Double the capacity
		if (len_to_read < 16)
		{
			self.ensure_capacity(self.bytes.len * 2)!;
			len_to_read = self.bytes.len - self.index;
		}
		// Read into the rest of the buffer
		assert(self.bytes.len > self.index);
		sz read = read_buffer(reader, self.bytes[self.index..])!;
		self.index += read;
		// Ok, we reached the end.
		if (read < len_to_read) return (long)self.index - start_index;
		// Otherwise go another round
	}
}
