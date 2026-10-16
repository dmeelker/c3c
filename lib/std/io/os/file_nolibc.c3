module std::io::os @feat(NO_LIBC);
import libc;

<* Signature of the `native_fopen_fn` hook. *>
alias FopenFn = fn void*?(String, String);
<* Signature of the `native_freopen_fn` hook. *>
alias FreopenFn = fn void*?(void*, String, String);
<* Signature of the `native_fclose_fn` hook. *>
alias FcloseFn = fn void?(void*);
<* Signature of the `native_fseek_fn` hook. *>
alias FseekFn = fn void?(void*, long, SeekOrigin);
<* Signature of the `native_ftell_fn` hook. *>
alias FtellFn = fn long?(void*);
<* Signature of the `native_fwrite_fn` hook. *>
alias FwriteFn = fn sz?(void*, char[] buffer);
<* Signature of the `native_fread_fn` hook. *>
alias FreadFn = fn sz?(void*, char[] buffer);
<* Signature of the `native_fflush_fn` hook. *>
alias FflushFn = fn void?(void*);
<* Signature of the `native_remove_fn` hook. *>
alias RemoveFn = fn void?(String);
<* Signature of the `native_fputc_fn` hook. *>
alias FputcFn = fn void?(int, void*);
<* Signature of the `native_set_modified_time_fn` hook. *>
alias SetModifiedTimeFn = fn void?(String, Time_t);

<* Hook used by `native_fopen` without libc; set it to provide file opening. *>
FopenFn native_fopen_fn @weak;
<* Hook for closing files without libc. Currently not called by the stdlib. *>
FcloseFn native_fclose_fn @weak;
<* Hook used by `native_freopen` without libc. *>
FreopenFn native_freopen_fn @weak;
<* Hook used by `native_fseek` without libc. *>
FseekFn native_fseek_fn @weak;
<* Hook used by `native_ftell` without libc. *>
FtellFn native_ftell_fn @weak;
<* Hook used by `native_fwrite` without libc. *>
FwriteFn native_fwrite_fn @weak;
<* Hook used by `native_fread` without libc. *>
FreadFn native_fread_fn @weak;
<* Hook used by `native_fflush` without libc. *>
FflushFn native_fflush_fn @weak;
<* Hook used by `native_remove` without libc. *>
RemoveFn native_remove_fn @weak;
<* Hook used by `native_fputc` without libc. *>
FputcFn native_fputc_fn @weak;
<* Hook used by `native_set_modified_time` without libc. *>
SetModifiedTimeFn native_set_modified_time_fn @weak;

<*
 Open a file using a C `fopen` mode string such as "rb" or "w".
 Usually called through `file::open` / `file::open_path`.

 Without libc this forwards to the `native_fopen_fn` hook; its faults are passed through.

 @param filename : "The file to open"
 @param mode : "The C fopen mode"
 @return "The native file handle"
 @return? io::UNSUPPORTED_OPERATION : "If the hook is not set"
 @require mode.len > 0
 @require filename.len > 0
*>
fn void*? native_fopen(String filename, String mode) @inline
{
	if (native_fopen_fn) return native_fopen_fn(filename, mode);
	return io::UNSUPPORTED_OPERATION~;
}

<*
 Delete a file.
 Usually called through `file::delete` / `path::delete`.

 Without libc this forwards to the `native_remove_fn` hook; its faults are passed through.

 @param filename : "The file to delete"
 @return? io::UNSUPPORTED_OPERATION : "If the hook is not set"
 @require filename.len > 0
*>
fn void? native_remove(String filename) @inline
{
	if (native_remove_fn) return native_remove_fn(filename);
	return io::UNSUPPORTED_OPERATION~;
}

<*
 Reopen `file` with a new file name and mode, reusing the handle.
 Usually called through `File.reopen`.

 Without libc this forwards to the `native_freopen_fn` hook; its faults are passed through.

 @param file : "The native file handle to reopen"
 @param filename : "The file to open"
 @param mode : "The C fopen mode"
 @return "The native file handle"
 @return? io::UNSUPPORTED_OPERATION : "If the hook is not set"
 @require mode.len > 0
 @require filename.len > 0
