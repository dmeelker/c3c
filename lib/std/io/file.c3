module std::io;
import libc;

<* A buffered file handle wrapping a C `FILE*`, usable as both an `InStream` and an `OutStream`. *>
struct File (InStream, OutStream)
{
	CFile file;
}

module std::io::file;
import libc, std::io::path, std::io::os, std::time;

<*
 Open a file with a C `fopen`-style mode string such as "rb", "w" or "a+".

 #### Example:
 ```
 File f = file::open("data.txt", "w")!!;
 defer (void)f.close();
 io::fprintn(&f, "Hello")!!;
 ```

 @param filename : "The path of the file to open"
 @param mode : "The open mode, e.g. `r`, `w` or `a`, optionally with `b` and/or `+`"
 @return "The opened file, which must be closed with `close()`"
 @return? io::FILE_NOT_FOUND, io::NO_PERMISSION, io::FILE_IS_DIR, io::TOO_MANY_DESCRIPTORS, io::NAME_TOO_LONG : "If the file could not be opened"
*>
fn File? open(String filename, String mode)
{
	return from_handle(os::native_fopen(filename, mode));
}

<*
 Open the file at a `Path` with a C `fopen`-style mode string, see `file::open`.

 @param path : "The path of the file to open"
 @param mode : "The open mode, e.g. `r`, `w` or `a`, optionally with `b` and/or `+`"
 @return "The opened file, which must be closed with `close()`"
 @return? io::FILE_NOT_FOUND, io::NO_PERMISSION, io::FILE_IS_DIR, io::TOO_MANY_DESCRIPTORS, io::NAME_TOO_LONG : "If the file could not be opened"
*>
fn File? open_path(Path path, String mode)
{
	return from_handle(os::native_fopen((String)path, mode));
}

<*
 Check whether a file or directory exists at the given path.

 @param file : "The path to check"
 @return "True if a file or directory exists at the path"
*>
fn bool exists(String file) => @pool()
{
	return os::native_file_or_dir_exists(file);
}

<*
 Wrap an existing C `FILE*` handle in a `File`; closing the File closes the handle.

 @param file : "The C file handle to wrap"
 @return "A File using the handle"
*>
fn File from_handle(CFile file)
{
	return { .file = file };
}

<*
 Check whether the path refers to an existing regular file.

 @param path : "The path to check"
 @return "True if the path is a regular file, false if it is missing, a directory or something else"
*>
fn bool is_file(String path)
{
	return os::native_is_file(path);
}

<*
 Check whether the path refers to an existing directory.

 @param path : "The path to check"
 @return "True if the path is a directory"
*>
fn bool is_dir(String path)
{
	return os::native_is_dir(path);
}

<*
 Get the size in bytes of the file at the given path, without opening it.

 @param path : "The path of the file"
 @return "The file size in bytes"
 @return? io::FILE_NOT_FOUND, io::NO_PERMISSION : "If the file can't be accessed"
 @return? io::PATH_COULD_NOT_BE_FOUND, io::BUSY : "On Windows, if a parent directory is missing or the file is in use"
 @return? io::FILE_IS_DIR : "If the path is a directory"
*>
fn long? get_size(String path)
{
	return os::native_file_size(path);
}

<*
 Set the last modification time of a file; on non-Windows platforms the access time is set as well.

 @param path : "The path of the file"
 @param time : "The new time in seconds since the Unix epoch"
 @return? io::GENERAL_ERROR : "If the file could not be opened or its time could not be changed"
*>
fn void? set_modified_time(String path, Time_t time)
{
	return os::native_set_modified_time(path, time);
}

<*
 Get the last modification time of a file or directory.

 #### Example:
 ```
 file::save("data.txt", "abc")!!;
 Time t = file::last_modified("data.txt")!!;
 io::printn(time::now().diff_sec(t) < 10); // true
 ```

 @param filename : "The path of the file"
 @return "The modification time, with whole-second precision"
 @return? io::FILE_NOT_FOUND, io::NO_PERMISSION : "If the file can't be accessed"
 @return? io::PATH_COULD_NOT_BE_FOUND, io::BUSY : "On Windows, if a parent directory is missing or the file is in use"
 @return? io::UNSUPPORTED_OPERATION : "If the platform doesn't support it"
*>
fn Time? last_modified(String filename)
{
	Time_t? seconds = os::native_get_modified_time(filename)!;
	return (Time)(seconds * (Time_t)time::SEC);
}

<*
 Delete a file.

 @param filename : "The path of the file to delete"
 @return? io::FILE_NOT_FOUND : "If the file doesn't exist"
 @return? io::FILE_CANNOT_DELETE : "If the file could not be deleted for any other reason"
*>
fn void? delete(String filename) @maydiscard
{
	return os::native_remove(filename) @inline;
}


