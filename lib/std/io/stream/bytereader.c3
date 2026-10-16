module std::io;

<*
 An InStream that reads from a byte slice, with seek and pushback support.

 It does not copy or own the bytes, and needs no cleanup. See also `io::wrap_bytes`.

 #### Example:
 ```
 ByteReader reader;
 reader.init("hello world");
 char[5] word;
 io::read_all(&reader, &word)!!; // word is "hello"
 reader.seek(1, FROM_CURSOR)!!;
 char[16] buf;
 sz n = reader.read(&buf)!!; // 5, buf[:n] is "world"
 ```
*>
struct ByteReader (InStream)
{
	char[] bytes;
	sz index;
}

<*
 Return the total length of the underlying bytes, regardless of the read position.

 @return "The number of bytes in the reader"
*>
fn long ByteReader.len(&self) @dynamic
{
	return self.bytes.len;
}

<*
 Initialize the reader to read from the start of the bytes.

 @param bytes : "The bytes to read, they must outlive the reader"
 @return "The initialized ByteReader"
*>
fn ByteReader* ByteReader.init(&self, char[] bytes)
{
	*self = { .bytes = bytes };
	return self;
}

<*
 Read bytes into the buffer.

 @param [out] bytes : "The buffer to read into"
 @return "The number of bytes read, or 0 if the end is reached"
*>
fn sz? ByteReader.read(&self, char[] bytes) @dynamic
{
	sz len = min(self.bytes.len - self.index, bytes.len);
	if (len < 1) return 0;
	mem::copy(bytes.ptr, &self.bytes[self.index], len);
	self.index += len;
	return len;
}

<*
 Read a single byte.

 @return "The byte read"
 @return? io::EOF : "If the end is reached"
*>
fn char? ByteReader.read_byte(&self) @dynamic
{
	if (self.index >= self.bytes.len) return io::EOF~;
	return self.bytes[self.index++];
}

<*
 Move the read position back one byte.

 @return? INVALID_PUSHBACK : "If at the start of the bytes"
*>
fn void? ByteReader.pushback_byte(&self) @dynamic
{
	if (!self.index) return INVALID_PUSHBACK~;
	self.index--;
}

<*
 Return the current read position.

 @return "The read position"
*>
fn long? ByteReader.cursor(&self) @dynamic
{
	return self.index;
}

<*
 Move the read position. For `FROM_END` the offset is added to the length, so it should be zero or negative.

 @param offset : "The offset relative to whence"
 @param whence : "Where the offset is relative to"
 @return? INVALID_POSITION : "If the position would be before the start or past the end"
*>
fn void? ByteReader.seek(&self, long offset, SeekOrigin whence = FROM_START) @dynamic
{
	long new_index;
	switch (whence)
	{
		case FROM_START:  new_index = offset;
		case FROM_CURSOR: new_index = self.index + offset;
		case FROM_END:    new_index = self.bytes.len + offset;
	}
	if (new_index < 0 || new_index > self.bytes.len) return INVALID_POSITION~;
	self.index = (sz)new_index;
}

<*
 Write the remaining unread bytes to an OutStream, advancing the read position by the amount written.

 @param writer : "The stream to write to"
 @return "The number of bytes written"
*>
fn long? ByteReader.write_to(&self, OutStream writer) @dynamic
{
	if (self.index >= self.bytes.len) return 0;
	sz written = writer.write(self.bytes[self.index..])!;
	self.index += written;
	assert(self.index <= self.bytes.len);
	return written;
}

<*
 Return the number of unread bytes.

 @return "The number of bytes left to read"
*>
fn long? ByteReader.available(&self) @inline @dynamic
{
	return max(0, self.bytes.len - self.index);
}
