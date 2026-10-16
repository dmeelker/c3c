// Copyright (c) 2021-2025 Christoffer Lerno. All rights reserved.
// Use of this source code is governed by the MIT license
// a copy of which can be found in the LICENSE_STDLIB file.
module std::io;
import libc;

<* The reference point that a seek offset is relative to. *>
enum SeekOrigin
{
	<* Seek relative to the start of the stream. *>
	FROM_START,
	<* Seek relative to the current position. *>
	FROM_CURSOR,
	<* Seek relative to the end of the stream. *>
	FROM_END
}


excuse
{
	<* The file or directory already exists. *>
	ALREADY_EXISTS,
	<* The resource is in use or locked by another process. *>
	BUSY,
	<* A directory could not be opened or read (it may not exist). *>
	CANNOT_READ_DIR,
	<* The directory could not be removed because it is not empty. *>
	DIR_NOT_EMPTY,
	<* A parent directory in the path does not exist. *>
	PARENT_DIR_MISSING,
	<* The stream or file has been closed. *>
	CLOSED,
	<* The end of the stream was reached. *>
	EOF,
	<* The file could not be deleted. *>
	FILE_CANNOT_DELETE,
	<* A file was expected, but the path is a directory. *>
	FILE_IS_DIR,
	<* The operation is not valid on a pipe, or the pipe is broken. *>
	FILE_IS_PIPE,
	<* A directory was expected, but the path is not a directory. *>
	FILE_NOT_DIR,
	<* The file does not exist. *>
	FILE_NOT_FOUND,
	<* The file handle is not valid. *>
	FILE_NOT_VALID,
	<* An unspecified I/O error occurred. *>
	GENERAL_ERROR,
	<* An argument, such as a file name or mode, is invalid. *>
	ILLEGAL_ARGUMENT,
	<* Not all data could be written. *>
	INCOMPLETE_WRITE,
	<* The operation was interrupted, for example by a signal. *>
	INTERRUPTED,
	<* The seek position is invalid. *>
	INVALID_POSITION,
	<* A byte could not be pushed back, for example because nothing has been read yet. *>
	INVALID_PUSHBACK,
	<* The file name or path is too long. *>
	NAME_TOO_LONG,
	<* The stream does not support seeking. *>
	NOT_SEEKABLE,
	<* Access was denied. *>
	NO_PERMISSION,
	<* The device has no space left. *>
	OUT_OF_SPACE,
	<* A size or offset is too large to represent. *>
	OVERFLOW,
	<* The path could not be resolved. *>
	PATH_COULD_NOT_BE_FOUND,
	<* The file or file system is read-only. *>
	READ_ONLY,
	<* Resolving a symbolic link failed, for example because of a loop. *>
	SYMLINK_FAILED,
	<* Too many files are open. *>
	TOO_MANY_DESCRIPTORS,
	<* The stream ended before the expected amount of data was read. *>
	UNEXPECTED_EOF,
	<* An error that could not be mapped to a more specific fault. *>
	UNKNOWN_ERROR,
	<* The stream or platform does not support this operation. *>
	UNSUPPORTED_OPERATION,
	<* The operation would block on a non-blocking stream. *>
	WOULD_BLOCK
}

<*
 Read a line from a stream (default is stdin), up to the next "\n" or the end of the stream.

 The "\n" is not included and any "\r" is filtered out.

 #### Example:
 ```
 ByteReader reader;
 reader.init("first line\r\nsecond");
 String line = io::readline(mem, &reader)!!;
 defer free(line);
 io::printn(line); // first line
 ```

 @param [&inout] allocator : "The allocator used to allocate the read string."
 @param stream : `The stream to read from.`
 @param limit : `Optionally limits the amount of bytes to read in a single line. Will NOT discard the remaining line data.`
 @return `The string containing the data read.`
 @return? EOF : "If the stream was already at its end."
 @require @is_not_instream_if_ptr(stream) : "The value for 'stream' should have been passed as a pointer and not as a value, please add '&'."
 @require @is_instream(stream) : `Make sure that the stream is actually an InStream.`
*>
macro String? readline(Allocator allocator, stream = io::stdin(), sz limit = 0)
{
	return readline_impl{$Typeof(stream)}(allocator, stream, limit);
}

