module std::io;
import std::math;

<* A function pointer matching InStream.seek, taking the stream as an untyped pointer. *>
alias SeekFn = fn void?(void*, long offset, SeekOrigin whence = FROM_START);
<* A function pointer matching OutStream.write, taking the stream as an untyped pointer. *>
alias WriteFn = fn sz?(void*, char[] bytes);
<* A function pointer matching InStream.read, taking the stream as an untyped pointer. *>
alias ReadFn = fn sz?(void*, char[] buffer);
<* A function pointer matching OutStream.write_byte, taking the stream as an untyped pointer. *>
alias WriteByteFn = fn void?(void*, char c);

<*
 A readable stream of bytes. Implementations must provide `read` and `read_byte`;
 the other methods are optional and can be tested for with `&stream.method`.
*>
interface InStream
{
	<*
	 Close the stream and release any resources it holds.
	*>
	fn void? close() @optional;
	<*
	 Get the current read position in the stream.

	 @return "The offset from the start of the stream"
	*>
	fn long? cursor() @optional;
	<*
	 Move the read position of the stream.

	 @param offset : "The offset relative to `whence`"
	 @param whence : "Where the offset is measured from"
	 @return? io::INVALID_POSITION : "Typically returned if the new position is out of range"
	*>
	fn void? seek(long offset, SeekOrigin whence = FROM_START) @optional;
	<*
	 Get the total length of the stream data.

	 @return "The length in bytes"
	*>
	fn long len() @optional;
	<*
	 Get the total size of the stream data, if it can be determined.

	 @return "The size in bytes"
	*>
	fn long? size() @optional;
	<*
	 Get the number of bytes that can still be read from the stream.

	 @return "The number of remaining bytes"
	*>
	fn long? available() @optional;

	<*
	 Read bytes into the buffer. Will return 0 upon encountering end of the stream/file.
	 Reading after reaching the end should be idempotent. Reading 0 bytes should not
	 touch the underlying stream.

	 @param [inout] buffer : "The buffer to read into"
	 @return "The number of bytes read, or 0 if the end of the stream is reached"

	 @require buffer.len > 0 : "The buffer may not be zero length"
	*>
	fn sz? read(char[] buffer);
	<*
	 Read a single byte into the buffer. Will return io::EOF upon encountering the
	 end of the stream/file.

	 @return "A byte, read from the underlying stream"
	 @return? io::EOF
	*>
	fn char? read_byte();
	<*
	 Write the remaining stream data to an output stream, as an efficient
	 alternative to reading through an intermediate buffer. Used by `io::copy_to`.

	 @param out : "The stream to write to"
	 @return "The number of bytes written"
	*>
	fn long? write_to(OutStream out) @optional;
	<*
	 Step back one byte, so that the last byte read is returned by the next read.

	 @return? io::INVALID_PUSHBACK : "Typically returned if there is no byte to push back"
	*>
	fn void? pushback_byte() @optional;
}

<*
 A writable stream of bytes. Implementations must provide `write` and `write_byte`;
 the other methods are optional and can be tested for with `&stream.method`.
*>
interface OutStream
{
	<*
	 Release the resources held by the stream, such as allocated memory.
	*>
	fn void? destroy() @optional;
	<*
	 Close the stream. Whether pending data is flushed first depends on the implementation.
	*>
	fn void? close() @optional;
	<*
	 Write any buffered data to the underlying destination.
	*>
	fn void? flush() @optional;
	<*
	 Write bytes to the stream. This may write fewer bytes than given; use
	 `io::write_all` to write an entire buffer.

	 @param bytes : "The bytes to write"
	 @return "The number of bytes written"
	*>
	fn sz? write(char[] bytes);
	<*
	 Write a single byte to the stream.

	 @param c : "The byte to write"
	*>
	fn void? write_byte(char c);
	<*
	 Read all data from an input stream into this stream, as an efficient
	 alternative to copying through an intermediate buffer. Used by `io::copy_to`.

	 @param in : "The stream to read from"
	 @return "The number of bytes copied"
	*>
	fn long? read_to(InStream in) @optional;
}

<*
 An InStream together with its cached `read` function, avoiding a dynamic lookup on each read.
 Create it with `InStream.cached_stream`.
*>
struct CachedInStream
{
	inline InStream stream;
	ReadFn read_fn;
}

<*
 An OutStream together with its cached `write` function, avoiding a dynamic lookup on each write.
 Create it with `OutStream.cached_stream`.
*>
struct CachedOutStream
{
	inline OutStream stream;
	WriteFn write_fn;
}

<*
 Wrap the stream in a CachedOutStream, looking up its `write` method once.

 @return "The stream with its cached write function"
