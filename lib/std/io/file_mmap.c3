module std::io::file::mmap @feat(POSIX, WIN32);
import std::core::mem::vm, std::io::file;

<* A memory mapped region of a file, created with `file::mmap_file` or `file::mmap_open`. *>
struct FileMmap
{
	File file;
	VirtualMemory vm;
	sz offset;
	sz len;
}

<*
 Provides a slice of bytes to the expected mapped range discarding the extra bytes due to misalignment of offset and/or size.

 @return "Slice of the mapped range where the first byte matches the file's byte at the offset passed to file::mmap_file()"
*>
fn char[] FileMmap.bytes(&self)
{
	return self.vm.ptr[self.offset:self.len];
}

<*
 Unmap the memory region and close the file if this FileMmap owns it (created by `file::mmap_open`).

 @return? io::FILE_NOT_VALID, io::INTERRUPTED, io::INCOMPLETE_WRITE, io::UNKNOWN_ERROR : "If closing the file failed"
 @return? vm::INVALID_ARGS, vm::UNMAPPED_ACCESS, vm::RELEASE_FAILED : "If unmapping failed"
*>
fn void? FileMmap.destroy(&self) @maydiscard
{
	fault err1 = @catch(self.file.close());
	fault err2 = @catch(self.vm.destroy());
	if (err1) return err1~;
	if (err2) return err2~;
}

module std::io::file @feat(POSIX, WIN32);

<*
 Map a region of an already opened file into memory; the file is not owned and must be closed by the caller.

 #### Example:
 ```
 file::save("data.txt", "Hello world")!!;
 File f = file::open("data.txt", "rb")!!;
 defer (void)f.close();
 FileMmap mm = file::mmap_file(f, 6)!!;
 defer mm.destroy();
 io::printn((String)mm.bytes()); // world
 ```

 @param file : "Already opened file created on the caller scope"
 @param offset : "Byte offset in file, the mapping itself starts at the page boundary below it"
 @param len : "Size in bytes to map starting from offset, 0 maps up to the end of the file"
 @param access : "The access permissions of the mapped memory"
 @param shared : "If true, writes go to the file; otherwise the mapping is private (copy-on-write)"
 @return "Memory mapped region. Must be released with FileMmap.destroy(). Provided File will not be closed"
 @return? mem::OUT_OF_MEMORY, vm::ACCESS_DENIED, vm::RANGE_OVERFLOW, vm::INVALID_ARGS, vm::UNKNOWN_ERROR, io::NO_PERMISSION, io::FILE_NOT_VALID, io::WOULD_BLOCK, io::FILE_NOT_FOUND
*>
fn FileMmap? mmap_file(File file, sz offset = 0, sz len = 0, VirtualMemoryAccess access = READ, bool shared = false)
{
	if (len == 0)
	{
		long new_len = file.size()! - offset;
		if (new_len > sz::max) return mem::OUT_OF_MEMORY~;
		len = (sz)new_len;
	}

	// get the page size
	sz page_size = vm::aligned_alloc_size(0);

	// align the offset specified by the user (might be not aligned)
	sz page_offset = offset & (page_size - 1);
	sz map_offset = offset - page_offset;
	
	// adjust map length (both the region start and the region end might be not aligned)
	sz map_len = len + page_offset; // when region start not aligned

	void* ptr = vm::mmap_file(file.fd(), map_len, map_offset, access, shared)!;

	// FileMmap does not own the supplied file
	return {{}, {ptr, map_len, access}, page_offset, len};
}

<*
 Open a file and map a region of it into memory; the file is closed when the FileMmap is destroyed.

 #### Example:
 ```
 file::save("data.txt", "Hello world")!!;
 FileMmap mm = file::mmap_open("data.txt", "rb")!!;
 defer mm.destroy();
 io::printn((String)mm.bytes()); // Hello world
 ```

 @param filename : "File path"
 @param mode : "File opening mode, as for `file::open`"
 @param offset : "Byte offset in file, the mapping itself starts at the page boundary below it"
 @param len : "Size in bytes to map starting from offset, 0 maps up to the end of the file"
 @param access : "The access permissions of the mapped memory"
 @param shared : "If true, writes go to the file; otherwise the mapping is private (copy-on-write)"
 @return "Memory mapped region. Must be released with FileMmap.destroy()"
 @return? io::FILE_NOT_FOUND, io::NO_PERMISSION : "If the file could not be opened"
 @return? mem::OUT_OF_MEMORY, vm::ACCESS_DENIED, vm::RANGE_OVERFLOW, vm::INVALID_ARGS, vm::UNKNOWN_ERROR, io::FILE_NOT_VALID, io::WOULD_BLOCK
*>
fn FileMmap? mmap_open(String filename, String mode, sz offset = 0, sz len = 0, VirtualMemoryAccess access = READ, bool shared = false)
{
	File file = open(filename, mode)!;
	defer catch (void)file.close();
	FileMmap mm = mmap_file(file, offset, len, access, shared)!;

	// FileMmap owns the file and it will close it on destroy()
	mm.file = file;

	return mm;
}

