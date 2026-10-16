module std::io::os;
import libc, std::os, std::io;

<*
 Fill `stat` with the libc `stat` information for `path`, following symbolic links.
 Only available on Darwin, Linux, Android, the BSDs and Emscripten.

 @param [out] stat : "The struct to fill"
 @param path : "The file or directory to query"
 @return? io::FILE_NOT_FOUND : "If the path does not exist"
 @return? io::FILE_NOT_DIR : "If a path component is not a directory"
 @return? io::NO_PERMISSION : "If access was denied, or on too many levels of symbolic links"
 @return? io::NAME_TOO_LONG : "If the path is too long"
 @return? io::FILE_NOT_VALID, io::GENERAL_ERROR, io::UNKNOWN_ERROR : "On other failures"
*>
fn void? native_stat(Stat* stat, String path) @feat(DARWIN, LINUX, ANDROID, BSD, EMSCRIPTEN) => @pool()
{
	int res = libc::stat(path.zstr_tcopy(), stat);
	if (res != 0)
	{
		switch (libc::errno())
		{
			case EBADF:        return io::FILE_NOT_VALID~;
			case EFAULT:       unreachable("Invalid stat");
			case EIO:          return io::GENERAL_ERROR~;
			case EACCES:       return io::NO_PERMISSION~;
			case ELOOP:        return io::NO_PERMISSION~;
			case ENAMETOOLONG: return io::NAME_TOO_LONG~;
			case ENOENT:       return io::FILE_NOT_FOUND~;
			case ENOTDIR:      return io::FILE_NOT_DIR~;
			case EOVERFLOW:    return io::GENERAL_ERROR~;
			default:           return io::UNKNOWN_ERROR~;
		}
	}
}

<*
 Return the size of a file in bytes.
 Usually called through `file::get_size` / `path::file_size`.

 On platforms without `stat` or Win32 support the file is opened and the
 position at its end is returned.

 @param path : "The file to query"
 @return "The file size in bytes"
 @return? io::FILE_IS_DIR : "If the path is a directory"
 @return? io::FILE_NOT_FOUND, io::NO_PERMISSION : "If the file can't be found or accessed"
 @return? io::PATH_COULD_NOT_BE_FOUND, io::BUSY : "On Windows, if a parent directory is missing or the file is in use"
*>
fn long? native_file_size(String path)
{
	$switch:
		$case env::WIN32:
			Win32_FILE_ATTRIBUTE_DATA data;
			get_win32_file_attributes(path, &data)!;
			if (data.dwFileAttributes & win32::FILE_ATTRIBUTE_DIRECTORY) return io::FILE_IS_DIR~;
			Win32_LARGE_INTEGER size;
			size.lowPart = (Win32_DWORD)data.nFileSizeLow;
			size.highPart = (Win32_LONG)data.nFileSizeHigh;
			return (long)size.quadPart;
		$case env::DARWIN || env::LINUX || env::ANDROID || env::BSD_FAMILY  || env::EMSCRIPTEN:
			Stat stat;
			native_stat(&stat, path)!;
			if (libc_S_ISTYPE(stat.st_mode, libc::S_IFDIR)) return io::FILE_IS_DIR~;
			return stat.st_size;
		$default:
			File f = file::open(path, "r")!;
			defer (void)f.close();
			f.seek(0, FROM_END)!;
			return f.cursor();
	$endswitch

}

<*
 Check whether a file or directory exists at `path`.
 Usually called through `file::exists` / `path::exists`.

 @param path : "The path to check"
 @return "true if something exists at the path"
*>
fn bool native_file_or_dir_exists(String path)
{
	$switch:
		$case env::DARWIN:
		$case env::FREEBSD:
		$case env::NETBSD:
		$case env::OPENBSD:
		$case env::LINUX:
		$case env::ANDROID:
		$case env::EMSCRIPTEN:
			Stat stat;
			return @ok(native_stat(&stat, path));
		$case env::WIN32:
			@pool()
			{
				return (bool)win32::pathFileExistsW(path.to_temp_utf16()) ?? false;
			};
		$case env::POSIX:
			@pool()
			{
				return posix::access(path.zstr_tcopy(), 0 /* F_OK */) != -1;
			};
		$default:
			unreachable("Not supported");
	$endswitch
}

<*
 Check whether `path` is a regular file, following symbolic links.
 Usually called through `file::is_file` / `path::is_file`.

 On platforms without `stat` (including Windows) this returns true if the path
 can be opened for reading.

 @param path : "The path to check"
 @return "true if the path is a file"
*>
fn bool native_is_file(String path)
{
	$switch:
		$case env::DARWIN:
		$case env::FREEBSD:
		$case env::NETBSD:
		$case env::OPENBSD:
		$case env::LINUX:
		$case env::ANDROID:
		$case env::EMSCRIPTEN:
			Stat stat;
			return @ok(native_stat(&stat, path)) && libc_S_ISTYPE(stat.st_mode, libc::S_IFREG);
		$default:
			File? f = file::open(path, "r");
			defer (void)f.close();
			return @ok(f);
	$endswitch
}

