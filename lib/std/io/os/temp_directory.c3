module std::io::os;

<* Well-known per-user directories that can be looked up with `native_user_directory`. *>
enum NativeSystemDir
{
	DESKTOP,
	DOCUMENTS,
	VIDEOS,
	MUSIC,
	DOWNLOADS,
	PICTURES,
	TEMPLATES,
	PUBLIC_SHARE,
	SAVED_GAMES,
	SCREENSHOTS
}

module std::io::os @feat(LIBC);
import std::io, std::os;

fn String? win32_get_known_folder_temp(Win32_REFKNOWNFOLDERID rfid) @private @feat(WIN32)
{
	Win32_PWSTR path;
	Win32_HRESULT res = win32::shGetKnownFolderPath(rfid, 0x00008000 /* KF_FLAG_CREATE */, null, &path);
	if (res) return io::PATH_COULD_NOT_BE_FOUND~;
	return string::from_wstring(tmem, (WString)path);
}

<*
 Return the home directory of the current user.
 Usually called through `path::home_directory`.

 Uses `$HOME` on Darwin, Linux, the BSDs and Haiku, and the profile known
 folder on Windows.

 @param allocator : "The allocator for the returned path"
 @return "The home directory"
 @return? io::PATH_COULD_NOT_BE_FOUND : "If it can't be determined, or the platform is unsupported"
*>
fn Path? native_home_directory(Allocator allocator) => @pool()
{
	$switch env::OS_TYPE:
		$case IOS:
		$case MACOS:
		$case TVOS:
		$case WATCHOS:
        $case FREEBSD:
        $case KFREEBSD:
		$case LINUX:
        $case NETBSD:
		$case OPENBSD:
		$case HAIKU:
			return path::new(allocator, env::tget_var("HOME")) ?? io::PATH_COULD_NOT_BE_FOUND~;
		$case WIN32:
			return path::new(allocator, win32_get_known_folder_temp(&win32::FOLDERID_PROFILE));
		$default:
			return io::PATH_COULD_NOT_BE_FOUND~;
	$endswitch
}

<*
 Return a well-known directory of the current user, such as Desktop or Downloads.
 Usually called through the `path::*_directory` functions, for example `path::downloads_directory`.

 Linux, the BSDs and Haiku use the XDG user directories, Darwin uses the
 system search paths and Windows uses known folders (created if missing).
 Not every directory exists everywhere: SAVED_GAMES and SCREENSHOTS are
 Windows-only, TEMPLATES is unavailable on Darwin and PUBLIC_SHARE is
 unavailable on Windows.

 @param allocator : "The allocator for the returned path"
 @param dir : "The directory to look up"
 @return "The requested directory"
 @return? io::PATH_COULD_NOT_BE_FOUND : "If the directory is not available on this platform or can't be found"