*>
macro CachedOutStream OutStream.cached_stream(self) => { self, &self.write };
<*
 Wrap the stream in a CachedInStream, looking up its `read` method once.

 #### Example:
 ```
 ByteReader reader = io::wrap_bytes("abc");
 CachedInStream s = ((InStream)&reader).cached_stream();
 char[4] buf;
 sz n = s.read(&buf)!!; // 3
 ```

 @return "The stream with its cached read function"
*>
macro CachedInStream InStream.cached_stream(self) => { self, &self.read };

<*
 Get the number of bytes left to read in a stream. Uses the stream's `available`
 method if it has one, otherwise seeks to the end and back to measure it.

 #### Example:
 ```
 ByteReader reader = io::wrap_bytes("hello");
 reader.read_byte()!!;
 long left = io::available(&reader)!!; // 4
 ```

 @param s : "The stream to check"
 @return "The number of bytes remaining"
 @return? io::UNSUPPORTED_OPERATION : "If the stream has neither `available` nor `seek` and `cursor`"
*>
fn long? available(InStream s)
{
	if (&s.available) return s.available();
	if (&s.seek && &s.cursor)
	{
		long curr = s.cursor()!;
		defer (void)s.seek(curr);
		s.seek(0, FROM_END)!;
		long len = s.cursor()!;
		return len - curr;
	}
	return io::UNSUPPORTED_OPERATION~;
}

<*
 Check at compile time whether an expression can be used as an input stream,
 that is, it converts to InStream or is a CachedInStream.

 @return "True if the expression is an input stream"
