module std::io::os;
import std::io::path, libc, std::os;

<*
 Change the current working directory of the process to `path`.
 Usually called through `path::chdir`.

 On Windows every failure is reported as GENERAL_ERROR, and a path that
 can't be converted to UTF-16 panics.

 @param path : "The directory to change to"
 @return? io::NO_PERMISSION, io::NAME_TOO_LONG, io::FILE_NOT_DIR, io::FILE_NOT_FOUND, io::SYMLINK_FAILED : "On POSIX, mapped from errno"
 @return? io::GENERAL_ERROR : "On any other failure, and on any failure on Windows"
 @return? io::UNSUPPORTED_OPERATION : "On platforms that are neither POSIX nor Windows"
*>
macro void? native_chdir(Path path)
{
	@pool()
	{
		$switch:
			$case env::POSIX:
				if (posix::chdir(path.zstr_tcopy()))
				{
					switch (libc::errno())
					{
						case EACCES:       return io::NO_PERMISSION~;
						case ENAMETOOLONG: return io::NAME_TOO_LONG~;
						case ENOTDIR:      return io::FILE_NOT_DIR~;
						case ENOENT:       return io::FILE_NOT_FOUND~;
						case ELOOP:        return io::SYMLINK_FAILED~;
						default:           return io::GENERAL_ERROR~;
					}
				}
			$case env::WIN32:
				// TODO improve with better error handling.
				if (win32::setCurrentDirectoryW(path.to_temp_utf16()!!)) return;
				return io::GENERAL_ERROR~;
			$default:
				return io::UNSUPPORTED_OPERATION~;
		$endswitch
	};
}