<*
 Read a line like `readline`, but allocate it on the temporary allocator so it does not need to be freed.

 #### Example:
 ```
 ByteReader reader;
 reader.init("abc\ndef");
 io::printn(io::treadline(&reader)!!); // abc
 io::printn(io::treadline(&reader)!!); // def
 ```

 @param stream : `The stream to read from.`
 @param limit : `Optionally limits the amount of bytes to read in a single line. Will NOT discard the remaining line data.`
 @return `The temporary string containing the data read.`
 @return? EOF : "If the stream was already at its end."
 @require @is_not_instream_if_ptr(stream) : "The value for 'stream' should have been passed as a pointer and not as a value, please add '&'."
 @require @is_instream(stream) : `The stream must implement InStream.`
*>
macro String? treadline(stream = io::stdin(), sz limit = 0)
{
	return readline(tmem, stream, limit) @inline;
}

fn String? readline_impl(Allocator allocator, Stream stream, sz limit) <Stream> @private
{
	if (allocator == tmem)
	{
		DString str = dstring::temp_with_capacity(256);
		readline_to_stream(&str, stream, limit)!;
		return str.str_view();
	}
	@pool()
	{
		DString str = dstring::temp_with_capacity(256);
		readline_to_stream(&str, stream, limit)!;
		return str.copy_str(allocator);
	};
}

<*
 Read a line like `readline`, but write it to an output stream instead of allocating a string.

 #### Example:
 ```
 ByteReader reader;
 reader.init("hello\nworld");
 DString out;
 defer out.free();
 sz n = io::readline_to_stream(&out, &reader)!!;
 io::printn(n); // 5
 io::printn(out); // hello
 ```

 @param out_stream : `The stream to write to`
 @param in_stream : `The stream to read from.`
 @param limit : `Optionally limits the number of bytes written. Will NOT discard the remaining line data.`
 @return `The number of bytes written. When a 'limit' is provided and the return value is equal to it, there may be more to read on the current line.`
 @return? EOF : "If the input stream was already at its end."
 @require @is_not_instream_if_ptr(in_stream) : "The value for 'in_stream' should have been passed as a pointer and not as a value, please add '&'."
 @require @is_not_outstream_if_ptr(out_stream) : "The value for 'out_stream' should have been passed as a pointer and not as a value, please add '&'."
 @require @is_instream(in_stream) : `The in_stream must implement InStream.`
 @require @is_outstream(out_stream) : `The out_stream must implement OutStream.`
*>
macro sz? readline_to_stream(out_stream, in_stream = io::stdin(), sz limit = 0)
{
	return readline_to_stream_impl{$Typeof(in_stream), $Typeof(out_stream)}(out_stream, in_stream, limit);
}

fn sz? readline_to_stream_impl(OStream out_stream, IStream in_stream, sz limit) <IStream, OStream> @private
{
	bool $is_stream = IStream == InStream;
	$if $is_stream:
		var func @safeinfer = &in_stream.read_byte;
		char val = func((void*)in_stream)!;
	$else
		char val = in_stream.read_byte()!;
	$endif
	bool $is_out_stream = OStream == OutStream;
	$if $is_out_stream:
		var out_func @safeinfer = &out_stream.write_byte;
	$endif

	if (val == '\n') return 0;
	sz len;
	if (val != '\r')
	{
		$if $is_out_stream:
			out_func((void*)out_stream.ptr, val)!;
		$else
			out_stream.write_byte(val)!;
		$endif
		len++;
	}
	while (!limit || len < limit)
	{
		$if $is_stream:
			char? c = func((void*)in_stream);
		$else
			char? c = in_stream.read_byte();
		$endif
		if (catch err = c)
		{
			if (err == io::EOF) break;
			return err~;
		}
		if (c == '\r') continue;
		if (c == '\n') break;
		$if $is_out_stream:
			out_func((void*)out_stream.ptr, c)!;
		$else
			out_stream.write_byte(c)!;
		$endif
		len++;
	}
	return len;
}
<*
 Print a value to a stream using its default representation.

 Strings are written as-is. Structs and bitstructs without `to_format` or
 `to_constant_string` are printed member by member, e.g. `{ x: 1, y: 2 }`.
 Other values are printed as with `"%s"`.

 #### Example:
 ```
 struct Point { int x; int y; }

 fn void main()
 {
 	DString s;
 	defer s.free();
 	io::fprint(&s, 42)!!;
 	io::fprint(&s, " ")!!;
 	io::fprint(&s, (Point) { 1, 2 })!!;
 	io::printn(s); // 42 { x: 1, y: 2 }
 }
 ```

 @param out : `the stream to print to`
 @param x : `the value to print`
 @return `the number of bytes printed.`
 @require @is_outstream(out) : `The output must implement OutStream.`
