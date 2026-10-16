module std::io::os @feat(LIBC);
import libc;

<*
 Open a file using a C `fopen` mode string such as "rb" or "w".
 Usually called through `file::open` / `file::open_path`.

 On Windows the name and mode are converted to UTF-16 and `_wfopen` is used.

 @param filename : "The file to open"
 @param mode : "The C fopen mode"
 @return "The native file handle"
 @return? io::FILE_NOT_FOUND, io::NO_PERMISSION, io::FILE_IS_DIR, io::ALREADY_EXISTS, io::NAME_TOO_LONG, io::READ_ONLY, io::TOO_MANY_DESCRIPTORS, io::OUT_OF_SPACE, io::UNKNOWN_ERROR : "Mapped from errno on failure"
 @require mode.len > 0
 @require filename.len > 0
*>
fn void*? native_fopen(String filename, String mode) @inline => @stack_mem(256; Allocator smem)
{
	$if env::WIN32:
		void* file = libc::_wfopen(filename.to_wstring(smem), mode.to_wstring(smem))!;
	$else
		void* file = libc::fopen(filename.zstr_copy(smem), mode.zstr_copy(smem));
	$endif
	return file ?: file_open_errno()~;
}

<*
 Delete a file.
 Usually called through `file::delete` / `path::delete`.

 @param filename : "The file to delete"
 @return? io::FILE_NOT_FOUND : "If the file does not exist"
 @return? io::FILE_CANNOT_DELETE : "If the file can't be deleted for any other reason"
*>
fn void? native_remove(String filename) => @stack_mem(256; Allocator smem)
{
	$if env::WIN32:
		CInt result = libc::_wremove(filename.to_wstring(smem))!;
	$else
		CInt result = libc::remove(filename.zstr_copy(smem));
	$endif
	if (result)
	{
		switch (libc::errno())
		{
			case ENOENT: return io::FILE_NOT_FOUND~;
			case EACCES:
			default:     return io::FILE_CANNOT_DELETE~;
		}
	}
}

<*
 Reopen `file` with a new file name and mode, reusing the handle.
 Usually called through `File.reopen`.

 @param file : "The native file handle to reopen"
 @param filename : "The file to open"
 @param mode : "The C fopen mode"
 @return "The native file handle"
 @return? io::FILE_NOT_FOUND, io::NO_PERMISSION, io::FILE_IS_DIR, io::ALREADY_EXISTS, io::NAME_TOO_LONG, io::READ_ONLY, io::TOO_MANY_DESCRIPTORS, io::OUT_OF_SPACE, io::UNKNOWN_ERROR : "Mapped from errno on failure"
 @require mode.len > 0
 @require filename.len > 0
*>
fn void*? native_freopen(void* file, String filename, String mode) @inline  => @stack_mem(256; Allocator smem)
{
	$if env::WIN32:
		file = libc::_wfreopen(filename.to_wstring(smem), mode.to_wstring(smem), file)!;
	$else
		file = libc::freopen(filename.zstr_copy(smem), mode.zstr_copy(smem), file);
	$endif
		return file ?: file_open_errno()~;
}

<*
 Move the file position. Usually called through `File.seek`.

 @param file : "The native file handle"
 @param offset : "The offset relative to the origin"
 @param seek_mode : "Where to seek from"
 @return? io::FILE_IS_PIPE, io::INVALID_POSITION, io::OVERFLOW, io::FILE_NOT_VALID, io::UNKNOWN_ERROR : "Mapped from errno on failure"
*>
fn void? native_fseek(void* file, long offset, SeekOrigin seek_mode) @inline
{
	if (libc::fseek(file, (SeekIndex)offset, seek_mode.ordinal)) return file_seek_errno()~;
}


<*
 Return the current file position. Usually called through `File.cursor`.

 @param file : "The native file handle"
 @return "The position in bytes from the start of the file"
 @return? io::FILE_IS_PIPE, io::INVALID_POSITION, io::OVERFLOW, io::FILE_NOT_VALID, io::UNKNOWN_ERROR : "Mapped from errno on failure"
*>
fn long? native_ftell(CFile file) @inline
{
	long index = libc::ftell(file);
	return index >= 0 ? index : file_seek_errno()~;
}

<*
 Write `buffer` to the file. Usually called through `File.write`.

 @param file : "The native file handle"
 @param buffer : "The bytes to write"
 @return "The number of bytes written, which may be less than `buffer.len`"
 @return? io::NO_PERMISSION, io::OUT_OF_SPACE, io::FILE_NOT_VALID, io::INCOMPLETE_WRITE, io::UNKNOWN_ERROR : "If nothing could be written, mapped from errno"
*>
fn sz? native_fwrite(CFile file, char[] buffer) @inline
{
	sz len = (sz)libc::fwrite(buffer.ptr, 1u, (usz)buffer.len, file);
	if (!len && buffer.len)
	{
		if (libc::ferror(file)) return file_open_errno()~;
	}
	return len;
}

<*
 Write a single byte to the file. Usually called through `File.write_byte`.

 @param c : "The byte to write"
 @param stream : "The native file handle"
 @return? io::EOF : "If the write failed, whatever the reason"
*>
fn void? native_fputc(CInt c, CFile stream) @inline
{
	if (libc::fputc(c, stream) == libc::EOF) return io::EOF~;
}

<*
 Read up to `buffer.len` bytes from the file. Usually called through `File.read`.

 @param file : "The native file handle"
 @param buffer : "The buffer to read into"
 @return "The number of bytes read, 0 at end of file"
 @return? io::NO_PERMISSION, io::FILE_NOT_VALID, io::FILE_IS_DIR, io::INCOMPLETE_WRITE, io::UNKNOWN_ERROR : "If a read error occurred, mapped from errno"
