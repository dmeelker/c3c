module std::io;

<*
 An InStream that writes everything it reads from a wrapped reader to a writer.

 It does not allocate, buffer or own either stream, and has no close.

 #### Example:
 ```
 ByteReader src;
 src.init("data");
 ByteWriter copy;
 copy.tinit();
 TeeReader tee = io::tee_reader(&src, &copy);
 char[16] buf;
 sz n = tee.read(&buf)!!; // 4, buf[:n] is "data"
 // copy.str_view() is also "data"
 ```
*>
struct TeeReader (InStream)
{
	CachedInStream r;
	CachedOutStream w;
}

<*
 Returns a reader that implements InStream and that will write any data read
 from the wrapped reader r to the writer w. There is no internal buffering.

 @param [&inout] r : "Stream r to read from."
 @param [&inout] w : "Stream w to write to what it reads from r."
 @return "The TeeReader, by value"
*>
macro TeeReader tee_reader(InStream r, OutStream w)
{
	return { .r = r.cached_stream(), .w = w.cached_stream() };
}

<*
 Initialize the TeeReader, see `tee_reader`.

 @param [&inout] self
 @param [&inout] r : "Stream r to read from."
 @param [&inout] w : "Stream w to write to what it reads from r."
 @return "The initialized TeeReader"
*>
fn TeeReader* TeeReader.init(&self, InStream r, OutStream w)
{
	*self = tee_reader(r, w);
	return self;
}

<*
 Read bytes from the wrapped reader and write all of them to the writer.

 @param [out] buffer : "The buffer to read into"
 @return "The number of bytes read, or 0 if the end of the stream is reached"
 @return? INCOMPLETE_WRITE : "If the writer did not accept all bytes"
*>
fn sz? TeeReader.read(&self, char[] buffer) @dynamic
{
	sz nr = self.r.read(buffer)!;
	if (!nr) return 0;
	io::write_all(self.w, buffer[:nr])!;
	return nr;
}

<*
 Read a single byte from the wrapped reader and write it to the writer.

 @return "The byte read"
 @return? io::EOF : "If the end of the stream is reached"
*>
fn char? TeeReader.read_byte(&self) @dynamic
{
	char[1] data;
	return self.read(data[..])! ? data[0] : io::EOF~;
}
