module std::io::os;
import libc;
import std::io::path;
import std::os::win32;
import std::os::posix;


<*
 Create a single directory; parent directories are not created.
 Usually called through `path::mkdir`, which also handles recursive creation.

 On POSIX `NORMAL` creates the directory with mode 0o777 (before umask) and any
 other permission value with 0o700. On Windows `permissions` is ignored and
 the default security attributes are used.

 @param path : "The directory to create"
 @param permissions : "The access permissions of the new directory"
 @return "true if the directory was created, false if it already existed"
 @return? io::NO_PERMISSION : "If access was denied or the file system is read-only"
 @return? io::NAME_TOO_LONG : "On POSIX, if the path is too long"
 @return? io::OUT_OF_SPACE : "If the disk or quota is full"
 @return? io::SYMLINK_FAILED : "On POSIX, on too many levels of symbolic links"
 @return? io::PARENT_DIR_MISSING : "On POSIX, if a parent directory does not exist"
 @return? io::FILE_NOT_FOUND : "If a path component is not a directory (POSIX), or the parent path is missing (Windows)"
 @return? io::GENERAL_ERROR : "On any other failure"
 @return? io::UNSUPPORTED_OPERATION : "On platforms that are neither POSIX nor Windows"
*>
macro bool? native_mkdir(Path path, MkdirPermissions permissions)
{
	@pool()
	{
	$switch:
		$case env::POSIX:
			if (!posix::mkdir(path.zstr_tcopy(), permissions == NORMAL ? 0o777 : 0o700)) return true;
			switch (libc::errno())
			{
				case EACCES:
				case EPERM:
				case EROFS:
				case EFAULT: return io::NO_PERMISSION~;
				case ENAMETOOLONG: return io::NAME_TOO_LONG~;
				case EDQUOT:
				case ENOSPC: return io::OUT_OF_SPACE~;
				case EISDIR:
				case EEXIST: return false;
				case ELOOP: return io::SYMLINK_FAILED~;
				case ENOTDIR: return io::FILE_NOT_FOUND~;
				case ENOENT: return io::PARENT_DIR_MISSING~;
				default:
					return io::GENERAL_ERROR~;
			}
		$case env::WIN32:
				// TODO security attributes
				if (win32::createDirectoryW(path.to_temp_utf16()!!, null)) return true;
				switch (win32::getLastError())
				{
					case win32::ERROR_ACCESS_DENIED:
						return io::NO_PERMISSION~;
					case win32::ERROR_DISK_FULL:
						return io::OUT_OF_SPACE~;
					case win32::ERROR_ALREADY_EXISTS:
						return false;
					case win32::ERROR_PATH_NOT_FOUND:
						return io::FILE_NOT_FOUND~;
					default:
						return io::GENERAL_ERROR~;
				}
		$default:
			return io::UNSUPPORTED_OPERATION~;
	$endswitch
	};
}