<*
 Reopen the file handle with a new file and/or mode, closing the currently open file.

 @param filename : "The path of the file to open"
 @param mode : "The open mode, e.g. `r`, `w` or `a`, optionally with `b` and/or `+`"
 @return? io::FILE_NOT_FOUND, io::NO_PERMISSION, io::FILE_IS_DIR : "If the new file could not be opened"
 @require self.file != null
*>
fn void? File.reopen(&self, String filename, String mode)
{
	self.file = os::native_freopen(self.file, filename, mode)!;
}

<*
 Move the file position to an offset relative to the start, the current position or the end.

 #### Example:
 ```
 file::save("data.txt", "Hello world")!!;
 File f = file::open("data.txt", "rb")!!;
 defer (void)f.close();
 f.seek(-5, FROM_END)!!;
 io::printn(f.cursor()!!); // 6
 ```

 @param offset : "The offset in bytes, may be negative"
 @param whence : "The position the offset is relative to"
 @return? io::INVALID_POSITION : "If the resulting position is invalid"
 @return? io::FILE_IS_PIPE : "If the file can't seek"
 @require self.file != null
*>
fn void? File.seek(&self, long offset, SeekOrigin whence = FROM_START) @dynamic
{
	return os::native_fseek(self.file, offset, whence);
}

<*
 Get the current position in the file.

 @return "The current offset in bytes from the start of the file"
 @return? io::FILE_IS_PIPE : "If the file doesn't support positioning"
 @require self.file != null
*>
fn long? File.cursor(&self) @dynamic
{
	return os::native_ftell(self.file);
}

/*
Implement later
<*
 @require self.file == null
*>
fn void? File.memopen(File* file, char[] data, String mode)
{
	@pool()
	{
		file.file = libc::memopen(data.ptr, data.len, mode.to_temp_zstr(), file.file);
		// TODO errors
	};
}
*/


<*
 Write a single byte to the file.

 @param c : "The byte to write"
 @return? io::EOF : "If the byte could not be written"
 @require self.file != null
*>
fn void? File.write_byte(&self, char c) @dynamic
{
	return os::native_fputc(c, self.file);
}

<*
 Close the file and set its handle to null; closing an already closed file does nothing.

 @param [&inout] self
 @return? io::FILE_NOT_VALID, io::INTERRUPTED, io::INCOMPLETE_WRITE, io::UNKNOWN_ERROR : "If closing failed, the handle is cleared regardless"
*>
fn void? File.close(&self) @inline @dynamic @maydiscard
{
	defer self.file = null;
	if (self.file && libc::fclose(self.file))
	{
		switch (libc::errno())
		{
			case ECONNRESET:
			case EBADF: return io::FILE_NOT_VALID~;
			case EINTR: return io::INTERRUPTED~;
			case EDQUOT:
			case EFAULT:
			case EAGAIN:
			case EFBIG:
			case ENETDOWN:
			case ENETUNREACH:
			case ENOSPC:
			case EIO: return io::INCOMPLETE_WRITE~;
			default: return io::UNKNOWN_ERROR~;
		}
	}
}

<*
 Get the size of the open file by seeking to its end; the current position is restored afterwards.

 @return "The file size in bytes"
 @return? io::FILE_IS_PIPE : "If the file can't seek"
*>
fn long? File.size(&self) @dynamic
{
	long curr = self.cursor()!;
	defer (void)self.seek(curr);
	self.seek(0, FROM_END)!;
	return self.cursor()!;
}

<*
 Check whether the end-of-file indicator is set, which happens once a read tries to go past the end.

 @return "True if a previous read hit the end of the file"
 @require self.file != null
*>
fn bool File.eof(&self) @inline
{
	return libc::feof(self.file) != 0;
}

<*
 Read up to `buffer.len` bytes from the file into the buffer.

 #### Example:
 ```
 file::save("data.txt", "Hello")!!;
 File f = file::open("data.txt", "rb")!!;
 defer (void)f.close();
 char[16] buf;
 sz n = f.read(&buf)!!;
 io::printn((String)buf[:n]); // Hello
 ```

 @param [out] buffer : "The buffer to read into"
 @return "The number of bytes read, 0 at the end of the file"
 @return? io::FILE_NOT_VALID, io::NO_PERMISSION, io::INTERRUPTED, io::UNKNOWN_ERROR : "If a read error occurred"
*>
fn sz? File.read(&self, char[] buffer) @dynamic
{
	return os::native_fread(self.file, buffer);
}

<*
 Write the bytes in the buffer to the file.

 @param [in] buffer : "The bytes to write"
 @return "The number of bytes written, which may be less than `buffer.len`"
 @return? io::FILE_NOT_VALID, io::NO_PERMISSION, io::OUT_OF_SPACE, io::INCOMPLETE_WRITE, io::UNKNOWN_ERROR : "If a write error occurred"
 @require self.file != null : `File must be initialized`
*>
fn sz? File.write(&self, char[] buffer) @dynamic
{
	return os::native_fwrite(self.file, buffer);
}

<*
 Get the underlying OS file descriptor.

 @return "The file descriptor"
*>
fn Fd File.fd(self) @feat(LIBC)
{
	return libc::fileno(self.file);
}

