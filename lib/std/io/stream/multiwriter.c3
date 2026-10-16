module std::io;

<*
 MultiWriter implements the OutStream interface and duplicates any write
 operation to all the wrapped writers.

 `init` allocates a copy of the writer list, release it with `free`. The wrapped
 writers are not owned and are never flushed or closed by the MultiWriter.

 #### Example:
 ```
 ByteWriter w1, w2;
 w1.tinit();
 w2.tinit();
 MultiWriter mw;
 mw.init(mem, &w1, &w2);
 defer mw.free();
 io::fprint(&mw, "hi")!!;
 // w1.str_view() and w2.str_view() are both "hi"
 ```
*>
struct MultiWriter (OutStream)
{
	CachedOutStream[] writers;
	Allocator allocator;
}

<*
 Initialize the MultiWriter to write to all the given writers.

 Allocates a list of the writers using the allocator, release it with `free`.

 @param [&inout] self
 @param [&inout] allocator
 @param writers : "The writers to duplicate writes to"
 @return "The initialized MultiWriter"
 @require writers.len > 0
 @require self.writers.len == 0 : "Init may not run on already initialized data"
*>
fn MultiWriter* MultiWriter.init(&self, Allocator allocator, OutStream... writers)
{
	CachedOutStream[] copy = alloc::new_array(allocator, CachedOutStream, writers.len);
	foreach (i, stream : writers) copy[i] = stream.cached_stream();
	*self = { .writers = copy, .allocator = allocator };
	return self;
}

<*
 Initialize the MultiWriter using the temp allocator, see `init`.

 @param [&inout] self
 @param writers : "The writers to duplicate writes to"
 @return "The initialized MultiWriter"
 @require writers.len > 0
 @require self.writers.len == 0 : "Init may not run on already initialized data"
*>
fn MultiWriter* MultiWriter.tinit(&self, OutStream... writers)
{
	return self.init(tmem, ...writers);
}

<*
 Free the list of writers and reset the MultiWriter. The writers themselves are not closed.
*>
fn void MultiWriter.free(&self)
{
	if (!self.allocator) return;
	alloc::free(self.allocator, self.writers);
	*self = {};
}

<*
 Write the bytes to each writer in turn, stopping at the first failure.

 @param [in] bytes : "The bytes to write"
 @return "The number of bytes written, always bytes.len"
 @return? INCOMPLETE_WRITE : "If a writer did not accept all bytes"
*>
fn sz? MultiWriter.write(&self, char[] bytes) @dynamic
{
	sz n;
	foreach (w : self.writers)
	{
		n = w.write(bytes)!;
		if (n != bytes.len) return INCOMPLETE_WRITE~;
	}
	return bytes.len;
}

<*
 Write a single byte to each writer.

 @return? INCOMPLETE_WRITE : "If a writer did not accept the byte"
*>
fn void? MultiWriter.write_byte(&self, char c) @dynamic
{
	char[1] data;
	data[0] = c;
	self.write(data[..])!;
}