*>
fn sz? native_fread(CFile file, char[] buffer) @inline
{
	sz len = (sz)libc::fread(buffer.ptr, 1u, (usz)buffer.len, file);
	if (!len)
	{
		if (libc::ferror(file)) return file_open_errno()~;
	}
	return len;
}

<*
 Flush buffered output to the file.

 @param file : "The native file handle"
 @return? io::NO_PERMISSION, io::OUT_OF_SPACE, io::FILE_NOT_VALID, io::INCOMPLETE_WRITE, io::UNKNOWN_ERROR : "If flushing failed, mapped from errno"
*>
fn void? native_fflush(CFile file) @inline @maydiscard
{
	if (libc::fflush(file) != 0) return file_open_errno()~;
}

macro fault file_open_errno() @local
{
	switch (libc::errno())
	{
		case EACCES: return io::NO_PERMISSION;
		case EDQUOT: return io::OUT_OF_SPACE;
		case EBADF: return io::FILE_NOT_VALID;
		case EEXIST: return io::ALREADY_EXISTS;
		case EINTR: return io::INTERRUPTED;
		case EFAULT: return io::GENERAL_ERROR;
		case EISDIR: return io::FILE_IS_DIR;
		case ELOOP: return io::SYMLINK_FAILED;
		case EMFILE: return io::TOO_MANY_DESCRIPTORS;
		case ENAMETOOLONG: return io::NAME_TOO_LONG;
		case ENFILE: return io::OUT_OF_SPACE;
		case ENOTDIR: return io::FILE_NOT_DIR;
		case ENOENT: return io::FILE_NOT_FOUND;
		case ENOSPC: return io::OUT_OF_SPACE;
		case ENXIO: return io::FILE_NOT_FOUND;
		case EOVERFLOW: return io::OVERFLOW;
		case EROFS: return io::READ_ONLY;
		case EOPNOTSUPP: return io::UNSUPPORTED_OPERATION;
		case EIO: return io::INCOMPLETE_WRITE;
		case EWOULDBLOCK: return io::WOULD_BLOCK;
		default: return io::UNKNOWN_ERROR;
	}
}

macro fault file_seek_errno() @local
{
	switch (libc::errno())
	{
		case ESPIPE: return io::FILE_IS_PIPE;
		case EPIPE: return io::FILE_IS_PIPE;
		case EOVERFLOW: return io::OVERFLOW;
		case ENXIO: return io::FILE_NOT_FOUND;
		case ENOSPC: return io::OUT_OF_SPACE;
		case EIO: return io::INCOMPLETE_WRITE;
		case EINVAL: return io::INVALID_POSITION;
		case EINTR: return io::INTERRUPTED;
		case EFBIG: return io::OUT_OF_SPACE;
		case EBADF: return io::FILE_NOT_VALID;
		case EAGAIN: return io::WOULD_BLOCK;
		default: return io::UNKNOWN_ERROR;
	}
}


<* The C `utimbuf` struct passed to `utime`. *>
struct Utimbuf @feat(EMSCRIPTEN)
{
	long actime;
	long modtime;
}

<* The C `utimbuf` struct passed to `utime`. *>
struct Utimbuf @feat(!EMSCRIPTEN) @feat(!WIN32)
{
	Time_t actime;
	Time_t modtime;
}
<* Binding to C `utime`: set the access and modification times of a file. *>
extern fn int utime(char* filename, void* times) @feat(!WIN32);

<* The Win32 FILETIME struct: 100-nanosecond intervals since 1601-01-01, split into two halves. *>
struct FileTime @feat(WIN32)
{
	uint low;
	uint high;
}
<* Binding to Win32 `CreateFileW`. *>
extern fn void* create_file_w(WChar* lpFileName, uint dwDesiredAccess, uint dwShareMode, void* lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, void* hTemplateFile) @cname("CreateFileW") @feat(WIN32);
<* Binding to Win32 `SetFileTime`. *>
extern fn int set_file_time(void* hFile, void* lpCreationTime, void* lpLastAccessTime, void* lpLastWriteTime) @cname("SetFileTime") @feat(WIN32);
<* Binding to Win32 `CloseHandle`. *>
extern fn int close_handle(void* hObject) @cname("CloseHandle") @feat(WIN32);

<*
 Set the modification time of a file. Usually called through `file::set_modified_time`.

 On POSIX both the access and modification time are set; on Windows only the
 last write time is changed.

 @param filename : "The file to change"
 @param time : "The new time, in seconds since the Unix epoch"
 @return? io::GENERAL_ERROR : "If the file can't be opened or its time can't be set"
*>
fn void? native_set_modified_time(String filename, Time_t time) => @stack_mem(256; Allocator smem)
{
	$if env::WIN32:
		void* h = create_file_w(filename.to_wstring(smem)!, 0x40000000, 1 | 2 | 4, null, 3, 0x02000000, null);
		if (h == (void*)(uptr)-1) return io::GENERAL_ERROR~;
		defer (void)close_handle(h);

		ulong ticks = ((ulong)time + 11644473600UL) * 10_000_000UL;
		FileTime ft = { (uint)(ticks & 0xFFFFFFFF), (uint)(ticks >> 32) };

		if (!set_file_time(h, null, null, &ft)) return io::GENERAL_ERROR~;
	$else
		$if env::EMSCRIPTEN:
			Utimbuf times = { (long)time, (long)time };
		$else
			Utimbuf times = { (Time_t)time, (Time_t)time };
		$endif
		if (utime(filename.zstr_copy(smem), &times)) return io::GENERAL_ERROR~;
	$endif
}
