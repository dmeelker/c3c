module std::io::path;
import std::collections::list, std::io::os;
import std::os::win32;

<* The path type of the current platform: `PathWin` on Windows, `PathPosix` elsewhere. *>
alias Path = env::WIN32 ? PathWin : PathPosix;
<* The path conventions of the current platform. *>
const PathEnv DEFAULT_ENV = env::WIN32 ? PathEnv.WIN32 : PathEnv.POSIX;

<* A path string, the common base of `PathWin` and `PathPosix`. *>
typedef PathCommon = inline String;
<* A path using Windows conventions (`\` separators, optional volume name). *>
typedef PathWin = inline PathCommon;
<* A path using POSIX conventions (`/` separators). *>
typedef PathPosix = inline PathCommon;

<* The path separator characters. *>
constset PathSeparator : inline char
{
	WIN32 = '\\',
	POSIX = '/'
}
<* The path separator of the current platform. *>
const PathSeparator PREFERRED_SEPARATOR = env::WIN32 ? WIN32 : POSIX;

<* A list of paths, as returned by `ls`. *>
alias PathList = List { Path };

excuse
{
	<* The path is empty where not allowed, malformed, or contains reserved characters. *>
	INVALID_PATH,
	<* The path has no parent component. *>
	NO_PARENT
}

<*
 Get the current working directory.

 @param allocator : "The allocator for the returned path"
 @return "The current working directory"
*>
fn Path? cwd(Allocator allocator)
{
	@pool()
	{
		return new(allocator, os::getcwd(tmem));
	};
}

<* A set of path conventions (separator, volume names, reserved characters) to parse paths with. *>
enum PathEnv : (PathSeparator separator)
{
	WIN32 { WIN32 },
	POSIX { POSIX }
}

<*
 Check if the path refers to an existing directory.

 @return "true if the path is a directory"
*>
fn bool is_dir(Path path) => os::native_is_dir(path);

<*
 Check if the path refers to an existing regular file.

 @return "true if the path is a file"
*>
fn bool is_file(Path path) => os::native_is_file(path);

<*
 Check if the path refers to a symbolic link.

 @return "true if the path is a symbolic link"
*>
fn bool is_link(Path path) => os::native_is_link(path);

<*
 Get the size of a file in bytes.

 @return "The file size in bytes"
*>
fn long? file_size(Path path) => os::native_file_size(path);

<*
 Check if a file or directory exists at the path.

 @return "true if the path exists"
*>
fn bool exists(Path path) => os::native_file_or_dir_exists(path);

<*
 Get the current working directory, allocated with the temp allocator.

 @return "The current working directory"
*>
fn Path? tcwd() => cwd(tmem) @inline;

<*
 Change the current working directory.

 #### Example:
 ```
 Path old = path::tcwd()!!;
 path::chdir(path::temp_directory(tmem)!!)!!;
 // ... work in the temp directory ...
 path::chdir(old)!!;
 ```

 @param path : "The directory to change to, as a Path or String"
 @return? io::FILE_NOT_FOUND, io::FILE_NOT_DIR, io::NO_PERMISSION, io::GENERAL_ERROR : "If the directory could not be entered (Windows only reports GENERAL_ERROR)"
 @require @is_pathlike(path) : "Expected a Path or String to chdir"
*>
macro void? chdir(path)
{
	$if $Typeof(path) == String:
		@pool()
		{
			return os::native_chdir(tnew(path));
		};
	$else
		return os::native_chdir(path) @inline;
	$endif
}

<*
 Get the directory for temporary files.

 On POSIX this is the first of TMPDIR, TMP, TEMP or TEMPDIR that is set, otherwise "/tmp".

 @param allocator : "The allocator for the returned path"
 @return "The temp directory"
*>
fn Path? temp_directory(Allocator allocator) => os::native_temp_directory(allocator);

<*
 Get the home directory of the current user.

 @param allocator : "The allocator for the returned path"
 @return "The home directory"
 @return? io::PATH_COULD_NOT_BE_FOUND : "If it could not be determined on this platform"
*>
fn Path? home_directory(Allocator allocator) => os::native_home_directory(allocator);

<*
 Get the desktop directory of the current user.

 @param allocator : "The allocator for the returned path"
 @return "The desktop directory"
 @return? io::PATH_COULD_NOT_BE_FOUND : "If it could not be determined on this platform"
*>
fn Path? desktop_directory(Allocator allocator) => os::native_user_directory(allocator, DESKTOP);

<*
 Get the videos directory of the current user.

 @param allocator : "The allocator for the returned path"
 @return "The videos directory"
 @return? io::PATH_COULD_NOT_BE_FOUND : "If it could not be determined on this platform"
*>
fn Path? videos_directory(Allocator allocator) => os::native_user_directory(allocator, VIDEOS);

<*
 Get the music directory of the current user.

 @param allocator : "The allocator for the returned path"
 @return "The music directory"
 @return? io::PATH_COULD_NOT_BE_FOUND : "If it could not be determined on this platform"
*>
fn Path? music_directory(Allocator allocator) => os::native_user_directory(allocator, MUSIC);

<*
 Get the documents directory of the current user.

 @param allocator : "The allocator for the returned path"
 @return "The documents directory"
 @return? io::PATH_COULD_NOT_BE_FOUND : "If it could not be determined on this platform"
*>
fn Path? documents_directory(Allocator allocator) => os::native_user_directory(allocator, DOCUMENTS);

<*
 Get the screenshots directory of the current user. Only available on Windows.

 @param allocator : "The allocator for the returned path"
 @return "The screenshots directory"
 @return? io::PATH_COULD_NOT_BE_FOUND : "If it could not be determined on this platform"
*>
fn Path? screenshots_directory(Allocator allocator) => os::native_user_directory(allocator, SCREENSHOTS);

<*
 Get the saved games directory of the current user. Only available on Windows.

 @param allocator : "The allocator for the returned path"
 @return "The saved games directory"
 @return? io::PATH_COULD_NOT_BE_FOUND : "If it could not be determined on this platform"
*>
fn Path? saved_games_directory(Allocator allocator) => os::native_user_directory(allocator, SAVED_GAMES);

<*
 Get the downloads directory of the current user.

 @param allocator : "The allocator for the returned path"
 @return "The downloads directory"
 @return? io::PATH_COULD_NOT_BE_FOUND : "If it could not be determined on this platform"
*>
fn Path? downloads_directory(Allocator allocator) => os::native_user_directory(allocator, DOWNLOADS);

<*
 Get the pictures directory of the current user.

 @param allocator : "The allocator for the returned path"
 @return "The pictures directory"
 @return? io::PATH_COULD_NOT_BE_FOUND : "If it could not be determined on this platform"
*>
fn Path? pictures_directory(Allocator allocator) => os::native_user_directory(allocator, PICTURES);

<*
 Get the templates directory of the current user. Not available on Apple platforms.

 @param allocator : "The allocator for the returned path"
 @return "The templates directory"
 @return? io::PATH_COULD_NOT_BE_FOUND : "If it could not be determined on this platform"
*>
fn Path? templates_directory(Allocator allocator) => os::native_user_directory(allocator, TEMPLATES);

<*
 Get the public share directory of the current user. Not available on Windows.

 @param allocator : "The allocator for the returned path"
 @return "The public share directory"
 @return? io::PATH_COULD_NOT_BE_FOUND : "If it could not be determined on this platform"
*>
fn Path? public_share_directory(Allocator allocator) => os::native_user_directory(allocator, PUBLIC_SHARE);

<*
 Delete a file.

 @param path : "The file to delete"
 @return? io::FILE_NOT_FOUND : "If the file does not exist"
 @return? io::FILE_CANNOT_DELETE : "If the file can't be deleted for any other reason"
*>
fn void? delete(PathCommon path) => os::native_remove(path) @inline;

<*
 Check at compile time if an expression is a Path (or other PathCommon) or a String.

 @return "true if the expression can be used as a path"
*>
macro bool @is_pathlike(#path) @const => $Typeof(#path) == String ||| $defined(PathCommon c = #path);

<*
 Check if a character is a path separator: '/' always, and also '\' for WIN32.

 @param c : "The character to test"
 @param path_env : "The path conventions to use"
 @return "true if c is a separator"
*>
macro bool is_separator(char c, PathEnv path_env = DEFAULT_ENV)
{
	return c == '/' || (c == '\\' && path_env == WIN32);
}

<*
 Check if a character is a POSIX path separator ('/').

 @return "true if c is '/'"
*>
macro bool is_posix_separator(char c) => c == '/';

<*
 Check if a character is a Windows path separator ('/' or '\').

 @return "true if c is '/' or '\'"
*>
macro bool is_win32_separator(char c) =>  c == '/' || c == '\\';

<*
 List directory contents. The entries "." and ".." are not included.

 #### Example:
 ```
 // All .c3 files below "src", e.g. "main.c3" and "sub/util.c3" ("sub\\util.c3" on Windows)
 PathList files = path::ls(tmem, path::tnew("src")!!, no_dirs: true, mask: "*.c3", recursive: true)!!;
 foreach (f : files) io::printn(f);
 ```

 @param allocator : `The allocator for the returned list and paths`
 @param dir : `The directory to list`
 @param no_dirs : `Exclude directories from the result`
 @param no_symlinks : `Exclude symbolic links from the result, where supported by the platform`
 @param mask : `Optional pattern. Supports one '*' wildcard, for example "*.c3" or "foo*bar"`
 @param recursive : `If true, recursively include entries in subdirectories`
 @param relative : `If true, return paths relative to dir. Defaults to true`
 @param rebase : `If non-empty, prepend this path to each returned entry`
 @return "The list of entries"
 @return? io::CANNOT_READ_DIR, io::FILE_NOT_DIR : "If the directory can't be opened or doesn't exist"
 @return? io::UNSUPPORTED_OPERATION : "If listing directories is not supported on this platform"
*>
fn PathList? ls(Allocator allocator, Path dir, bool no_dirs = false, bool no_symlinks = false, String mask = "", bool recursive = false, bool relative = true, Path rebase = (Path)"")
{
	PathList list;
	list.init(allocator);
	_ls_collect(allocator, &list, dir, (Path)"", no_dirs, no_symlinks, mask, recursive, relative, rebase)!;
	return list;
}

<* Access permissions for a new directory. On POSIX NORMAL is 0o777 and the others 0o700; ignored on Windows. *>
enum MkdirPermissions
{
	NORMAL,
	USER_ONLY,
	USER_AND_ADMIN
}

<*
 Create a directory on a given path, optionally recursive.

 #### Example:
 ```
 path::mkdir("out/logs", recursive: true)!!; // true
 path::mkdir("out")!!; // false, it already exists
 ```

 @param path : `The path to create, as a Path or String`
 @param recursive : `If directories in between should be created if they're missing, defaults to false`
 @param permissions : `The permissions to set on the directory`
 @return "true if the directory was created, false if it already existed"
 @return? INVALID_PATH : "If the path is empty or invalid"
 @return? io::FILE_NOT_DIR : "If a file exists at the path"
 @return? io::CANNOT_READ_DIR : "If the parent directory does not exist"
 @require @is_pathlike(path) : "Expected a Path or String to mkdir"
*>
macro bool? mkdir(path, bool recursive = false, MkdirPermissions permissions = NORMAL)
{
	$if $Typeof(path) == String:
		@pool() { return _mkdir(tnew(path), recursive, permissions); };
	$else
		return _mkdir(path, recursive, permissions);
	$endif
}


<*
 Tries to delete directory, which must be empty.

 #### Example:
 ```
 path::mkdir("scratch")!!;
 path::rmdir(path::tnew("scratch")!!)!!; // true
 ```

 @param path : `The path to delete`
 @return `true if there was a directory to delete, false otherwise. On Windows a missing directory in an existing parent gives GENERAL_ERROR instead`
 @return? INVALID_PATH : `if the path was invalid`
 @return? io::DIR_NOT_EMPTY : "If the directory is not empty"
 @require @is_pathlike(path) : "Expected a Path or String to rmdir"
*>
macro bool? rmdir(path)
{
	$if $Typeof(path) == String:
		@pool() { return _rmdir(temp(path)); };
	$else
		return _rmdir(path);
	$endif
}

<*
 Like `rmdir` but deletes a directory even if it contains items.

 @param path : "The directory to delete, including all its contents"
 @return? INVALID_PATH : "If the path is empty"
 @return? io::UNSUPPORTED_OPERATION : "If not supported on this platform"
*>
fn void? rmtree(Path path)
{
	if (!path.len) return INVALID_PATH~;
	$if $defined(os::native_rmtree):
		return os::native_rmtree(path);
	$else
		return io::UNSUPPORTED_OPERATION~;
	$endif
}

<*
 Creates a new normalized path for the current platform, see `normalize`.

 #### Example:
 ```
 Path p = path::new(mem, "foo/./bar/../baz")!!; // "foo/baz" on POSIX, "foo\\baz" on Windows
 defer p.free(mem);
 ```

 @param allocator : "The allocator for the path"
 @param path : "The path string, which is copied"
 @return "The normalized path"
 @return? INVALID_PATH : `if the path was invalid`
*>
fn Path? new(Allocator allocator, String path)
{
	return (Path)normalize(path.copy(allocator), DEFAULT_ENV);
}

<*
 Creates a new path using the temp allocator.

 @param path : "The path string, which is copied"
 @return "The normalized path"
 @return? INVALID_PATH : `if the path was invalid`
*>
fn Path? tnew(String path) => new(tmem, path);

<*
 Creates a new path from a UTF-16 zero-terminated string.

 @param allocator : "The allocator for the path"
 @param path : "The wide string to convert"
 @return "The normalized path"
 @return? INVALID_PATH : "If the path was invalid"
*>
fn Path? from_wstring(Allocator allocator, WString path) => @pool()
{
	return path::new(allocator, string::tfrom_wstring(path)!);
}

<*
 Creates a new normalized path using Windows conventions, regardless of platform.

 #### Example:
 ```
 PathWin p = path::for_windows(tmem, "C:/foo//bar")!!; // "C:\\foo\\bar"
 ```

 @param allocator : "The allocator for the path"
 @param path : "The path string, which is copied"
 @return "The normalized path"
 @return? INVALID_PATH : "If the path was invalid"
*>
fn PathWin? for_windows(Allocator allocator, String path) => (PathWin)normalize(path.copy(allocator), WIN32);

<*
 Creates a new normalized path using POSIX conventions, regardless of platform.

 #### Example:
 ```
 PathPosix p = path::for_posix(tmem, "/usr//lib/")!!; // "/usr/lib"
 ```

 @param allocator : "The allocator for the path"
 @param path : "The path string, which is copied"
 @return "The normalized path"
 @return? INVALID_PATH : "If the path was invalid"
*>
fn PathPosix? for_posix(Allocator allocator, String path) => (PathPosix)normalize(path.copy(allocator), POSIX);


<*
 Append one or more strings to the current path, inserting separators as needed.
 Empty parts are skipped and the result is normalized.

 #### Example:
 ```
 PathWin p = path::for_windows(tmem, "C:\\foo")!!;
 PathWin q = p.append(mem, "bar", "baz", extension: "txt")!!; // "C:\\foo\\bar\\baz.txt"
 defer q.free(mem);
 ```

 @param allocator : "The allocator for the new path"
 @param [in] parts
 @param extension : "The optional extension to append, automatically inserting a '.' if necessary."
 @return "A new path"
 @return? INVALID_PATH : "If the resulting path is invalid"
*>
fn PathWin? PathWin.append(self, Allocator allocator, String... parts, String extension = "") => @pool()
{
	return _append_path(self, allocator, parts, extension, WIN32);
}

<*
 Append one or more strings to the current path, inserting separators as needed.
 Empty parts are skipped and the result is normalized.

 #### Example:
 ```
 PathPosix p = path::for_posix(tmem, "/usr")!!;
 PathPosix q = p.append(mem, "lib", "libc", extension: "so")!!; // "/usr/lib/libc.so"
 defer q.free(mem);
 ```

 @param allocator : "The allocator for the new path"
 @param [in] parts
 @param extension : "The optional extension to append, automatically inserting a '.' if necessary."
 @return "A new path"
 @return? INVALID_PATH : "If the resulting path is invalid"
*>
fn PathPosix? PathPosix.append(self, Allocator allocator, String... parts, String extension = "") => @pool()
{
	return _append_path(self, allocator, parts, extension, POSIX);
}

<*
 Append one or more strings to the current path, using the temp allocator. See `PathPosix.append`.

 @param [in] parts
 @param extension : "The optional extension to append, automatically inserting a '.' if necessary."
 @return "A new path"
 @return? INVALID_PATH : "If the resulting path is invalid"
*>
fn PathPosix? PathPosix.tappend(self, String... parts, String extension = "") => self.append(tmem, ...parts, extension: extension);

<*
 Append one or more strings to the current path, using the temp allocator. See `PathWin.append`.

 @param [in] parts
 @param extension : "The optional extension to append, automatically inserting a '.' if necessary."
 @return "A new path"
 @return? INVALID_PATH : "If the resulting path is invalid"
*>
fn PathWin? PathWin.tappend(self, String... parts, String extension = "") => self.append(tmem, ...parts, extension: extension);

<*
 Check if the string is an absolute path on the current platform.

 @return "true if the path is absolute"
 @return? INVALID_PATH : "If the string is not a valid path"
*>
fn bool? String.is_absolute_path(self) => @pool()
{
	return tnew(self).is_absolute();
}

<*
 Check if the path is absolute, that is, starts with '/'.

 @return "true if the path is absolute"
*>
fn bool? PathPosix.is_absolute(self)
{
	return self.len > 0 && self[0] == PathSeparator.POSIX;
}

<*
 Check if the path is absolute: it has a root directory, like "C:\foo",
 "\foo" or "\\server\share\foo". "C:foo" is not absolute.

 #### Example:
 ```
 path::for_windows(tmem, "C:\\foo")!!.is_absolute()!!; // true
 path::for_windows(tmem, "C:foo")!!.is_absolute()!!; // false
 ```

 @return "true if the path is absolute"
 @return? INVALID_PATH : "If the path has a malformed volume name"
*>
fn bool? PathWin.is_absolute(self)
{
	if (!self.len) return false;
	sz path_start = volume_name_len_win(self)!;
	if (path_start > 0 && self[0] == '\\') return true;
	return path_start < self.len && is_separator(self[path_start], WIN32);
}


<*
 Convert the string to an absolute path, resolving it against the current working directory.

 @param allocator : "The allocator for the returned path"
 @return "The absolute path"
 @return? INVALID_PATH : "If the string is empty or not a valid path"
*>
fn Path? String.to_absolute_path(self, Allocator allocator) => @pool()
{
	return tnew(self).absolute(allocator);
}

<*
 Get the absolute form of the path, resolving it against the current working directory.
 An already absolute path is just copied.

 #### Example:
 ```
 Path p = path::tnew("foo")!!.absolute(tmem)!!; // e.g. "/home/user/foo" on POSIX, "C:\\Users\\user\\foo" on Windows
 ```

 @param allocator : "The allocator for the returned path"
 @return "The absolute path"
 @return? INVALID_PATH : "If the path is empty or could not be resolved"
*>
fn Path? Path.absolute(self, Allocator allocator)
{
	if (!self.len) return INVALID_PATH~;
	if (self.is_absolute()!) return self.copy(allocator);
	if (self == ".")
	{
		return (Path)os::getcwd(allocator);
	}
	$if Path::typeid == PathWin:
		@pool()
		{
			const sz BUFFER_LEN = 4096;
			WString buffer = (WString)mem::talloc_array(Char16, BUFFER_LEN);
			buffer = win32::_wfullpath(buffer, self.to_temp_wstring()!, BUFFER_LEN);
			if (!buffer) return INVALID_PATH~;
			return (Path)string::from_wstring(allocator, buffer);
		};
	$else
		Path cwd = (Path)os::getcwd(tmem)!;
		return cwd.append(allocator, self);
	$endif
}

<*
 Get the last component of the path in the string, see `PathPosix.basename`.

 #### Example:
 ```
 String name = "foo/bar.c3".file_basename(mem)!!; // "bar.c3"
 defer free(name);
 ```

 @param allocator : "The allocator for the returned string"
 @return "A copy of the last path component"
 @return? INVALID_PATH : "If the string is not a valid path"
*>
fn String? String.file_basename(self, Allocator allocator) => @pool()
{
	return tnew(self).basename().copy(allocator);
}

<*
 Get the last component of the path in the string, using the temp allocator.

 @return "A copy of the last path component"
 @return? INVALID_PATH : "If the string is not a valid path"
*>
fn String? String.file_tbasename(self) => self.file_basename(tmem);

<*
 Get the last component of the path, or "" if the path is only a root or volume.
 This does not allocate, but returns a slice of the path itself.

 #### Example:
 ```
 path::for_windows(tmem, "C:\\foo\\bar.c3")!!.basename(); // "bar.c3"
 ```

 @return "The last path component"
*>
fn String PathWin.basename(self) => _basename(self);

<*
 Get the last component of the path, or "" if the path is only "/".
 This does not allocate, but returns a slice of the path itself.

 #### Example:
 ```
 path::for_posix(tmem, "/foo/bar.c3")!!.basename(); // "bar.c3"
 ```

 @return "The last path component"
*>
fn String PathPosix.basename(self) => _basename(self);

<*
 Get the directory part of the path in the string, using the temp allocator.

 @return `A copy of the directory part, or "." if there is none`
 @return? INVALID_PATH : "If the string is not a valid path"
*>
fn String? String.path_tdirname(self) => self.path_dirname(tmem);

<*
 Get the directory part of the path in the string, see `PathPosix.dirname`.

 #### Example:
 ```
 String dir = "foo/bar.c3".path_dirname(mem)!!; // "foo"
 defer free(dir);
 ```

 @param allocator : "The allocator for the returned string"
 @return `A copy of the directory part, or "." if there is none`
 @return? INVALID_PATH : "If the string is not a valid path"
*>
fn String? String.path_dirname(self, Allocator allocator) => @pool()
{
	return tnew(self).dirname().copy(allocator);
}

<*
 Get the path without its last component, or "." if it has no directory part.
 This does not allocate, but returns a slice of the path itself.

 #### Example:
 ```
 path::for_posix(tmem, "/foo/bar.c3")!!.dirname(); // "/foo"
 path::for_posix(tmem, "/foo")!!.dirname(); // "/"
 path::for_posix(tmem, "foo")!!.dirname(); // "."
 ```

 @return "The directory part of the path"
*>
fn String PathPosix.dirname(self)
{
	sz basename_start = start_of_base_name(self, POSIX)!!;
	if (basename_start == 0) return ".";
	if (basename_start <= 1)
	{
		return self[:basename_start];
	}
	return self[:basename_start - 1];
}

<*
 Get the path without its last component, or "." if it has no directory part.
 The volume name and root are kept. This does not allocate, but returns a slice of the path itself.

 #### Example:
 ```
 path::for_windows(tmem, "C:\\foo\\bar.c3")!!.dirname(); // "C:\\foo"
 path::for_windows(tmem, "C:\\foo")!!.dirname(); // "C:\\"
 ```

 @return "The directory part of the path"
*>
fn String PathWin.dirname(self)
{
	sz basename_start = start_of_base_name(self, WIN32)!!;
	if (basename_start == 0) return ".";
	sz start = volume_name_len_win(self)!!;
	if (basename_start <= start + 1)
	{
		if (basename_start > start && self[0..1] == `\\`)
		{
			return self[:basename_start - 1];
		}
		return self[:basename_start];
	}
	return self[:basename_start - 1];
}


<*
 Test if the path has the given extension, so given the path /foo/bar.c3
 this would be true matching the extension "c3"

 @param [in] extension : `The extension name (not including the leading '.')`
 @require extension.len > 0 : `The extension cannot be empty`
 @return `true if the extension matches`
*>
fn bool PathPosix.has_extension(self, String extension) => _has_extension(self, extension);

<*
 Test if the path has the given extension, so given the path C:\foo\bar.c3
 this would be true matching the extension "c3"

 @param [in] extension : `The extension name (not including the leading '.')`
 @require extension.len > 0 : `The extension cannot be empty`
 @return `true if the extension matches`
*>
fn bool PathWin.has_extension(self, String extension) => _has_extension(self, extension);

<*
 Get the extension of the path's last component, without the leading '.'.
 This does not allocate, but returns a slice of the path itself.

 #### Example:
 ```
 path::for_windows(tmem, "C:\\foo\\a.tar.gz")!!.extension()!!; // "gz"
 path::for_windows(tmem, "C:\\foo\\.gitignore")!!.extension()!!; // ""
 ```

 @return `The extension, or "" for names starting with '.' and no other '.'`
 @return? NOT_FOUND : "If the last component contains no '.'"
*>
fn String? PathWin.extension(self) => _extension(self);

<*
 Get the extension of the path's last component, without the leading '.'.
 This does not allocate, but returns a slice of the path itself.

 #### Example:
 ```
 path::for_posix(tmem, "/foo/a.tar.gz")!!.extension()!!; // "gz"
 path::for_posix(tmem, "/foo/.bashrc")!!.extension()!!; // ""
 ```

 @return `The extension, or "" for names starting with '.' and no other '.'`
 @return? NOT_FOUND : "If the last component contains no '.'"
*>
fn String? PathPosix.extension(self) => _extension(self);

<*
 Get the volume name of the path, which is always "" for POSIX paths.

 @return `Always ""`
*>
fn String PathPosix.volume_name(self) => "";

<*
 Get the volume name of the path, such as "C:" or "\\server\share", or "" if there is none.

 #### Example:
 ```
 path::for_windows(tmem, "C:\\foo")!!.volume_name(); // "C:"
 path::for_windows(tmem, "\\\\server\\share\\foo")!!.volume_name(); // "\\\\server\\share"
 ```

 @return "The volume name"
*>
fn String PathWin.volume_name(self)
{
	sz len = volume_name_len_win(self)!!;
	if (!len) return "";
	return self[:len];
}

<*
 Convert the string to a normalized path for the current platform, see `new`.

 @param allocator : "The allocator for the path"
 @return "The normalized path"
 @return? INVALID_PATH : "If the path was invalid"
*>
fn Path? String.to_path(self, Allocator allocator) => new(allocator, self);

<*
 Convert the string to a normalized path for the current platform, using the temp allocator.

 @return "The normalized path"
 @return? INVALID_PATH : "If the path was invalid"
*>
fn Path? String.to_tpath(self) => new(tmem, self);


<*
 Get the path of the parent. This does not allocate, but returns a slice
 of the path itself.

 #### Example:
 ```
 path::for_windows(tmem, "C:\\foo\\bar")!!.parent()!!; // "C:\\foo"
 path::for_windows(tmem, "C:\\foo")!!.parent()!!; // "C:\\"
 ```

 @return `The parent of the path as a non-allocated path`
 @return? NO_PARENT : `if this path does not have a parent`
*>
fn PathWin? PathWin.parent(self) => _parent(self);

<*
 Get the path of the parent. This does not allocate, but returns a slice
 of the path itself.

 #### Example:
 ```
 path::for_posix(tmem, "/foo/bar")!!.parent()!!; // "/foo"
 path::for_posix(tmem, "/foo")!!.parent()!!; // "/"
 ```

 @return `The parent of the path as a non-allocated path`
 @return? NO_PARENT : `if this path does not have a parent`
*>
fn PathPosix? PathPosix.parent(self) => _parent(self);


<*
 Normalize a path string in place: separators are converted to the preferred one
 and repeated ones folded, "." components are removed, "name/.." pairs are collapsed
 and a trailing separator is dropped. Leading ".." components of relative paths are kept.
 A path that collapses to nothing (e.g. "a/..") becomes "."; an empty input stays empty.

 #### Example:
 ```
 String s = "a//b/./c/../d/".tcopy();
 path::normalize(s, PathEnv.POSIX)!!; // "a/b/d"
 String w = "c:/foo/../bar".tcopy();
 path::normalize(w, PathEnv.WIN32)!!; // "c:\\bar"
 ```

 @param path_str : "The path to normalize, which is modified"
 @param path_env : "The path conventions to use"
 @return "A slice of path_str with the normalized path"
 @return? INVALID_PATH : "If the path contains reserved characters, a malformed volume name, or '..' above the root"
*>
fn String? normalize(String path_str, PathEnv path_env = DEFAULT_ENV)
{
	if (!path_str.len) return path_str;
	sz path_start = 0;
	if (path_env == WIN32)
	{
		path_start = volume_name_len_win(path_str)!;
		if (path_start > 0)
		{
			for (sz i = 0; i < path_start; i++) if (path_str[i] == '/') path_str[i] = '\\';
		}
	}
	sz path_len = path_str.len;
	if (path_start == path_len) return path_str;
	PathSeparator path_separator = path_env.separator;
	sz len = path_start;
	bool has_root = is_separator(path_str[path_start], path_env);
	if (has_root)
	{
		path_str[len++] = path_separator;
		path_start++;
	}
	// It is safe to write it as true, since we already dealt with /foo.
	// This allows us to avoid checking whether it is the start of the path.
	bool previous_was_separator = true;

	for (sz i = path_start; i < path_len; i++)
	{
		char c = path_str[i];
		// Fold foo///bar into foo/bar
		if (is_separator(c, path_env))
		{
			// Fold //
			if (previous_was_separator) continue;

			// New /, so mark and rewrite
			path_str.ptr[len++] = path_separator;
			previous_was_separator = true;
			continue;
		}

		// The rest are names of the path elements, so check that the
		// characters are valid.
		if (is_reserved_path_char(c, path_env)) return INVALID_PATH~;

		// If we have '.' after a separator
		if (c == '.' && previous_was_separator)
		{
			// Get the number of dots until next separator, expecting 1 or 2
			bool is_last = i == path_len - 1;
			int dots = 1;
			if (!is_last)
			{
				char next = path_str[i + 1];
				switch
				{
					case next == '.':
						dots = 2;
						is_last = i == path_len - 2;
						if (!is_last && !is_separator(path_str[i + 2], path_env))
						{
							dots = 0;
						}
					case !is_separator(next, path_env):
						dots = 0;
				}
			}
			switch (dots)
			{
				case 1:
					// /./abc -> skip to /./abc
					//  ^                  ^
					i++;
					continue;
				case 2:
					// This is an error: /a/../..
					if (len == path_start && has_root) return INVALID_PATH~;

					// If this .. at the start, or after ../? If so, we just copy ..
					if (len == path_start ||
						(len - path_start >= 3 && path_str[len - 1] == path_separator
						&& path_str[len - 3] == '.' && path_str[len - 2] == '.' &&
						(len - 3 == 0 || path_str[len - 4] == path_separator)))
					{
						if (i != len) path_str[len:2] = ".."[:2];
						len += 2;
						if (len < path_len) path_str[len++] = path_separator;
						i += 2;
						continue;
					}
					// Step back, now looking at '/' abc/def/. -> abc/def/
					len--;
					// Step back until finding a separator or the start.
					while (len > path_start && !is_separator(path_str[len - 1], path_env))
					{
						len--;
					}
					// Reading, we go from /../abc to /../abc
					//                      ^            ^
					i += 2;
					continue;
				default:
					break;

			}
		}
		if (i != len) path_str[len] = c;
		previous_was_separator = false;
		len++;
	}
	if (len > path_start + 1 && is_separator(path_str[len - 1], path_env)) len--;
	if (path_str.len > len) path_str.ptr[len] = 0;
	// Empty path after normalization -> "."
	if (!len)
	{
		path_str[0] = '.';
		return path_str[:1];
	}
	return path_str[:len];
}

<*
 Get the root directory separator following the volume name, or "" if the path is relative.

 #### Example:
 ```
 path::for_windows(tmem, "C:\\foo")!!.root_directory(); // "\\"
 path::for_windows(tmem, "C:foo")!!.root_directory(); // ""
 ```

 @return `The root separator, "." for the path ".", or ""`
*>
fn String PathWin.root_directory(self) => _root_directory(self, WIN32);

<*
 Get the root of the path, or "" if the path is relative.

 Note: this currently returns the first component including the leading '/', so "/usr/lib" gives "/usr".

 @return `The root part of the path, "." for the path ".", or ""`
*>
fn String PathPosix.root_directory(self) => _root_directory(self, POSIX);

<* A callback for `Path.walk`, receiving each path, whether it is a directory, and the user data. Return true to stop the walk. *>
alias PathWalker = fn bool? (Path, bool is_dir, void*);

<*
 Walk the path recursively. PathWalker is run on every file and
 directory found. Return true to abort the walk.

 The paths passed to the walker are absolute and only valid during the call.

 #### Example:
 ```
 fn bool? count_files(Path p, bool is_dir, void* data)
 {
 	if (!is_dir) (*(int*)data)++;
 	return false;
 }

 fn void main()
 {
 	int count;
 	path::tnew("src")!!.walk(&count_files, &count)!!;
 }
 ```

 @param w : "The callback to run for every entry"
 @param data : "User data passed to the callback"
 @return "true if the walk was aborted by the callback, false otherwise"
*>
fn bool? Path.walk(self, PathWalker w, void* data)
{
	const PATH_MAX = 512;
	@stack_mem(PATH_MAX; Allocator allocator)
	{
		Path abs = self.absolute(allocator)!;
		PathList files = ls(allocator, abs)!;
		foreach (f : files)
		{
			if (f == "." || f == "..") continue;
			f = abs.append(allocator, f)!;
			bool is_directory = is_dir(f);
			if (w(f, is_directory, data)!) return true;
			if (is_directory && f.walk(w, data)!) return true;
		}
	};
	return false;
}

<* A callback for `traverse`, receiving each path, whether it is a directory, and the user data. Return true to stop the walk. *>
alias TraverseCallback = fn bool? (Path, bool is_dir, any data);

<*
 Walk the path recursively. TraverseCallback is run for every file and
 directory found. Return true to abort the walk.

 The paths passed to the callback are absolute and only valid during the call.

 #### Example:
 ```
 fn bool? count_entries(Path p, bool is_dir, any data)
 {
 	(*anycast(data, int)!!)++;
 	return false;
 }

 fn void main()
 {
 	int count;
 	path::traverse(path::tnew("src")!!, &count_entries, &count)!!;
 }
 ```

 @param path : "The directory to walk"
 @param callback : "The callback to run for every entry"
 @param data : "User data passed to the callback"
 @return "true if the walk was aborted by the callback, false otherwise"
*>
fn bool? traverse(Path path, TraverseCallback callback, any data)
{
	const PATH_MAX = 512;
	@stack_mem(PATH_MAX; Allocator allocator)
	{
		Path abs = path.absolute(allocator)!;
		PathList files = ls(allocator, abs)!;
		foreach (f : files)
		{
			if (f == "." || f == "..") continue;
			@stack_mem(128; Allocator smem)
			{
				f = abs.append(smem, f)!;
				bool is_directory = is_dir(f);
				if (callback(f, is_directory, data)!) return true;
				if (is_directory && traverse(f, callback, data)!) return true;
			};
		}
	};
	return false;
}

<*
 Check if the path string ends with str. This is a plain string comparison.

 @return "true if the path ends with str"
*>
fn bool PathCommon.has_suffix(self, String str) => self.ends_with(str);

<*
 Copy the path.

 @param allocator : "The allocator for the copy"
 @return "A copy of the path"
*>
fn PathWin PathWin.copy(self, Allocator allocator) => (PathWin)((String)self).copy(allocator);

<*
 Copy the path using the temp allocator.

 @return "A copy of the path"
*>
fn PathWin PathWin.tcopy(self) => self.copy(tmem) @inline;

<*
 Copy the path.

 @param allocator : "The allocator for the copy"
 @return "A copy of the path"
*>
fn PathPosix PathPosix.copy(self, Allocator allocator) => (PathPosix)((String)self).copy(allocator);

<*
 Copy the path using the temp allocator.

 @return "A copy of the path"
*>
fn PathPosix PathPosix.tcopy(self) => self.copy(tmem) @inline;

<*
 Free a path allocated with the given allocator.

 @param allocator : "The allocator the path was allocated with"
*>
fn void PathCommon.free(self, Allocator allocator) => alloc::free(allocator, self.ptr);

<* Characters that may not appear in a POSIX path component. *>
const bool[256] RESERVED_PATH_CHAR_POSIX = {
	[0] = true,
	['/'] = true,
};
<* Characters that may not appear in a Windows path component. *>
const bool[256] RESERVED_PATH_CHAR_WIN32 = {
	[0..31] = true,
	['>'] = true,
	['<'] = true,
	[':'] = true,
	['\"'] = true,
	['/'] = true,
	['\\'] = true,
	['|'] = true,
	['?'] = true,
	['*'] = true,
};

<*
 Check if a character may not appear in a Windows path component.

 @return "true if c is reserved"
*>
macro bool is_reserved_win32_path_char(char c) => RESERVED_PATH_CHAR_WIN32[c];

<*
 Check if a character may not appear in a path component, for example ':' on Windows.

 @param c : "The character to test"
 @param path_env : "The path conventions to use"
 @return "true if c is reserved"
*>
macro bool is_reserved_path_char(char c, PathEnv path_env = DEFAULT_ENV)
{
	return path_env == PathEnv.WIN32
		? RESERVED_PATH_CHAR_WIN32[c]
		: RESERVED_PATH_CHAR_POSIX[c];
}


// --- Non public

fn bool? _mkdir(Path path, bool recursive = false, MkdirPermissions permissions = NORMAL) @private
{
	if (!path.len) return INVALID_PATH~;
	if (is_dir(path)) return false;
	if (exists(path)) return io::FILE_NOT_DIR~;

	if (recursive)
	{
		if (try parent = path.parent()) mkdir(parent, true, permissions)!;
	}
	if (!is_dir(path.parent()) ?? false) return io::CANNOT_READ_DIR~;

	return os::native_mkdir(path, permissions);
}

fn bool? _rmdir(Path path) @private
{
	if (!path) return INVALID_PATH~;
	return os::native_rmdir(path);
}

fn void? _ls_collect(Allocator allocator, PathList* result, Path base, Path rel_dir, bool no_dirs, bool no_symlinks, String mask, bool recursive, bool relative, Path rebase) @private
{
	$if $defined(os::native_ls):
		@pool()
		{
			Path scan_dir = rel_dir ? base.tappend(rel_dir)! : base;
			PathList entries = os::native_ls(scan_dir, false, no_symlinks, "", tmem)!;
			foreach (entry : entries)
			{
				Path rel = rel_dir ? rel_dir.tappend(entry)! : entry;
				Path full = scan_dir.tappend(entry)!;
				bool is_directory = is_dir(full);
				if (!(is_directory && no_dirs) && _path_match(rel, entry, mask))
				{
					Path item = relative ? rel : full;
					if (rebase) item = rebase.tappend(item)!;
					result.push(item.copy(allocator));
				}
				if (recursive && is_directory) _ls_collect(allocator, result, base, rel, no_dirs, no_symlinks, mask, recursive, relative, rebase)!;
			}
		};
	$else
		return io::UNSUPPORTED_OPERATION~;
	$endif
}

fn bool _path_match(Path rel, Path name, String mask) @private
{
	if (!mask) return true;
	if (try star = mask.index_of_char('*'))
	{
		String prefix = mask[:star];
		String suffix = mask[star + 1..];
		return rel.len >= prefix.len + suffix.len && rel.starts_with(prefix) && rel.ends_with(suffix)
			|| name.len >= prefix.len + suffix.len && name.starts_with(prefix) && name.ends_with(suffix);
	}
	return rel == mask || name == mask;
}

macro _append_path(self, Allocator allocator, String[] parts, String extension, PathEnv path_env) @local => @pool()
{
	sz capacity = self.len + parts.len;
	if (extension) capacity += 1 + extension.len;
	foreach (part : parts) if (part) capacity += part.len;
	@stack_mem(2048; smem)
	{
		DString dstr = dstring::new_with_capacity(smem, capacity);
		dstr.append(self);
		foreach (part : parts)
		{
			if (!part) continue;
			if (dstr.len() && !is_separator(dstr[^1], path_env)) dstr.append(path_env.separator);
			dstr.append(part);
		}
		if (extension)
		{
			if (extension[0] != '.') dstr.append('.');
			dstr.append(extension);
		}
		return ($Typeof(self))normalize(dstr.str_view(), path_env).copy(allocator);
	};

}

fn sz? start_of_base_name(String str, PathEnv path_env) @local
{
	if (!str.len) return 0;
	sz? start_slash = str.rindex_of_char('/');
	if (path_env != WIN32) return (start_slash + 1) ?? 0;
	if (try index = str.rindex_of_char('\\'))
	{
		if (try start_slash && start_slash > index) return start_slash + 1;
		// c:\ style path, we're done!
		if (str[0] != '\\') return index + 1;
		// Handle \\server\foo
		// Find the \ before "foo"
		sz last_index = 2 + str[2..].index_of_char('\\')!;
		// If they don't match, we're done
		if (last_index > index) return INVALID_PATH~;
		if (last_index != index) return index + 1;
		// Otherwise just default to the volume length.
	}
	if (path_env == WIN32) return volume_name_len_win(str)!!;
	return 0;
}

fn sz? volume_name_len_win(String path) @local
{
	sz len = path.len;
	if (len < 2) return 0;
	switch (path[0])
	{
		case '\\':
			// "\\" paths.. must be longer than 2
			if (len == 2) return 0;
			int count = 1;
			while (count < len && path[count] == '\\') count++;
			// Not 2 => folded paths
			if (count != 2) return 0;
			// Check that we have a name followed by '\'
			sz base_found = 0;
			for (sz i = 2; i < len; i++)
			{
				char c = path[i];
				if (is_win32_separator(c))
				{
					if (base_found) return i;
					base_found = i;
					continue;
				}
				if (is_reserved_win32_path_char(c)) return INVALID_PATH~;
			}
			if (base_found > 0 && base_found + 1 < len) return len;
			return INVALID_PATH~;
		case 'A'..'Z':
		case 'a'..'z':
			return path[1] == ':' ? 2 : 0;
		default:
			return 0;
	}
}

macro String _basename(self) @local
{
	sz basename_start = start_of_base_name(self, $Typeof(self)::typeid == PathPosix::typeid ? POSIX : WIN32)!!;
	if (basename_start == self.len) return "";
	return self[basename_start..];
}

macro bool _has_extension(self, String extension) @local
{
	String basename = self.basename();
	if (basename.len <= extension.len) return false;
	if (basename[^extension.len + 1] != '.') return false;
	return basename[^extension.len..] == extension;
}

macro String? _extension(self) @local
{
	String basename = self.basename();
	sz index = basename.rindex_of(".")!;
	// Plain ".foo" does not have an extension
	if (index == 0 || index == basename.len) return "";
	return basename[index + 1..];
}

macro _parent(self) @local
{
	PathEnv env = $Typeof(self)::typeid == PathPosix::typeid ? POSIX : WIN32;
	if (self.len == 1 && is_separator(self[0], env)) return NO_PARENT~;
	foreach_r(i, c : self)
	{
		if (is_separator(c, env))
		{
			if (i == 0) return self[..0];
			$if $Typeof(self)::typeid == PathWin::typeid:
				if (i > 1)
				{
					if (try volume_len = volume_name_len_win(self))
					{
						// Handle C:\foo
						if (volume_len == i)
						{
							if (i + 1 == self.len) return NO_PARENT~;
							return self[:i + 1];
						}
					}
				}
			$endif
			return self[:i];
		}
	}
	return NO_PARENT~;
}

fn String _root_directory(String path_str, PathEnv env) @local @inline
{
	sz len = path_str.len;
	if (!len) return "";
	if (path_str == ".") return ".";
	if (env == WIN32)
	{
		sz root_len = volume_name_len_win(path_str)!!;
		if (root_len == len || !is_win32_separator(path_str[root_len])) return "";
		return path_str[root_len..root_len];
	}
	if (!is_posix_separator(path_str[0])) return "";
	for (sz i = 1; i < len; i++)
	{
		if (is_posix_separator(path_str[i]))
		{
			return path_str[:i];
		}
	}
	return path_str;
}