*>
macro sz? fprint(out, x)
{
	var $Type = $Typeof(x);
	$switch $Type:
		$case String: return out.write(x);
		$case ZString: return out.write(x.str_view());
		$case DString: return out.write(x.str_view());
		$default:
			$if $defined(String a = x):
				return out.write((String)x);
			$else
				$if is_struct_with_default_print($Type):
					Formatter formatter;
					formatter.init(&out_putstream_fn, &&(OutStream)out);
					return struct_to_format(x, &formatter, false);
				$else
					return fprintf(out, "%s", x);
				$endif
			$endif
	$endswitch
}

<*
 Print to a stream using a 'printf'-style format string.
 See `printf` for details on formatting.

 #### Example:
 ```
 DString s;
 defer s.free();
 io::fprintf(&s, "%s has %d items", "list", 3)!!;
 io::printn(s); // list has 3 items
 ```

 @param [inout] out : `The OutStream to print to`
 @param [in] format : `The printf-style format string`
 @param args : "The values to format"
 @return `the number of characters printed`
 @return? INVALID_FORMAT, NOT_ENOUGH_ARGUMENTS, INVALID_ARGUMENT, INTERNAL_BUFFER_EXCEEDED : "If the format string and arguments don't match, or a stream fault if writing fails"
*>
fn sz? fprintf(OutStream out, String format, args...) @format(1)
{
	Formatter formatter;
	formatter.init(&out_putstream_fn, &out);
	return formatter.vprintf(format, args);
}

<*
 Print to a stream using a 'printf'-style format string, then append '\n' and flush the stream.
 See `printf` for details on formatting.

 #### Example:
 ```
 io::fprintfn(io::stdout(), "%d + %d = %d", 1, 2, 3)!!; // 1 + 2 = 3
 ```

 @param [inout] out : `The OutStream to print to`
 @param [in] format : `The printf-style format string`
 @param args : "The values to format"
 @return `the number of characters printed, including the '\n'`
 @return? INVALID_FORMAT, NOT_ENOUGH_ARGUMENTS, INVALID_ARGUMENT, INTERNAL_BUFFER_EXCEEDED : "If the format string and arguments don't match, or a stream fault if writing fails"
*>
fn sz? fprintfn(OutStream out, String format, args...) @format(1) @maydiscard
{
	Formatter formatter;
	formatter.init(&out_putstream_fn, &out);
	sz len = formatter.vprintf(format, args)!;
	out.write_byte('\n')!;
	if (&out.flush) out.flush()!;
	return len + 1;
}

<*
 Print a value to a stream like `fprint`, then append '\n' and flush the stream if it supports flushing.

 #### Example:
 ```
 io::fprintn(io::stderr(), "to stderr")!!;
 ```

 @param out : "The stream to print to"
 @param x : "The value to print, defaults to an empty string"
 @return "The number of bytes printed, including the '\n'"
 @require @is_outstream(out) : "The output must implement OutStream"
*>
macro sz? fprintn(out, x = "")
{
	sz len = fprint(out, x)!;
	out.write_byte('\n')!;
	$switch:
		$case $Typeof(out) == OutStream:
			if (&out.flush) out.flush()!;
		$case $defined(out.flush):
			out.flush()!;
	$endswitch
	return len + 1;
}

<*
 Print any value to stdout, ignoring any fault. See `fprint`.

 @param x : "The value to print"
*>
macro void print(x)
{
	(void)fprint(io::stdout(), x);
}

<*
 Print any value to stdout, appending a '\n' after, ignoring any fault. See `fprint`.

 @param x : "The value to print"
*>
macro void printn(x = "")
{
	(void)fprintn(io::stdout(), x);
}

<*
 Print any value to stderr, ignoring any fault. See `fprint`.

 @param x : "The value to print"
*>
macro void eprint(x)
{
	(void)fprint(io::stderr(), x);
}

<*
 Print any value to stderr, appending a '\n' after, ignoring any fault. See `fprint`.

 @param x : "The value to print"
*>
macro void eprintn(x = "")
{
	(void)fprintn(io::stderr(), x);
}


fn void? out_putstream_fn(void* data, char c) @private
{
	OutStream* stream = data;
	return (*stream).write_byte(c);
}

<*
 The size of the buffer `printf` and `printfn` use for stdout, depending on `env::MEMORY_ENV`.

 @return "The buffer size in bytes"