*>
fn void*? native_freopen(void* file, String filename, String mode) @inline
{
	if (native_freopen_fn) return native_freopen_fn(file, filename, mode);
	return io::UNSUPPORTED_OPERATION~;
}

<*
 Move the file position. Usually called through `File.seek`.

 Without libc this forwards to the `native_fseek_fn` hook; its faults are passed through.

 @param file : "The native file handle"
 @param offset : "The offset relative to the origin"
 @param whence : "Where to seek from"
 @return? io::UNSUPPORTED_OPERATION : "If the hook is not set"
*>
fn void? native_fseek(void* file, long offset, SeekOrigin whence) @inline
{
	if (native_fseek_fn) return native_fseek_fn(file, offset, whence);
	return io::UNSUPPORTED_OPERATION~;
}

<*
 Return the current file position. Usually called through `File.cursor`.

 Without libc this forwards to the `native_ftell_fn` hook; its faults are passed through.

 @param file : "The native file handle"
 @return "The position in bytes from the start of the file"
 @return? io::UNSUPPORTED_OPERATION : "If the hook is not set"
*>
fn long? native_ftell(CFile file) @inline
{
	if (native_ftell_fn) return native_ftell_fn(file);
	return io::UNSUPPORTED_OPERATION~;
}

<*
 Write `buffer` to the file. Usually called through `File.write`.

 Without libc this forwards to the `native_fwrite_fn` hook; its faults are passed through.

 @param file : "The native file handle"
 @param buffer : "The bytes to write"
 @return "The number of bytes written, which may be less than `buffer.len`"
 @return? io::UNSUPPORTED_OPERATION : "If the hook is not set"
*>
fn sz? native_fwrite(CFile file, char[] buffer) @inline
{
	if (native_fwrite_fn) return native_fwrite_fn(file, buffer);
	return io::UNSUPPORTED_OPERATION~;
}

<*
 Read up to `buffer.len` bytes from the file. Usually called through `File.read`.

 Without libc this forwards to the `native_fread_fn` hook; its faults are passed through.

 @param file : "The native file handle"
 @param buffer : "The buffer to read into"
 @return "The number of bytes read, 0 at end of file"
 @return? io::UNSUPPORTED_OPERATION : "If the hook is not set"
*>
fn sz? native_fread(CFile file, char[] buffer) @inline
{
	if (native_fread_fn) return native_fread_fn(file, buffer);
	return io::UNSUPPORTED_OPERATION~;
}

<*
 Flush buffered output to the file.

 Without libc this forwards to the `native_fflush_fn` hook; its faults are passed through.

 @param file : "The native file handle"
 @return? io::UNSUPPORTED_OPERATION : "If the hook is not set"
*>
fn void? native_fflush(CFile file) @inline @maydiscard
{
	if (native_fflush_fn) return native_fflush_fn(file);
	return io::UNSUPPORTED_OPERATION~;
}

<*
 Write a single byte to the file. Usually called through `File.write_byte`.

 Without libc this forwards to the `native_fputc_fn` hook; its faults are passed through.

 @param c : "The byte to write"
 @param stream : "The native file handle"
 @return? io::UNSUPPORTED_OPERATION : "If the hook is not set"
*>
fn void? native_fputc(CInt c, CFile stream) @inline
{
	if (native_fputc_fn) return native_fputc_fn(c, stream);
	return io::UNSUPPORTED_OPERATION~;
}

<*
 Set the modification time of a file. Usually called through `file::set_modified_time`.

 Without libc this forwards to the `native_set_modified_time_fn` hook; its faults are passed through.

 @param filename : "The file to change"
 @param time : "The new time, in seconds since the Unix epoch"
 @return? io::UNSUPPORTED_OPERATION : "If the hook is not set"
*>
fn void? native_set_modified_time(String filename, Time_t time) @inline
{
	if (native_set_modified_time_fn) return native_set_modified_time_fn(filename, time);
	return io::UNSUPPORTED_OPERATION~;
}