*>
fn Path? native_user_directory(Allocator allocator, NativeSystemDir dir) => @pool()
{
	$switch env::OS_TYPE:
        $case FREEBSD:
        $case KFREEBSD:
		$case LINUX:
        $case NETBSD:
		$case OPENBSD:
		$case HAIKU:
			switch (dir)
			{
				case DESKTOP: return path::new(allocator, posix::xdg_user_dir_lookup(tmem, "DESKTOP"));
				case DOWNLOADS: return path::new(allocator, posix::xdg_user_dir_lookup(tmem, "DOWNLOAD"));
				case DOCUMENTS: return path::new(allocator, posix::xdg_user_dir_lookup(tmem, "DOCUMENTS"));
				case MUSIC: return path::new(allocator, posix::xdg_user_dir_lookup(tmem, "MUSIC"));
				case VIDEOS: return path::new(allocator, posix::xdg_user_dir_lookup(tmem, "VIDEOS"));
				case PICTURES: return path::new(allocator, posix::xdg_user_dir_lookup(tmem, "PICTURES"));
				case PUBLIC_SHARE: return path::new(allocator, posix::xdg_user_dir_lookup(tmem, "PUBLICSHARE"));
				case TEMPLATES: return path::new(allocator, posix::xdg_user_dir_lookup(tmem, "TEMPLATES"));
				case SAVED_GAMES:
				case SCREENSHOTS: nextcase;
				default: return io::PATH_COULD_NOT_BE_FOUND~;
			}
		$case IOS:
		$case MACOS:
		$case WATCHOS:
		$case TVOS:
			switch (dir)
			{
				case DESKTOP: return path::new(allocator, darwin::find_first_directory_temp(DESKTOP, USER));
				case DOWNLOADS: return path::new(allocator, darwin::find_first_directory_temp(DOWNLOADS, USER));
				case DOCUMENTS: return path::new(allocator, darwin::find_first_directory_temp(DOCUMENT, USER));
				case MUSIC: return path::new(allocator, darwin::find_first_directory_temp(MUSIC, USER));
				case VIDEOS: return path::new(allocator, darwin::find_first_directory_temp(MOVIES, USER));
				case PICTURES: return path::new(allocator, darwin::find_first_directory_temp(PICTURES, USER));
				case PUBLIC_SHARE: return path::new(allocator, darwin::find_first_directory_temp(SHARED_PUBLIC, USER));
				case SAVED_GAMES:
				case SCREENSHOTS:
				case TEMPLATES: nextcase;
				default: return io::PATH_COULD_NOT_BE_FOUND~;
			}
		$case WIN32:
			switch (dir)
			{
				case DOWNLOADS: return path::new(allocator, win32_get_known_folder_temp(&win32::FOLDERID_DOWNLOADS));
				case DOCUMENTS: return path::new(allocator, win32_get_known_folder_temp(&win32::FOLDERID_DOCUMENTS));
				case DESKTOP: return path::new(allocator, win32_get_known_folder_temp(&win32::FOLDERID_DESKTOP));
				case MUSIC: return path::new(allocator, win32_get_known_folder_temp(&win32::FOLDERID_MUSIC));
				case VIDEOS: return path::new(allocator, win32_get_known_folder_temp(&win32::FOLDERID_VIDEOS));
				case PICTURES: return path::new(allocator, win32_get_known_folder_temp(&win32::FOLDERID_PICTURES));
				case SAVED_GAMES: return path::new(allocator, win32_get_known_folder_temp(&win32::FOLDERID_SAVED_GAMES));
				case SCREENSHOTS: return path::new(allocator, win32_get_known_folder_temp(&win32::FOLDERID_SCREENSHOTS));
				case TEMPLATES: return path::new(allocator, win32_get_known_folder_temp(&win32::FOLDERID_TEMPLATES));
				case PUBLIC_SHARE: nextcase;
				default: return io::PATH_COULD_NOT_BE_FOUND~;
			}
		$default:
			return io::PATH_COULD_NOT_BE_FOUND~;
	$endswitch
}


<*
 Return the directory for temporary files.
 Usually called through `path::temp_directory`.

 On Windows this is the result of GetTempPathW. Elsewhere the first non-empty
 of the `TMPDIR`, `TMP`, `TEMP` and `TEMPDIR` environment variables is used,
 falling back to "/tmp". The directory is not checked for existence.

 @param allocator : "The allocator for the returned path"
 @return "The temporary directory"
 @return? io::GENERAL_ERROR : "On Windows, if the OS call fails"
*>
fn Path? native_temp_directory(Allocator allocator) @feat(!WIN32)
{
	foreach (String env : { "TMPDIR", "TMP", "TEMP", "TEMPDIR" })
	{
		String tmpdir = env::tget_var(env) ?? "";
		if (tmpdir) return path::new(allocator, tmpdir);
	}
	return path::new(allocator, "/tmp");
}

<*
 Return the directory for temporary files.
 Usually called through `path::temp_directory`.

 On Windows this is the result of GetTempPathW. Elsewhere the first non-empty
 of the `TMPDIR`, `TMP`, `TEMP` and `TEMPDIR` environment variables is used,
 falling back to "/tmp". The directory is not checked for existence.

 @param allocator : "The allocator for the returned path"
 @return "The temporary directory"
 @return? io::GENERAL_ERROR : "On Windows, if the OS call fails"
*>
fn Path? native_temp_directory(Allocator allocator) @feat(WIN32) => @pool()
{
	Win32_DWORD len = win32::getTempPathW(0, null);
	if (!len) return io::GENERAL_ERROR~;
	Char16[] buff = mem::talloc_array(Char16, len);
	Win32_DWORD res = win32::getTempPathW(len, buff);
	if (!res) return io::GENERAL_ERROR~;
	return path::new(allocator, string::tfrom_utf16(buff[:res]));
}

module std::io::os @feat(NO_LIBC);
import std::io::path;

<* Without libc the home directory is unknown: always returns PATH_COULD_NOT_BE_FOUND. *>
macro Path? native_home_directory(Allocator allocator) => io::PATH_COULD_NOT_BE_FOUND~;
<* Without libc the temporary directory is unknown: always returns PATH_COULD_NOT_BE_FOUND. *>
macro Path? native_temp_directory(Allocator allocator) => io::PATH_COULD_NOT_BE_FOUND~;
<* Without libc user directories are unknown: always returns PATH_COULD_NOT_BE_FOUND. *>
fn Path? native_user_directory(Allocator allocator, NativeSystemDir dir) => io::PATH_COULD_NOT_BE_FOUND~;