<*
 Check whether the file is connected to a terminal.

 @return "True if the file is a terminal"
*>
fn bool File.isatty(self) @feat(LIBC)
{
	return libc::isatty(self.fd()) > 0;
}

<*
 Read a single byte from the file.

 @return "The byte read"
 @return? io::EOF : "If the end of the file was reached or a read error occurred"
*>
fn char? File.read_byte(&self) @dynamic
{
	int c = libc::fgetc(self.file);
	if (c == -1) return io::EOF~;
	return (char)c;
}

<*
 Load a whole file into the buffer, returning io::OVERFLOW if the file is longer than the buffer.

 #### Example:
 ```
 file::save("data.txt", "Hello")!!;
 char[64] buf;
 char[] data = file::load_buffer("data.txt", &buf)!!;
 io::printn((String)data); // Hello
 ```

 @param filename : "The path to the file to read"
 @param [out] buffer : "The buffer to read to"
 @return "The slice of the buffer holding the file contents"
 @return? io::OVERFLOW : "If the file doesn't fit in the buffer"
 @return? io::FILE_NOT_FOUND, io::NO_PERMISSION : "If the file could not be opened"
 @return? io::read_buffer_to_end!
*>
fn char[]? load_buffer(String filename, char[] buffer)
{
	File file = open(filename, "rb")!;
	defer (void)file.close();
	long len = file.size()!;
	if (len > buffer.len) return io::OVERFLOW~;
	return io::read_buffer_to_end(file, buffer[:len]);
}

<*
 Load a whole file into memory allocated with the given allocator.

 #### Example:
 ```
 file::save("data.txt", "Hello")!!;
 char[] data = file::load(mem, "data.txt")!!;
 defer free(data);
 io::printn((String)data); // Hello
 ```

 @param allocator : "The allocator used for the returned data"
 @param filename : "The path to the file to read"
 @return "The file contents, owned by the caller"
 @return? io::FILE_NOT_FOUND, io::NO_PERMISSION : "If the file could not be opened"
 @return? io::OUT_OF_SPACE : "If the file is too large to be loaded"
 @return? mem::OUT_OF_MEMORY : "If allocation failed"
 @return? io::read_buffer_to_end!
*>
fn char[]? load(Allocator allocator, String filename)
{
	File file = open(filename, "rb")!;
	defer (void)file.close();
	long len = file.size()!;
	if (len > sz::max) return io::OUT_OF_SPACE~;
	char* data = alloc::malloc_try(allocator, (sz)len)!;
	defer catch alloc::free(allocator, data);
	return io::read_buffer_to_end(file, data[:len]);
}

<*
 Load the whole file at a `Path` into memory allocated with the given allocator, see `file::load`.

 @param allocator : "The allocator used for the returned data"
 @param path : "The path to the file to read"
 @return "The file contents, owned by the caller"
 @return? io::FILE_NOT_FOUND, io::NO_PERMISSION, io::OUT_OF_SPACE, mem::OUT_OF_MEMORY : "If the file could not be loaded"
*>
fn char[]? load_path(Allocator allocator, Path path) => load(allocator, (String)path);

<*
 Load a whole file into temporary memory, see `file::load`.

 #### Example:
 ```
 file::save("data.txt", "Hello")!!;
 String s = (String)file::load_temp("data.txt")!!;
 io::printn(s); // Hello
 ```

 @param filename : "The path to the file to read"
 @return "The file contents, allocated with the temp allocator"
 @return? io::FILE_NOT_FOUND, io::NO_PERMISSION, io::OUT_OF_SPACE, mem::OUT_OF_MEMORY : "If the file could not be loaded"
*>
fn char[]? load_temp(String filename) => load(tmem, filename);

<*
 Load the whole file at a `Path` into temporary memory, see `file::load`.

 @param path : "The path to the file to read"
 @return "The file contents, allocated with the temp allocator"
 @return? io::FILE_NOT_FOUND, io::NO_PERMISSION, io::OUT_OF_SPACE, mem::OUT_OF_MEMORY : "If the file could not be loaded"
*>
fn char[]? load_path_temp(Path path) => load_temp((String)path);

<*
 Save the data to a file, replacing any existing contents. Not atomic.

 #### Example:
 ```
 file::save("data.txt", "Hello")!!;
 io::printn(file::get_size("data.txt")!!); // 5
 ```

 @param filename : "The path of the file to write"
 @param data : "The bytes to write"
 @return? io::NO_PERMISSION, io::FILE_IS_DIR : "If the file could not be opened for writing"
 @return? io::write_all!
*>
fn void? save(String filename, char[] data)
{
	File file = open(filename, "wb")!;
	defer (void)file.close();
	io::write_all(&file, data)!;
}

<*
 Flush any buffered output to the file. Errors from flushing are currently ignored.

 @require self.file != null : `File must be initialized`
*>
fn void? File.flush(&self) @dynamic
{
	libc::fflush(self.file);
}
