module std::io::os;
import libc, std::os;

<* Largest buffer size (in characters) `getcwd` tries before giving up. *>
const MAX_CWD = 64 * 1024;
<*
 Return the current working directory of the process as a newly allocated string.
 Usually called through `path::cwd` / `path::tcwd`, which return a normalized `Path`.

 The buffer starts at 256 characters and doubles while the OS reports it is
 too small, up to `MAX_CWD`.

 @param allocator : "The allocator for the returned string"
 @return "The current working directory"
 @return? io::GENERAL_ERROR : "If the OS call fails, or the path is longer than `MAX_CWD`"
 @return? io::UNSUPPORTED_OPERATION : "On platforms that are neither POSIX nor Windows"
*>
macro String? getcwd(Allocator allocator)
{
	$switch:
		$case env::WIN32:
			@stack_mem(540; smem)
			{
				int size = 256;
				Char16[] buffer = alloc::alloc_array_try(smem, Char16, size)!;
				WString res @noinit;
				while ((res = win32::_wgetcwd(buffer, size)) == null)
				{
					// Improve error
					if (libc::errno() != ERANGE || size >= MAX_CWD) return io::GENERAL_ERROR~;
					size *= 2;
					buffer = alloc::alloc_array_try(smem, Char16, size)!;
				}
				Char16[] str16 = res[:win32::wcslen(res)];
				return string::from_utf16(allocator, str16);
			};
		$case env::POSIX:
			@stack_mem(280; smem)
			{
				sz size = 256;
				char[] buffer = alloc::alloc_array_try(smem, char, size)!;
				ZString res;
				while ((res = posix::getcwd(buffer, (usz)size)) == null)
				{
					// Improve error
					if (libc::errno() != ERANGE || size >= MAX_CWD) return io::GENERAL_ERROR~;
					size *= 2;
					buffer = alloc::alloc_array_try(smem, char, size)!;
				}
				return res.copy(allocator);
			};
		$default:
			return io::UNSUPPORTED_OPERATION~;
	$endswitch
}