*>
macro bool @is_instream(#expr) @const
{
	return $Typeof(#expr) == CachedInStream ||| $defined(InStream i = #expr);
}

<*
 Check at compile time that an expression is not a stream value that should have
 been passed by pointer. Used in contracts to catch a missing `&`.

 @return "False if the address of the expression is an input stream"
*>
macro bool @is_not_instream_if_ptr(#expr) @const
{
	return !$defined(&#expr) ||| !@is_instream(&#expr);
}

<*
 Check at compile time whether an expression can be used as an output stream,
 that is, it converts to OutStream or is a CachedOutStream.

 @return "True if the expression is an output stream"
*>
macro bool @is_outstream(#expr) @const
{
	return $Typeof(#expr) == CachedOutStream ||| $defined(OutStream s = #expr);
}

<*
 Check at compile time that an expression is not a stream value that should have
 been passed by pointer. Used in contracts to catch a missing `&`.

 @return "False if the address of the expression is an output stream"
*>
macro bool @is_not_outstream_if_ptr(#expr) @const
{
	return !$defined(&#expr) ||| !@is_outstream(&#expr);
}

<*
 Read the raw bytes of a value from the stream, filling exactly the size of its type.

 #### Example:
 ```
 ByteReader reader = io::wrap_bytes({ 1, 0, 0, 0 });
 int result;
 io::read_any(&reader, &result)!!; // 1 on a little endian target
 ```

 @param stream : "The stream to read from"
 @param [&out] ref : "Pointer to the value to fill"
 @return "The number of bytes read, which is the size of the type"
 @return? UNEXPECTED_EOF : "If the stream ended before the value was filled"
 @require @is_instream(stream) : "Expected a stream"
*>
macro sz? read_any(stream, any ref)
{
	return read_all(stream, ((char*)ref)[:ref.type.size]);
}

<*
 Write the raw bytes of a value to the stream.

 #### Example:
 ```
 ByteWriter writer;
 writer.tinit();
 int value = 0x12345678;
 io::write_any(&writer, &value)!!; // 4
 ```

 @param stream : "The stream to write to"
 @param [&in] ref : "the object to write."
 @return "The number of bytes written, which is the size of the type"
 @return? INCOMPLETE_WRITE : "If the stream stopped accepting data"
 @require @is_outstream(stream)
 @ensure return == ref.type.size
*>
macro sz? write_any(stream, any ref)
{
	return write_all(stream, ((char*)ref)[:ref.type.size]);
}

<*
 Read from the stream until the buffer is completely filled.

 #### Example:
 ```
 ByteReader reader = io::wrap_bytes("abcdef");
 char[4] buf;
 io::read_all(&reader, &buf)!!; // buf is "abcd"
 if (catch err = io::read_all(&reader, &buf))
 {
 	// err is io::UNEXPECTED_EOF, only "ef" was left
 }
 ```

 @param stream : "The stream to read from"
 @param buffer : "The buffer to fill"
 @return "The number of bytes read, always buffer.len"
 @return? read_buffer_to_end!
 @return? UNEXPECTED_EOF : "If the buffer wasn't filled"
 @require @is_instream(stream)
*>
macro sz? read_all(stream, char[] buffer)
{
	sz n = read_buffer_to_end(stream, buffer).len!;
	if (n != buffer.len) return UNEXPECTED_EOF~;
	return n;
}

<*
 Read into a buffer, where reading an io::EOF returns 0.
 This is a single read, so it may read fewer bytes than the buffer holds.

 #### Example:
 ```
 ByteReader reader = io::wrap_bytes("abc");
 char[8] buf;
 sz n = io::read_buffer(&reader, &buf)!!; // 3
 n = io::read_buffer(&reader, &buf)!!;    // 0, end of stream
 ```

 @param stream : "The stream to read from"
 @param buffer : "The buffer to read into"
 @return "The number of bytes read, 0 if reading yields an io::EOF"
 @require buffer.len > 0 : "The buffer may not be empty."
*>
macro sz? read_buffer(stream, char[] buffer)
{
	sz? read = stream.read(buffer);
	if (catch err = read) return err == io::EOF ? 0 : err~;
	return read;
}

<*
 Read from the stream until the buffer is full or the stream ends.

 #### Example:
 ```
 ByteReader reader = io::wrap_bytes("abc");
 char[8] buf;
 char[] data = io::read_buffer_to_end(&reader, &buf)!!; // "abc"
 ```

 @param stream : "The stream to read from"
 @param buffer : "The buffer to read into"
 @return "The filled part of the buffer, shorter than the buffer if the stream ended first"
*>
macro char[]? read_buffer_to_end(stream, char[] buffer)
{
	sz len = buffer.len;
	if (!len) return buffer[:0];
	sz read = 0;
	while (read < len)
	{
		sz bytes_read = read_buffer(stream, buffer[read:len - read])!;
		read += bytes_read;
		if (!bytes_read) return buffer[:read];
	}
	return buffer[:len];
}

<*
 Read the stream to the end into newly allocated memory.

 #### Example:
 ```
 ByteReader reader = io::wrap_bytes("hello world");
 char[] data = io::read_fully(mem, &reader)!!;
 defer free(data);
 // data is "hello world"
 ```

 @param allocator : "The allocator for the returned data"
 @param stream : "The stream to read from"
 @return "The data read"
 @return? mem::INVALID_ALLOC_SIZE : "If the remaining stream data is too large to allocate"
 @require @is_instream(stream)
*>
macro char[]? read_fully(Allocator allocator, stream)
{
	// Efficient path if it is possible to pre-allocate
	if (try len = available(stream))
	{
		if (len > sz::max) return mem::INVALID_ALLOC_SIZE~;
		char* data = alloc::malloc_try(allocator, (sz)len)!;
		defer catch alloc::free(allocator, data);
		return read_buffer_to_end(stream, data[:len]);
	}
	ByteWriter writer;
	writer.init(allocator);
	copy_to(stream, &writer)!;
	return writer.array_view();
}


<*
 Write an entire buffer, calling `write` repeatedly until all bytes are written.

 #### Example:
 ```
 ByteWriter writer;
 writer.tinit();
 sz n = io::write_all(&writer, "hello")!!; // 5
 ```

 @param stream : "The stream to write to"
 @param buffer : "The bytes to write"
 @return "The number of bytes written, always buffer.len"
 @return? OutStream.write!, INCOMPLETE_WRITE
 @require @is_outstream(stream)
*>
macro sz? write_all(stream, char[] buffer)
{
	return fn sz?($Typeof(stream) s, char[] buffer) {
		sz len = buffer.len;
		if (!len) return 0;
		sz written;
		while (written < len)
		{
			sz write = s.write(buffer[written..])!;
			if (!write) break;
			written += write;
		}
		if (written != buffer.len) return INCOMPLETE_WRITE~;
		return written;
	}(stream, buffer);
}

<*
 Implement `read` by calling `read_byte` repeatedly, for streams that only read byte by byte.

 @param s : "The stream to read from"
 @param buffer : "The buffer to read into"
 @return "The number of bytes read, 0 at the end of the stream"
 @require @is_instream(s)
*>
macro sz? read_using_read_byte(s, char[] buffer)
{
	sz len = 0;
	foreach (&cptr : buffer)
	{
		char? c = s.read_byte();
		if (catch err = c)
		{
			if (err == io::EOF) return len;
			return err~;
		}
		*cptr = c;
		len++;
	}
	return len;
}

<*
 Implement `write_byte` by calling `write` with a one byte buffer.

 @param s : "The stream to write to"
 @param c : "The byte to write"
 @return? INCOMPLETE_WRITE : "If the byte was not written"
 @require @is_outstream(s)
*>
macro void? write_byte_using_write(s, char c)
{
	char[1] buff = { c };
	if (s.write(&buff)! == 0) return INCOMPLETE_WRITE~;
}

<*
 Implement `read_byte` by calling `read` with a one byte buffer.

 @param s : "The stream to read from"
 @return "The byte read"
 @return? io::EOF : "If the end of the stream was reached"
 @require @is_instream(s)
*>
macro char? read_byte_using_read(s)
{
	char[1] buffer;
	return read_buffer(s, &buffer)! ? buffer[0] : io::EOF~;
}

<* A function pointer type for a method-less `read_byte`. *>
alias ReadByteFn = fn char?();

<*
 Implement `write` by calling `write_byte` for each byte.

 @param s : "The stream to write to"
 @param bytes : "The bytes to write"
 @return "The number of bytes written, always bytes.len"
 @require @is_outstream(s)
*>
macro sz? write_using_write_byte(s, char[] bytes)
{
	foreach (c : bytes) s.write_byte(c)!;
	return bytes.len;
}

<*
 Implement `pushback_byte` by seeking back one byte from the cursor.

 @param s : "A stream supporting `seek`"
*>
macro void? pushback_using_seek(s)
{
	s.seek(-1, FROM_CURSOR)!;
}

<*
 Copy all remaining data from an input stream to an output stream.
 Without a buffer, it uses `in.write_to` or `dst.read_to` if available, otherwise
 it copies through a stack buffer.

 #### Example:
 ```
 ByteReader reader = io::wrap_bytes("some data");
 ByteWriter writer;
 writer.tinit();
 long copied = io::copy_to(&reader, &writer)!!; // 9
 ```

 @param in : "The stream to read from"
 @param dst : "The stream to write to"
 @param buffer : "An optional buffer to copy through"
 @return "The number of bytes copied"
 @return? INCOMPLETE_WRITE : "If the output stream did not accept all data"
*>
fn long? copy_to(InStream in, OutStream dst, char[] buffer = {})
{
	if (buffer.len) return copy_through_buffer(in, dst, buffer);
	if (&in.write_to) return in.write_to(dst);
	if (&dst.read_to) return dst.read_to(in);
	$switch env::MEMORY_ENV:
		$case NORMAL:
			return copy_through_buffer(in, dst, &&(char[4096]){});
		$case SMALL:
			return copy_through_buffer(in, dst, &&(char[1024]){});
		$case TINY:
		$case NONE:
			return copy_through_buffer(in, dst, &&(char[256]){});
	$endswitch
}

macro long? copy_through_buffer(InStream in, OutStream dst, char[] buffer) @local
{
	long total_copied;
	while (true)
	{
		sz? len = in.read(buffer);
		if (catch err = len)
		{
			if (err == io::EOF) return total_copied;
			return err~;
		}
		if (!len) return total_copied;
		sz written = dst.write(buffer[:len])!;
		total_copied += len;
		if (written != len) return INCOMPLETE_WRITE~;
	}
}

<*
 Read an integer in the variable length format written by `io::write_varint`.
 Read into the same integer type, signed or unsigned, as was written.

 #### Example:
 ```
 ByteWriter writer;
 writer.tinit();
 io::write_varint(&writer, (uint)300)!!; // 2 bytes: 0xAC 0x02
 io::write_varint(&writer, (int)-3)!!;
 ByteReader reader = io::wrap_bytes(writer.array_view());
 uint a;
 int b;
 io::read_varint(&reader, &a)!!; // a = 300
 io::read_varint(&reader, &b)!!; // b = -3
 ```

 @param stream : "The stream to read from"
 @param x_ptr : "Pointer to the integer to store the result in"
 @return "The number of bytes read"
 @return? io::UNEXPECTED_EOF : "If the stream ended in the middle of the value"
 @return? math::OVERFLOW : "If the encoded value is longer than the maximum of 19 bytes"
 @require @is_instream(stream)
 @require @kindof(x_ptr) == POINTER && @kindof(*x_ptr).is_int()
*>
macro sz? read_varint(stream, x_ptr)
{
	return read_varint_generic{$Typeof(stream), $Typeof(x_ptr)::inner}(stream, x_ptr);
}

fn sz? read_varint_generic(VarInStream stream, Type* ptr) <VarInStream, Type> @private
{
	const MAX = 19;
	const LAST_BYTE = 3;
	uint128 u;
	uint shift;
	sz n;
	for (sz i = 0; i < MAX; i++)
	{
		char? c = stream.read_byte();
		if (catch err = c)
		{
			if (err == io::EOF) return io::UNEXPECTED_EOF~;
			return err~;
		}
		n++;
		if (c & 0x80 == 0)
		{
			if (i + 1 == MAX && c > LAST_BYTE) break;
			u |= (uint128)c << shift;
			$if Type::kind == SIGNED_INT:
				*ptr = u & 1 == 0 ? (Type)(u >> 1) : -(Type)(u >> 1);
			$else
				*ptr = (Type)u;
			$endif
			return n;
		}
		u |= (uint128)(c & 0x7F) << shift;
		shift += 7;
	}
	return math::OVERFLOW~;
}


<*
 Write an integer in a variable length format, 7 bits per byte with the high bit
 marking that more bytes follow (LEB128). Signed values store the sign in the lowest bit,
 so an untyped literal like `300` is encoded as a signed int.

 #### Example:
 ```
 ByteWriter writer;
 writer.tinit();
 sz n = io::write_varint(&writer, (uint)300)!!; // 2, bytes 0xAC 0x02
 ```

 @param stream : "The stream to write to"
 @param x : "The integer to write"
 @return "The number of bytes written"
 @return? INCOMPLETE_WRITE : "If the stream did not accept all bytes"
 @require @is_outstream(stream)
 @require @kindof(x).is_int()
*>
macro sz? write_varint(stream, x)
{
	return write_varint_generic{$Typeof(stream), $Typeof(x)}(stream, x);
}

fn sz? write_varint_generic(VarOutStream stream, Type x) <VarOutStream, Type> @private
{
	const MAX = 19;
	char[MAX] buffer @noinit;
	sz i;
	$if Type::kind == SIGNED_INT:
		uint128 u = ((uint128)(x < 0 ? -x : x)) << 1;
		if (x < 0) u |= 1;
	$else
		uint128 u = (uint128)x;
	$endif
	while (u >= 0x80)
	{
		buffer[i] = (char)(u | 0x80);
		u >>= 7;
		i++;
	}
	buffer[i] = (char)u;
	return write_all(stream, buffer[:i + 1]);
}

<*
 Read a big endian short from the stream.

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro short? read_be_short(stream) => (short)read_be_ushort(stream);
<*
 Read a big endian int from the stream.

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro int? read_be_int(stream) => (int)read_be_uint(stream);
<*
 Read a big endian long from the stream.

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro long? read_be_long(stream) => (long)read_be_ulong(stream);
<*
 Read a big endian int128 from the stream.

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro int128? read_be_int128(stream) => (int128)read_be_uint128(stream);

<*
 Read a little endian short from the stream.

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro short? read_le_short(stream) => (short)read_le_ushort(stream);
<*
 Read a little endian int from the stream.

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro int? read_le_int(stream) => (int)read_le_uint(stream);
<*
 Read a little endian long from the stream.

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro long? read_le_long(stream) => (long)read_le_ulong(stream);
<*
 Read a little endian int128 from the stream.

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro int128? read_le_int128(stream) => (int128)read_le_uint128(stream);


<*
 Write a short to the stream in big endian byte order.

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_be_short(stream, short s) => write_be_ushort(stream, (ushort)s);
<*
 Write a int to the stream in big endian byte order.

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_be_int(stream, int s) => write_be_uint(stream, (uint)s);
<*
 Write a long to the stream in big endian byte order.

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_be_long(stream, long s) => write_be_ulong(stream, (ulong)s);
<*
 Write a int128 to the stream in big endian byte order.

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_be_int128(stream, int128 s) => write_be_uint128(stream, (uint128)s);

<*
 Write a short to the stream in little endian byte order.

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_le_short(stream, short s) => write_le_ushort(stream, (ushort)s);
<*
 Write a int to the stream in little endian byte order.

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_le_int(stream, int s) => write_le_uint(stream, (uint)s);
<*
 Write a long to the stream in little endian byte order.

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_le_long(stream, long s) => write_le_ulong(stream, (ulong)s);
<*
 Write a int128 to the stream in little endian byte order.

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_le_int128(stream, int128 s) => write_le_uint128(stream, (uint128)s);

<*
 Read a big endian ushort from the stream.

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro ushort? read_be_ushort(stream)
{
	char hi_byte = stream.read_byte()!;
	char lo_byte = stream.read_byte()!;
	return (ushort)(hi_byte << 8 | lo_byte);
}

<*
 Read a little endian ushort from the stream.

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro ushort? read_le_ushort(stream)
{
	char lo_byte = stream.read_byte()!;
	char hi_byte = stream.read_byte()!;
	return (ushort)(hi_byte << 8 | lo_byte);
}

<*
 Write a ushort to the stream in big endian byte order.

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_be_ushort(stream, ushort s)
{
	stream.write_byte((char)(s >> 8))!;
	stream.write_byte((char)s)!;
}

<*
 Write a ushort to the stream in little endian byte order.

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_le_ushort(stream, ushort s)
{
	stream.write_byte((char)s)!;
	stream.write_byte((char)(s >> 8))!;
}

<*
 Read a big endian uint from the stream.

 #### Example:
 ```
 ByteReader reader = io::wrap_bytes({ 1, 2, 3, 4 });
 uint x = io::read_be_uint(&reader)!!; // 0x01020304
 ```

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro uint? read_be_uint(stream)
{
	uint val = stream.read_byte()! << 24;
	val += stream.read_byte()! << 16;
	val += stream.read_byte()! << 8;
	return val + stream.read_byte()!;
}

<*
 Read a little endian uint from the stream.

 #### Example:
 ```
 ByteReader reader = io::wrap_bytes({ 4, 3, 2, 1 });
 uint x = io::read_le_uint(&reader)!!; // 0x01020304
 ```

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro uint? read_le_uint(stream)
{
	uint val = stream.read_byte()!;
	val += stream.read_byte()! << 8;
	val += stream.read_byte()! << 16;
	return val + stream.read_byte()! << 24;
}


<*
 Write a uint to the stream in big endian byte order.

 #### Example:
 ```
 ByteWriter writer;
 writer.tinit();
 io::write_be_uint(&writer, 0x01020304)!!; // bytes: 1, 2, 3, 4
 ```

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_be_uint(stream, uint s)
{
	stream.write_byte((char)(s >> 24))!;
	stream.write_byte((char)(s >> 16))!;
	stream.write_byte((char)(s >> 8))!;
	stream.write_byte((char)s)!;
}

<*
 Write a uint to the stream in little endian byte order.

 #### Example:
 ```
 ByteWriter writer;
 writer.tinit();
 io::write_le_uint(&writer, 0x01020304)!!; // bytes: 4, 3, 2, 1
 ```

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_le_uint(stream, uint s)
{
	stream.write_byte((char)s)!;
	stream.write_byte((char)(s >> 8))!;
	stream.write_byte((char)(s >> 16))!;
	stream.write_byte((char)(s >> 24))!;
}

<*
 Read a big endian ulong from the stream.

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro ulong? read_be_ulong(stream)
{
	ulong val = (ulong)stream.read_byte()! << 56;
	val += (ulong)stream.read_byte()! << 48;
	val += (ulong)stream.read_byte()! << 40;
	val += (ulong)stream.read_byte()! << 32;
	val += (ulong)stream.read_byte()! << 24;
	val += (ulong)stream.read_byte()! << 16;
	val += (ulong)stream.read_byte()! << 8;
	return val + stream.read_byte()!;
}

<*
 Read a little endian ulong from the stream.

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro ulong? read_le_ulong(stream)
{
	ulong val = (ulong)stream.read_byte()!;
	val += (ulong)stream.read_byte()! << 8;
	val += (ulong)stream.read_byte()! << 16;
	val += (ulong)stream.read_byte()! << 24;
	val += (ulong)stream.read_byte()! << 32;
	val += (ulong)stream.read_byte()! << 40;
	val += (ulong)stream.read_byte()! << 48;
	return val + (ulong)stream.read_byte()! << 56;
}

<*
 Write a ulong to the stream in big endian byte order.

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_be_ulong(stream, ulong s)
{
	stream.write_byte((char)(s >> 56))!;
	stream.write_byte((char)(s >> 48))!;
	stream.write_byte((char)(s >> 40))!;
	stream.write_byte((char)(s >> 32))!;
	stream.write_byte((char)(s >> 24))!;
	stream.write_byte((char)(s >> 16))!;
	stream.write_byte((char)(s >> 8))!;
	stream.write_byte((char)s)!;
}

<*
 Write a ulong to the stream in little endian byte order.

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_le_ulong(stream, ulong s)
{
	stream.write_byte((char)s)!;
	stream.write_byte((char)(s >> 8))!;
	stream.write_byte((char)(s >> 16))!;
	stream.write_byte((char)(s >> 24))!;
	stream.write_byte((char)(s >> 32))!;
	stream.write_byte((char)(s >> 40))!;
	stream.write_byte((char)(s >> 48))!;
	stream.write_byte((char)(s >> 56))!;
}

<*
 Read a big endian uint128 from the stream.

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro uint128? read_be_uint128(stream)
{
	uint128 val = (uint128)stream.read_byte()! << 120;
	val += (uint128)stream.read_byte()! << 112;
	val += (uint128)stream.read_byte()! << 104;
	val += (uint128)stream.read_byte()! << 96;
	val += (uint128)stream.read_byte()! << 88;
	val += (uint128)stream.read_byte()! << 80;
	val += (uint128)stream.read_byte()! << 72;
	val += (uint128)stream.read_byte()! << 64;
	val += (uint128)stream.read_byte()! << 56;
	val += (uint128)stream.read_byte()! << 48;
	val += (uint128)stream.read_byte()! << 40;
	val += (uint128)stream.read_byte()! << 32;
	val += (uint128)stream.read_byte()! << 24;
	val += (uint128)stream.read_byte()! << 16;
	val += (uint128)stream.read_byte()! << 8;
	return val + stream.read_byte()!;
}

<*
 Read a little endian uint128 from the stream.

 @return "The value read"
 @return? io::EOF : "If the stream ended before the whole value was read"
 @require @is_instream(stream)
*>
macro uint128? read_le_uint128(stream)
{
	uint128 val = stream.read_byte()!;
	val += (uint128)stream.read_byte()! << 8;
	val += (uint128)stream.read_byte()! << 16;
	val += (uint128)stream.read_byte()! << 24;
	val += (uint128)stream.read_byte()! << 32;
	val += (uint128)stream.read_byte()! << 40;
	val += (uint128)stream.read_byte()! << 48;
	val += (uint128)stream.read_byte()! << 56;
	val += (uint128)stream.read_byte()! << 64;
	val += (uint128)stream.read_byte()! << 72;
	val += (uint128)stream.read_byte()! << 80;
	val += (uint128)stream.read_byte()! << 88;
	val += (uint128)stream.read_byte()! << 96;
	val += (uint128)stream.read_byte()! << 104;
	val += (uint128)stream.read_byte()! << 112;
	return val + (uint128)stream.read_byte()! << 120;
}

<*
 Write a uint128 to the stream in big endian byte order.

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_be_uint128(stream, uint128 s)
{
	stream.write_byte((char)(s >> 120))!;
	stream.write_byte((char)(s >> 112))!;
	stream.write_byte((char)(s >> 104))!;
	stream.write_byte((char)(s >> 96))!;
	stream.write_byte((char)(s >> 88))!;
	stream.write_byte((char)(s >> 80))!;
	stream.write_byte((char)(s >> 72))!;
	stream.write_byte((char)(s >> 64))!;
	stream.write_byte((char)(s >> 56))!;
	stream.write_byte((char)(s >> 48))!;
	stream.write_byte((char)(s >> 40))!;
	stream.write_byte((char)(s >> 32))!;
	stream.write_byte((char)(s >> 24))!;
	stream.write_byte((char)(s >> 16))!;
	stream.write_byte((char)(s >> 8))!;
	stream.write_byte((char)s)!;
}

<*
 Write a uint128 to the stream in little endian byte order.

 @param s : "The value to write"
 @require @is_outstream(stream)
*>
macro void? write_le_uint128(stream, uint128 s)
{
	stream.write_byte((char)s)!;
	stream.write_byte((char)(s >> 8))!;
	stream.write_byte((char)(s >> 16))!;
	stream.write_byte((char)(s >> 24))!;
	stream.write_byte((char)(s >> 32))!;
	stream.write_byte((char)(s >> 40))!;
	stream.write_byte((char)(s >> 48))!;
	stream.write_byte((char)(s >> 56))!;
	stream.write_byte((char)(s >> 64))!;
	stream.write_byte((char)(s >> 72))!;
	stream.write_byte((char)(s >> 80))!;
	stream.write_byte((char)(s >> 88))!;
	stream.write_byte((char)(s >> 96))!;
	stream.write_byte((char)(s >> 104))!;
	stream.write_byte((char)(s >> 112))!;
	stream.write_byte((char)(s >> 120))!;

}

<*
 Write a byte array prefixed with its length as a single byte.

 #### Example:
 ```
 ByteWriter writer;
 writer.tinit();
 sz n = io::write_tiny_bytearray(&writer, "abc")!!; // 4: length byte + 3 bytes
 ByteReader reader = io::wrap_bytes(writer.array_view());
 char[] data = io::read_tiny_bytearray(&reader, tmem)!!; // "abc"
 ```

 @param stream : "The stream to write to"
 @param data : "The bytes to write, at most 255"
 @return "The number of bytes written, including the length byte"
 @return? INCOMPLETE_WRITE : "If the stream did not accept all bytes"
 @require @is_outstream(stream)
 @require data.len < 256 : "Data exceeded 255"
*>
macro sz? write_tiny_bytearray(stream, char[] data)
{
	stream.write_byte((char)data.len)!;
	return write_all(stream, data) + 1;
}

<*
 Read a byte array written by `io::write_tiny_bytearray`: a length byte followed by the data.

 @param stream : "The stream to read from"
 @param allocator : "The allocator for the returned data"
 @return "The data read, empty if the length was 0; the caller owns the memory"
 @return? io::EOF : "If the stream ended before the length byte"
 @return? UNEXPECTED_EOF : "If the stream ended before all data was read"
 @require @is_instream(stream)
*>
macro char[]? read_tiny_bytearray(stream, Allocator allocator)
{
	int len = stream.read_byte()!;
	if (!len) return {};
	char[] data = alloc::alloc_array(allocator, char, len);
	io::read_all(stream, data)!;
	return data;
}

<*
 Write a byte array prefixed with its length as a big endian ushort.

 #### Example:
 ```
 ByteWriter writer;
 writer.tinit();
 sz n = io::write_short_bytearray(&writer, "abc")!!; // 5: 2 length bytes + 3 bytes
 ByteReader reader = io::wrap_bytes(writer.array_view());
 char[] data = io::read_short_bytearray(&reader, tmem)!!; // "abc"
 ```

 @param stream : "The stream to write to"
 @param data : "The bytes to write"
 @return "The number of bytes written, including the 2 length bytes"
 @return? INCOMPLETE_WRITE : "If the stream did not accept all bytes"
 @require @is_outstream(stream)
 @require data.len < 0x1000 : "Data exceeded 65535"
*>
macro sz? write_short_bytearray(stream, char[] data)
{
	io::write_be_ushort(stream, (ushort)data.len)!;
	return write_all(stream, data) + 2;
}

<*
 Read a byte array written by `io::write_short_bytearray`: a big endian ushort length followed by the data.

 @param stream : "The stream to read from"
 @param allocator : "The allocator for the returned data"
 @return "The data read, empty if the length was 0; the caller owns the memory"
 @return? io::EOF : "If the stream ended inside the length"
 @return? UNEXPECTED_EOF : "If the stream ended before all data was read"
 @require @is_instream(stream)
*>
macro char[]? read_short_bytearray(stream, Allocator allocator)
{
	int len = io::read_be_ushort(stream)!;
	if (!len) return {};
	char[] data = alloc::alloc_array(allocator, char, len);
	io::read_all(stream, data)!;
	return data;
}

<*
 Skip over bytes in the stream, seeking if the stream supports it and reading byte by byte otherwise.

 #### Example:
 ```
 ByteReader reader = io::wrap_bytes("abcdef");
 io::skip(&reader, 3)!!;
 char c = reader.read_byte()!!; // 'd'
 ```

 @param stream : "The stream to skip in"
 @param bytes : "The number of bytes to skip"
 @return? io::EOF : "If the stream ended while reading past the bytes"
 @return? io::INVALID_POSITION : "If the stream is seekable and the new position is past the end"
 @require @is_instream(stream)
*>
macro void? skip(stream, sz bytes)
{
	if (!bytes) return;
	$switch:
		$case $Typeof(stream) == InStream:
			if (!&stream.seek)
			{
				for (sz i = 0; i < bytes; i++)
				{
					stream.read_byte()!;
				}
				return;
			}
			stream.seek(bytes, FROM_CURSOR)!;
		$case $defined(stream.seek):
			stream.seek(bytes, FROM_CURSOR)!;
		$default:
			for (sz i = 0; i < bytes; i++)
			{
				stream.read_byte()!;
			}
	$endswitch
}

<*
 Wrap bytes for reading using io functions. The bytes are not copied.

 #### Example:
 ```
 ByteReader reader = io::wrap_bytes("hi");
 char c = reader.read_byte()!!; // 'h'
 ```

 @param bytes : "The bytes to read from"
 @return "A ByteReader positioned at the start of the bytes"
*>
fn ByteReader wrap_bytes(char[] bytes)
{
	return { bytes, 0 };
}

<*
 Write bytes using the cached write function.

 @param bytes : "The bytes to write"
 @return "The number of bytes written"
*>
macro sz? CachedOutStream.write(self, char[] bytes)
{
	return self.write_fn(self.ptr, bytes);
}

<*
 Read into the buffer using the cached read function.

 @param buffer : "The buffer to read into"
 @return "The number of bytes read"
*>
macro sz? CachedInStream.read(self, char[] buffer)
{
	return self.read_fn(self.ptr, buffer);
}