<*
 Check whether `path` is a directory, following symbolic links.
 Usually called through `file::is_dir` / `path::is_dir`.

 On platforms without `stat` (including Windows) this is true when the path
 exists but `native_is_file` is false.

 @param path : "The path to check"
 @return "true if the path is a directory"
*>
fn bool native_is_dir(String path)
{
	$if env::DARWIN || env::LINUX || env::ANDROID || env::BSD_FAMILY || env::EMSCRIPTEN:
		Stat stat;
		return @ok(native_stat(&stat, path)) && libc_S_ISTYPE(stat.st_mode, libc::S_IFDIR);
	$else
		return native_file_or_dir_exists(path) && !native_is_file(path);
	$endif
}

<*
 Check whether `path` itself is a symbolic link.
 Usually called through `path::is_link`.

 On Windows any reparse point (symlinks, junctions) counts as a link. On
 platforms that are not supported this always returns false.

 @param path : "The path to check"
 @return "true if the path is a symbolic link"
*>
fn bool native_is_link(String path)
{
	$switch:
		$case env::DARWIN || env::LINUX || env::ANDROID || env::BSD_FAMILY || env::EMSCRIPTEN:
			@pool()
			{
				Stat stat;
				return libc::lstat(path.zstr_tcopy(), &stat) == 0 && libc_S_ISTYPE(stat.st_mode, libc::S_IFLNK);
			};
		$case env::WIN32:
			Win32_FILE_ATTRIBUTE_DATA data;
			return @ok(get_win32_file_attributes(path, &data)) && (data.dwFileAttributes & win32::FILE_ATTRIBUTE_REPARSE_POINT) != 0;
		$default:
			return false;
	$endswitch
}

<*
 Return the last modification time of a file or directory.
 Usually called through `file::last_modified`.

 @param path : "The path to query"
 @return "The modification time, in seconds since the Unix epoch"
 @return? io::FILE_NOT_FOUND, io::NO_PERMISSION : "If the path can't be found or accessed"
 @return? io::PATH_COULD_NOT_BE_FOUND, io::BUSY : "On Windows, if a parent directory is missing or the file is in use"
 @return? io::UNSUPPORTED_OPERATION : "On unsupported platforms"
*>
fn Time_t? native_get_modified_time(String path) => @pool()
{
	$switch:
		$case env::WIN32:
			Win32_FILE_ATTRIBUTE_DATA data;
			get_win32_file_attributes(path, &data)!;
			ulong ticks = ((ulong)data.ftLastWriteTime.dwHighDateTime << 32) | data.ftLastWriteTime.dwLowDateTime;
			return (Time_t)(ticks / 10_000_000UL - 11644473600UL);
		$case env::DARWIN:
			Stat stat;
			native_stat(&stat, path)!;
			return stat.st_mtimespec.s;
		$case env::LINUX:
		$case env::ANDROID:
		$case env::NETBSD:
		$case env::EMSCRIPTEN:
			Stat stat;
			native_stat(&stat, path)!;
			return (Time_t)stat.st_mtime;
		$case env::BSD_FAMILY:
			Stat stat;
			native_stat(&stat, path)!;
			return stat.st_mtime.s;
		$default:
			return io::UNSUPPORTED_OPERATION~;
	$endswitch
}


macro fault file_attr_errno() @local @feat(WIN32)
{
	switch (win32::getLastError())
	{
		case win32::ERROR_FILE_NOT_FOUND:        return io::FILE_NOT_FOUND;
		case win32::ERROR_PATH_NOT_FOUND:        return io::PATH_COULD_NOT_BE_FOUND;
		case win32::ERROR_BAD_NETPATH:           return io::PATH_COULD_NOT_BE_FOUND;
		case win32::ERROR_ACCESS_DENIED:         return io::NO_PERMISSION;
		case win32::ERROR_SHARING_VIOLATION:     return io::BUSY;
		case win32::ERROR_LOCK_VIOLATION:        return io::BUSY;
		case win32::ERROR_TOO_MANY_OPEN_FILES:   return io::TOO_MANY_DESCRIPTORS;
		case win32::ERROR_FILENAME_EXCED_RANGE:  return io::NAME_TOO_LONG;
		case win32::ERROR_BUFFER_OVERFLOW:       return io::NAME_TOO_LONG;
		case win32::ERROR_INVALID_NAME:          return io::ILLEGAL_ARGUMENT;
		case win32::ERROR_BAD_PATHNAME:          return io::ILLEGAL_ARGUMENT;
		case win32::ERROR_DIRECTORY:             return io::FILE_NOT_DIR;
		case win32::ERROR_INVALID_HANDLE:        return io::FILE_NOT_VALID;
		case win32::ERROR_NOT_READY:             return io::BUSY;
		case win32::ERROR_WRITE_PROTECT:         return io::READ_ONLY;
		default:                                 return io::UNKNOWN_ERROR;
	}
}

fn void? get_win32_file_attributes(String path, Win32_FILE_ATTRIBUTE_DATA* data_ptr) @local @feat(WIN32) => @pool()
{
	if (!win32::getFileAttributesExW(path.to_temp_wstring()!, Win32_GET_FILEEX_INFO_LEVELS.STANDARD, data_ptr))
	{
		return file_attr_errno()~;
	}
}
