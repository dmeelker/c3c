module std::io;

<*
 Reads values bit by bit from an InStream, most significant bit first.

 #### Example:
 ```
 ByteReader r;
 r.init({ 0b10111000 });
 BitReader br;
 br.init(&r);
 io::printfn("%b", br.read_bits(3)!!); // 101
 io::printfn("%b", br.read_bits(2)!!); // 11
 ```
*>
struct BitReader
{
	InStream reader;
	uint bits;
	int len;
}

<*
 Initialize the reader to read from the given stream, discarding any buffered bits.

 @param byte_reader : "The stream to read bytes from"
*>
fn void BitReader.init(&self, InStream byte_reader)
{
	*self = { .reader = byte_reader };
}

<*
 Discard any buffered bits, so the next read starts at a new byte.
*>
fn void BitReader.clear(&self) @inline
{
	self.len = 0;
}

<*
 Read the next `nbits` bits, reading a new byte from the stream if needed.

 @param nbits : "The number of bits to read, 1 to 8"
 @return "The bits read, in the lowest bits of the result"
 @return? EOF : "If a new byte is needed but the stream has ended, or any other stream fault"
 @require nbits <= 8 && nbits > 0
 @require self.len + (sz)nbits <= uint::size * 8
*>
fn char? BitReader.read_bits(&self, int nbits)
{
	uint bits = self.bits;
	if (self.len < nbits)
	{
		// New bits are pushed right.
		char c = self.reader.read_byte()!;
		bits <<= 8;
		bits |= c;
		self.bits = bits;
		self.len += 8;
	}
	self.len -= nbits;
	uint mask = (1u << nbits) - 1u;
	return (char)((bits >> self.len) & mask);
}

<*
 Writes values bit by bit to an OutStream, most significant bit first.

 Call `flush` when done to write any remaining bits.

 #### Example:
 ```
 ByteWriter w;
 w.tinit();
 BitWriter bw;
 bw.init(&w);
 bw.write_bits(0b101, 3)!!;
 bw.write_bits(0b11, 2)!!;
 bw.flush()!!; // pads with zero bits to a whole byte
 io::printfn("%08b", w.str_view()[0]); // 10111000
 ```
*>
struct BitWriter
{
	OutStream writer;
	uint bits;
	int len;
}

// c3 doesn't allow to shift more than bit width of a variable,
// so use closest byte boundary of 24 instead of 32
<* The maximum number of bits a `BitWriter` buffers before writing them out. *>
const int WRITER_BITS = 24;

<*
 Initialize the writer to write to the given stream, discarding any buffered bits.

 @param byte_writer : "The stream to write bytes to"
*>
fn void BitWriter.init(&self, OutStream byte_writer)
{
	*self = { .writer = byte_writer };
}

<*
 Write any buffered bits to the stream, padding the last byte with zero bits.

 Any fault from the stream is returned.
*>
fn void? BitWriter.flush(&self)
{
	if (!self.len) return;

	int padding = (@sizeof(self.bits) * 8 - self.len);
	uint bits = self.bits << padding;
	sz n = ((sz)self.len + 7) / 8;
	char[4] buffer;
	bitorder::write(bits, &buffer, UIntBE);
	io::write_all(self.writer, buffer[:n])!;
	self.len = 0;
}

<*
 Write the lowest `nbits` bits of `bits`, writing full bytes to the stream as the buffer fills.

 Any fault from the stream is returned.

 @param bits : "The value whose lowest bits are written"
 @param nbits : "The number of bits to write, 0 to 32"
 @require nbits <= 32 && nbits >= 0
*>
fn void? BitWriter.write_bits(&self, uint bits, int nbits)
{
	if (!nbits) return;
	while (self.len + nbits > WRITER_BITS)
	{
		int to_push = WRITER_BITS - self.len;
		uint bits_to_push = (bits >> (nbits - to_push)) & ((1u << to_push) - 1u);

		self.bits <<= to_push;
		self.bits |= bits_to_push;
		self.len += to_push;
		nbits -= to_push;

		self.flush()!;
	}

	if (!nbits) return;

	self.bits <<= nbits;
	self.bits |= bits & ((1u << nbits) - 1u);
	self.len += nbits;
}
