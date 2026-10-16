module std::io;

<*
 MultiReader implements the InStream interface and provides a logical
 concatenation of the provided readers. They are read sequentially. If all the
 data has been read, the end of the stream is reported.

 `init` allocates a copy of the reader list, release it with `free`. The wrapped
 readers are not owned and are never closed by the MultiReader.

 #### Example:
 ```
 ByteReader a, b;
 a.init("hello ");
 b.init("world");
 MultiReader mr;
 mr.init(mem, &a, &b);
 defer mr.free();
 char[32] buf;
 char[] data = io::read_buffer_to_end(&mr, &buf)!!; // "hello world"
 ```
*>
struct MultiReader (InStream)
{
	CachedInStream[] readers;
	sz index;
	Allocator allocator;
}


<*
 Initialize the MultiReader to read the given readers in order.

 Allocates a list of the readers using the allocator, release it with `free`.

 @param [&inout] self
 @param [&inout] allocator
 @param readers : "The readers to read from, in order"
 @return "The initialized MultiReader"
 @require self.readers.len == 0 : "Init may not run on already initialized data"
 @ensure self.index == 0
*>
fn MultiReader* MultiReader.init(&self, Allocator allocator, InStream... readers)
{
	CachedInStream[] copy = alloc::new_array(allocator, CachedInStream, readers.len);
	foreach (i, stream : readers) copy[i] = stream.cached_stream();
	*self = { .readers = copy, .allocator = allocator };
	return self;
}

<*
 Initialize the MultiReader using the temp allocator, see `init`.

 @param [&inout] self
 @param readers : "The readers to read from, in order"
 @return "The initialized MultiReader"
 @require self.readers.len == 0 : "Init may not run on already initialized data"
 @ensure self.index == 0
*>
fn MultiReader* MultiReader.tinit(&self, InStream... readers)
{
	return self.init(tmem, ...readers);
}

<*
 Free the list of readers and reset the MultiReader. The readers themselves are not closed.
*>
fn void MultiReader.free(&self)
{
	if (!self.allocator) return;
	alloc::free(self.allocator, self.readers);
	*self = {};
}

<*
 Read bytes from the current reader, moving on to the next reader when it reaches its end.

 @param [out] buffer : "The buffer to read into"
 @return "The number of bytes read, or 0 if all readers have reached their end"
*>
fn sz? MultiReader.read(&self, char[] buffer) @dynamic
{
	while (true)
	{
		if (self.index >= self.readers.len) return 0;
		InStream r = self.readers[self.index];
		if (sz n = read_buffer(r, buffer)!) return n;
		self.index++;
	}
}

<*
 Read a single byte, moving on to the next reader as needed.

 @return "The byte read"
 @return? io::EOF : "If all readers have reached their end"
*>
fn char? MultiReader.read_byte(&self) @dynamic
{
	return read_byte_using_read(self);
}
