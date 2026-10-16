module std::io::os @feat(POSIX);
import std::io, std::os;

<*
 List the entries of a single directory, excluding "." and "..".
 Usually called through `path::ls`, which adds masking, recursion and rebasing.

 The returned paths are entry names relative to `dir`. The `mask` argument is
 currently ignored. On POSIX an empty `dir` lists the current directory, and
 the `no_dirs` / `no_symlinks` filters rely on the file system reporting the
 entry type.

 @param dir : "The directory to list"
 @param no_dirs : "Exclude directories from the result"
 @param no_symlinks : "Exclude symbolic links (on Windows: all reparse points) from the result"
 @param mask : "Unused"
 @param allocator : "The allocator for the list and its paths"
 @return "The list of entry names"
 @return? io::CANNOT_READ_DIR : "If the directory can't be opened"
 @return? io::FILE_NOT_DIR : "On POSIX, if `dir` is not a directory or does not exist"
*>
fn PathList? native_ls(Path dir, bool no_dirs, bool no_symlinks, String mask, Allocator allocator)
{
	PathList list;
	list.init(allocator);
	DIRPtr directory @noinit;
	@pool()
	{
		directory = posix::opendir(dir ? dir.zstr_tcopy() : (ZString)".");
	};
	defer if (directory) posix::closedir(directory);
	if (!directory) return (path::is_dir(dir) ? io::CANNOT_READ_DIR : io::FILE_NOT_DIR)~;
	Posix_dirent* entry;
	while ((entry = posix::readdir(directory)))
	{
		String name = ((ZString)&entry.name).str_view();
		if (!name || name == "." || name == "..") continue;
		if (entry.d_type == posix::DT_LNK && no_symlinks) continue;
		if (entry.d_type == posix::DT_DIR && no_dirs) continue;
		Path path = path::new(allocator, name)!!;
		list.push(path);
	}
	return list;
}

module std::io::os @feat(WIN32);
import std::time, std::os, std::io;

<*
 List the entries of a single directory, excluding "." and "..".
 Usually called through `path::ls`, which adds masking, recursion and rebasing.

 The returned paths are entry names relative to `dir`. The `mask` argument is
 currently ignored. On POSIX an empty `dir` lists the current directory, and
 the `no_dirs` / `no_symlinks` filters rely on the file system reporting the
 entry type.

 @param dir : "The directory to list"
 @param no_dirs : "Exclude directories from the result"
 @param no_symlinks : "Exclude symbolic links (on Windows: all reparse points) from the result"
 @param mask : "Unused"
 @param allocator : "The allocator for the list and its paths"
 @return "The list of entry names"
 @return? io::CANNOT_READ_DIR : "If the directory can't be opened"
 @return? io::FILE_NOT_DIR : "On POSIX, if `dir` is not a directory or does not exist"
*>
fn PathList? native_ls(Path dir, bool no_dirs, bool no_symlinks, String mask, Allocator allocator)
{
	PathList list;
	list.init(allocator);

	@pool()
	{
		WString result = dir.tconcat(`\*`).to_temp_wstring()!!;
		Win32_WIN32_FIND_DATAW find_data;
		Win32_HANDLE find = win32::findFirstFileW(result, &find_data);
		if (find == win32::INVALID_HANDLE_VALUE) return io::CANNOT_READ_DIR~;
		defer win32::findClose(find);
		do
		{
			if (no_dirs && find_data.dwFileAttributes & win32::FILE_ATTRIBUTE_DIRECTORY) continue;
			if (no_symlinks && find_data.dwFileAttributes & win32::FILE_ATTRIBUTE_REPARSE_POINT) continue;
			@pool()
			{
				String filename = string::tfrom_wstring((WString)&find_data.cFileName)!;
				if (filename == ".." || filename == ".") continue;
				list.push(path::new(allocator, filename)!);
			};
		} while (win32::findNextFileW(find, &find_data));
		return list;
	};
}