*>
macro sz putchar_buf_size() @const
{
	$switch env::MEMORY_ENV:
		$case NORMAL: return 32 * 1024;
		$case SMALL: return 1024;
		$case TINY: return 256;
		$case NONE: return 256;
	$endswitch
}

<* A stack buffer used by `printf` and `printfn` to batch writes to stdout. *>
struct PutcharBuffer
{
	char[putchar_buf_size()] data;
	sz len;
	bool should_flush;
}

fn void? write_putchar_buffer(PutcharBuffer* buff, bool flush) @private
{
	File* stdout = io::stdout();
	libc::fwrite(&buff.data, 1, (usz)buff.len, stdout.file);
	buff.len = 0;
	if (flush) stdout.flush()!;
}

fn void? out_putchar_buffer_fn(void* data @unused, char c) @private
{
	$if env::TESTING:
		// HACK: this is used for the purpose of unit test output hijacking
		File* stdout = io::stdout();
		assert(stdout.file);
		libc::fputc(c, stdout.file);
	$else
		PutcharBuffer* buff = data;
		buff.data[buff.len++] = c;
		if (c == '\n') buff.should_flush = true;
		if (buff.len == buff.data.len) write_putchar_buffer(buff, false)!;
	$endif
}

<*
 Print to stdout using a 'printf'-style format string.

 A format specifier has the form `%[flags][width][.precision]specifier`:
 - `d` decimal integer; `x`/`X` hexadecimal; `o`/`O` octal; `b`/`B` binary.
 - `f`/`F` fixed-point float; `e`/`E` exponential; `g`/`G` shortest of the two; `a`/`A` hexadecimal float.
 - `s` the default representation of any value; `c` a character (Unicode code point); `p` a pointer.
 - `h`/`H` a hex dump of a `char[]`, `ichar[]` or a char array.
 - `%%` prints a single `%`.
 - Flags: `-` left-align, `0` zero-pad, `+` always print the sign, space for a leading space, `#` prefix (`0x`, `0o`, `0b`).
 - Width and precision may be `*` to take them from the next argument.

 To create a custom output for a type, implement the Printable interface.
 Output is buffered and flushed when a '\n' was printed.

 #### Example:
 ```
 io::printf("%d|%5d|%-5d|%05d\n", 42, 42, 42, 42); // 42|   42|42   |00042
 io::printf("%x %X %#x %o %b\n", 255, 255, 255, 8, 5); // ff FF 0xff 10 101
 io::printf("%.2f %e %g\n", 3.14159, 1234.5, 0.0001); // 3.14 1.234500e+03 0.0001
 io::printf("%s %s %c\n", "text", true, 'A'); // text true A
 io::printf("%h\n", (char[]){ 0xDE, 0xAD }); // dead
 io::printf("100%%\n"); // 100%
 ```

 @param [in] format : `The printf-style format string`
 @param args : "The values to format"
 @return `the number of characters printed`
 @return? INVALID_FORMAT, NOT_ENOUGH_ARGUMENTS, INVALID_ARGUMENT, INTERNAL_BUFFER_EXCEEDED : "If the format string and arguments don't match; a marker such as `<MISSING>` is printed in place"
*>
fn sz? printf(String format, args...) @format(0) @maydiscard
{
	Formatter formatter;
	PutcharBuffer buff;
	formatter.init(&out_putchar_buffer_fn, &buff);
	sz? len = formatter.vprintf(format, args);
	write_putchar_buffer(&buff, buff.should_flush)!;
	return len;
}

<*
 Print to stdout using a 'printf'-style format string, then append '\n' and flush.
 See `printf` for details on formatting.

 #### Example:
 ```
 io::printfn("Hello %s!", "world"); // Hello world!
 ```

 @param [in] format : `The printf-style format string`
 @param args : "The values to format"
 @return `the number of characters printed, including the '\n'`
 @return? INVALID_FORMAT, NOT_ENOUGH_ARGUMENTS, INVALID_ARGUMENT, INTERNAL_BUFFER_EXCEEDED : "If the format string and arguments don't match"
*>
fn sz? printfn(String format, args...) @format(0) @maydiscard
{
	Formatter formatter;
	PutcharBuffer buff;
	formatter.init(&out_putchar_buffer_fn, &buff);
	sz? len = formatter.vprintf(format, args);
	formatter.print_char('\n')!;
	write_putchar_buffer(&buff, true)!;
	return len + 1;
}

<*
 Print to stderr using a 'printf'-style format string. See `printf` for details on formatting.

 @param [in] format : `The printf-style format string`
 @param args : "The values to format"
 @return `the number of characters printed`
 @return? INVALID_FORMAT, NOT_ENOUGH_ARGUMENTS, INVALID_ARGUMENT, INTERNAL_BUFFER_EXCEEDED : "If the format string and arguments don't match"
*>
fn sz? eprintf(String format, args...) @maydiscard
{
	Formatter formatter;
	OutStream stream = stderr();
	formatter.init(&out_putstream_fn, &stream);
	return formatter.vprintf(format, args);
}


<*
 Print to stderr using a 'printf'-style format string, then append '\n' and flush.
 See `printf` for details on formatting.

 @param [in] format : `The printf-style format string`
 @param args : "The values to format"
 @return `the number of characters printed, including the '\n'`
 @return? INVALID_FORMAT, NOT_ENOUGH_ARGUMENTS, INVALID_ARGUMENT, INTERNAL_BUFFER_EXCEEDED : "If the format string and arguments don't match"
*>
fn sz? eprintfn(String format, args...) @maydiscard
{
	Formatter formatter;
	OutStream stream = stderr();
	formatter.init(&out_putstream_fn, &stream);
	sz? len = formatter.vprintf(format, args);
	stderr().write_byte('\n')!;
	stderr().flush()!;
	return len + 1;
}

<*
 Print to a fixed-size buffer using a 'printf'-style format string. See `printf` for details on formatting.

 No allocation is done and no zero terminator is written.

 #### Example:
 ```
 char[32] buf;
 String s = (String)io::bprintf(&buf, "x = %d", 10)!!;
 io::printn(s); // x = 10
 ```

 @param [inout] buffer : `The buffer to print to`
 @param [in] format : `The printf-style format string`
 @param args : "The values to format"
 @return `a slice formed from the "buffer" with the resulting length.`
 @return? BUFFER_EXCEEDED : "If the output does not fit in the buffer"
 @return? INVALID_FORMAT, NOT_ENOUGH_ARGUMENTS, INVALID_ARGUMENT, INTERNAL_BUFFER_EXCEEDED : "If the format string and arguments don't match"
*>
fn char[]? bprintf(char[] buffer, String format, args...) @maydiscard
{
	Formatter formatter;
	BufferData data = { .buffer = buffer };
	formatter.init(&out_buffer_fn, &data);
	sz size = formatter.vprintf(format, args)!;
	return buffer[:data.written];
}

// Used to print to a buffer.
fn void? out_buffer_fn(void* data, char c) @private
{
	BufferData* buffer_data = data;
	if (buffer_data.written >= buffer_data.buffer.len) return BUFFER_EXCEEDED~;
	buffer_data.buffer[buffer_data.written++] = c;
}

// Used for buffer printing
struct BufferData @private
{
	char[] buffer;
	sz written;
}

// Only available with LIBC
module std::io @feat(LIBC);
import libc;

<*
 Libc `putchar`, prints a single character to stdout.

 @param c : "The character to print"
*>
fn void putchar(char c) @inline
{
	libc::putchar(c);
}

<*
 Get standard out.

 @return `stdout as a File`
*>
fn File* stdout()
{
	static File file;
	if (!file.file) file = file::from_handle(libc::stdout());
	return &file;
}

<*
 Get standard err.

 @return `stderr as a File`
*>
fn File* stderr()
{
	static File file;
	if (!file.file) file = file::from_handle(libc::stderr());
	return &file;
}

<*
 Get standard in.

 @return `stdin as a File`
*>
fn File* stdin()
{
	static File file;
	if (!file.file) file = file::from_handle(libc::stdin());
	return &file;
}

module std::io @feat(!LIBC);

<* The standard input file, used when libc is unavailable. *>
File stdin_file;
<* The standard output file, used when libc is unavailable. *>
File stdout_file;
<* The standard error file, used when libc is unavailable. *>
File stderr_file;

<*
 Print a single character to stdout, ignoring any fault.

 @param c : "The character to print"
*>
fn void putchar(char c) @inline
{
	(void)stdout_file.write_byte(c);
}

<*
 Get standard out.

 @return `stdout as a File`
*>
fn File* stdout()
{
	return &stdout_file;
}

<*
 Get standard err.

 @return `stderr as a File`
*>
fn File* stderr()
{
	return &stderr_file;
}

<*
 Get standard in.

 @return `stdin as a File`
*>
fn File* stdin()
{
	return &stdin_file;
}

