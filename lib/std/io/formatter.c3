module std::io;
import std::collections::map;
import libc;

// It is vitally important that the formatter doesn't do any allocations,
// or it ceases to be useful in constrained environments.

<* The size of the stack buffer used when formatting a single integer. *>
const int PRINTF_NTOA_BUFFER_SIZE = 256;

<*
 Implement this interface to customize how a type is printed with `%s` and the print functions.

 #### Example:
 ```
 struct Celsius (Printable)
 {
 	double degrees;
 }

 fn sz? Celsius.to_format(&self, Formatter* f) @dynamic
 {
 	return f.printf("%.1f C", self.degrees);
 }

 fn void main()
 {
 	Celsius c = { 21.5 };
 	io::printfn("%s", c); // 21.5 C
 }
 ```
*>
interface Printable
{
	<*
	 Return a fixed string representing the value, used if `to_format` is not implemented.

	 @return "The string to print"
	*>
	fn String to_constant_string() @optional;
	<*
	 Print the value to the formatter.

	 @param [inout] formatter : "The formatter to print to"
	 @return "The number of characters printed"
	*>
	fn sz? to_format(Formatter* formatter) @optional;
}

excuse
{
	<* The output buffer is too small, e.g. in `bprintf`. *>
	BUFFER_EXCEEDED,
	<* A number was too large for the formatter's internal buffer. *>
	INTERNAL_BUFFER_EXCEEDED,
	<* The format string is malformed or contains an unknown specifier. *>
	INVALID_FORMAT,
	<* The format string has more specifiers than there are arguments. *>
	NOT_ENOUGH_ARGUMENTS,
	<* An argument could not be printed with the given specifier. *>
	INVALID_ARGUMENT
}

<* A function that receives each character a `Formatter` outputs, along with the formatter's user data. *>
alias OutputFn = fn void?(void* buffer, char c);
<* The float type used internally for formatting floating point values. *>
alias FloatType = double;


<*
 Check if a type is a struct or bitstruct with neither `to_format` nor `to_constant_string`,
 meaning the print functions will print it member by member.

 @param $Type : "The type to check"
 @return "True if the type uses the default struct printing"
*>
macro bool is_struct_with_default_print($Type)
{
	return ($Type::kind == STRUCT ||| $Type::kind == BITSTRUCT)
		&&& !$defined($Type.to_format)
		&&& !$defined($Type.to_constant_string);
}

<*
 Introspect a struct and print it to a formatter member by member, e.g. `{ x: 1, name: abc }`.

 Members that are themselves structs without custom printing are printed recursively.

 @param value : "The struct or bitstruct to print"
 @param [inout] f : "The formatter to print to"
 @param $force_dump : "If true, print all nested structs member by member, even if they implement Printable"
 @return "The number of characters printed"
 @require @kindof(value) == STRUCT || @kindof(value) == BITSTRUCT : `This macro is only valid on structs and bitstructs`
*>
macro sz? struct_to_format(value, Formatter* f, bool $force_dump)
{
	var $Type = $Typeof(value);
	sz total = f.print("{ ")!;
	$foreach $i, $member : $Type::members:
		$if $i > 0:
			total += f.print(", ")!;
		$endif
		$if $member.name != "":
			total += f.printf("%s: ", $member.name)!;
		$endif
		$if ($force_dump &&& ($member.type.kind == STRUCT || $member.type.kind == BITSTRUCT)) ||| is_struct_with_default_print($member.type):
			total += struct_to_format(value.$member, f, $force_dump)!;
		$else
			total += f.printf("%s", value.$member)!;
		$endif
	$endforeach
	return total + f.print(" }");
}

<*
 Print to the formatter using a 'printf'-style format string. See `io::printf` for details on formatting.

 @param format : "The printf-style format string"
 @param args : "The values to format"
 @return "The number of characters printed"
 @return? INVALID_FORMAT, NOT_ENOUGH_ARGUMENTS, INVALID_ARGUMENT, INTERNAL_BUFFER_EXCEEDED : "If the format string and arguments don't match, or a fault from the output function"
*>
fn sz? Formatter.printf(&self, String format, args...)
{
	return self.vprintf(format, args) @inline;
}

<*
 Formats values and sends each resulting character to an output function, without allocating.

 The anonymous inner struct holds the formatting state: flags, width and precision of the current
 specifier, and the first fault recorded during the call.

 #### Example:
 ```
 fn void? count_fn(void* data, char c)
 {
 	(*(int*)data)++;
 }

 fn void main()
 {
 	int count;
 	Formatter f;
 	f.init(&count_fn, &count);
 	f.printf("%d-%s", 123, "abc")!!;
 	io::printn(count); // 7
 }
 ```
*>
struct Formatter
{
	void *data;
	OutputFn out_fn;
	struct
	{
		PrintFlags flags;
		int width;
		int prec;
		fault first_fault;
	}
}

<* The flags parsed from the current format specifier, such as `-`, `0`, `+`, space and `#`. *>
bitstruct PrintFlags : uint
{
	bool zeropad;
	bool left;
	bool plus;
	bool space;
	bool hash;
	bool uppercase;
	bool precision;
}

<*
 Initialize the formatter with an output function and the user data passed to it.

 @param out_fn : "The function called for each character output"
 @param data : "User data passed to `out_fn`, may be null"
*>
fn void Formatter.init(&self, OutputFn out_fn, void* data = null)
{
	*self = { .data = data, .out_fn = out_fn};
}



<*
 Print a value using its `to_format` or, failing that, its `to_constant_string` method.

 The formatter's flags, width and precision are restored afterwards. A null value prints "(null)".

 @param arg : "The value to print"
 @return "The number of characters printed"
 @return? NOT_FOUND : "If the value implements neither method"
*>
fn sz? Formatter.print_with_function(&self, Printable arg)
{
	if (&arg.to_format)
	{
		PrintFlags old = self.flags;
		int old_width = self.width;
		int old_prec = self.prec;
		defer
		{
			self.flags = old;
			self.width = old_width;
			self.prec = old_prec;
		}
		if (!arg) return formatter_out_substr(self, "(null)");
		return arg.to_format(self);
	}
	if (&arg.to_constant_string)
	{
		PrintFlags old = self.flags;
		int old_width = self.width;
		int old_prec = self.prec;
		defer
		{
			self.flags = old;
			self.width = old_width;
			self.prec = old_prec;
		}
		if (!arg) return formatter_out_substr(self, "(null)");
		return formatter_out_substr(self, arg.to_constant_string());
	}
	return NOT_FOUND~;
}


fn void? out_null_fn(void* data @unused, char c @unused) @private
{
}

<*
 Print an error marker to the formatter and return INVALID_FORMAT.

 @param [inout] f : "The formatter to print to"
 @param $fault : `The marker text to print, e.g. "%ERR"`
 @return? INVALID_FORMAT : "Always"
*>
macro sz? @report_fault(Formatter* f, $fault)
{
	(void)formatter_out_substr(f, $fault);
	return INVALID_FORMAT~;
}

<*
 Evaluate a formatting action, printing "<INVALID>" and recording INVALID_ARGUMENT if it fails.

 Buffer faults are recorded and returned as-is.

 @param [inout] f : "The formatter being printed to"
 @param #action : "The expression that prints the value"
 @return "The number of characters printed by the action"
 @return? BUFFER_EXCEEDED, INTERNAL_BUFFER_EXCEEDED, INVALID_ARGUMENT : "The first fault recorded by the formatter"
*>
macro sz? @wrap_bad(Formatter* f, #action)
{
	sz? len = #action;
	if (catch err = len)
	{
		switch (err)
		{
			case BUFFER_EXCEEDED:
			case INTERNAL_BUFFER_EXCEEDED:
				return f.first_err(err)~;
			default:
				err = f.first_err(INVALID_ARGUMENT);
				formatter_out_substr(f, "<INVALID>")!;
				return err~;
		}
	}
	return len;
}



<*
 Print to the formatter using a 'printf'-style format string and a slice of arguments.
 See `io::printf` for details on formatting.

 A missing argument prints `<MISSING>` and an unknown specifier prints `<BAD FORMAT>`; formatting
 then continues and the first fault is returned at the end. An argument that can't be printed
 (`<INVALID>`) or a malformed `*` width or precision stops formatting immediately.
 If no output function is set, output is discarded.

 #### Example:
 ```
 fn void? stdout_fn(void* data @unused, char c)
 {
 	io::putchar(c);
 }

 fn void main()
 {
 	Formatter f;
 	f.init(&stdout_fn);
 	any[] args = { &&1, &&"one" };
 	f.vprintf("%d is %s\n", args)!!; // 1 is one
 }
 ```

 @param format : "The printf-style format string"
 @param anys : "The values to format"
 @return "The number of characters printed"
 @return? INVALID_FORMAT, NOT_ENOUGH_ARGUMENTS, INVALID_ARGUMENT, INTERNAL_BUFFER_EXCEEDED : "If the format string and arguments don't match, or a fault from the output function"
*>
fn sz? Formatter.vprintf(&self, String format, any[] anys)
{
	self.first_fault = {};
	if (!self.out_fn)
	{
		// use null output function
		self.out_fn = &out_null_fn;
	}
	sz total_len;
	sz format_len = format.len;
	sz variant_index = 0;
	for (sz i = 0; i < format_len; i++)
	{
		// format specifier?  %[flags][width][.precision][length]
		char c = format[i];
		if (c != '%')
		{
			// no
			total_len += self.print_char(c)!;
			continue;
		}
		i++;
		if (i >= format_len) return @report_fault(self, "%ERR");
		c = format[i];
		if (c == '%')
		{
			total_len += self.print_char(c)!;
			continue;
		}
		// evaluate flags
		self.flags = {};
		while FLAG_EVAL: (true)
		{
			switch (c)
			{
				case '0': self.flags.zeropad = true;
				case '-': self.flags.left = true;
				case '+': self.flags.plus = true;
				case ' ': self.flags.space = true;
				case '#': self.flags.hash = true;
				default: break FLAG_EVAL;
			}
			if (++i >= format_len) return @report_fault(self, "%ERR");
			c = format[i];
		}
		// evaluate width field
		int? w = printf_parse_format_field(anys.ptr, anys.len, &variant_index, format.ptr, format.len, &i);
		if (catch w) return @report_fault(self, "%ERR");
		c = format[i];
		if (w < 0)
		{
			self.flags.left = true;
			w = -w;
		}
		self.width = w;
		// evaluate precision field
		self.prec = 0;
		if (c == '.')
		{
			self.flags.precision = true;
			if (++i >= format_len) return @report_fault(self, "<BAD FORMAT>");
			int? prec = printf_parse_format_field(anys.ptr, anys.len, &variant_index, format.ptr, format.len, &i);
			if (catch prec) return @report_fault(self, "<BAD FORMAT>");
			self.prec = prec < 0 ? 0 : prec;
			c = format[i];
		}

		// evaluate specifier
		uint base = 0;
		if (variant_index >= anys.len)
		{
			self.first_err(NOT_ENOUGH_ARGUMENTS);
			total_len += formatter_out_substr(self, "<MISSING>")!;
			continue;
		}
		any current = anys[variant_index++];
		switch (c)
		{
			case 'd':
				base = 10;
				self.flags.hash = false;
			case 'X' :
				self.flags.uppercase = true;
				nextcase;
			case 'x' :
				base = 16;
			case 'O':
				self.flags.uppercase = true;
				nextcase;
			case 'o' :
				base = 8;
			case 'B':
				self.flags.uppercase = true;
				nextcase;
			case 'b' :
				base = 2;
			case 'A':
				self.flags.uppercase = true;
				nextcase;
			case 'a':
				total_len += @wrap_bad(self, formatter_atoa(self, float_from_any(current)))!;
				continue;
			case 'F' :
				self.flags.uppercase = true;
				nextcase;
			case 'f':
				total_len += @wrap_bad(self, formatter_ftoa(self, float_from_any(current)))!;
				continue;
			case 'E':
				self.flags.uppercase = true;
				nextcase;
			case 'e':
				total_len += @wrap_bad(self, formatter_etoa(self, float_from_any(current)))!;
				continue;
			case 'G':
				self.flags.uppercase = true;
				nextcase;
			case 'g':
				total_len += @wrap_bad(self, formatter_gtoa(self, float_from_any(current)))!;
				continue;
			case 'c':
				total_len += formatter_out_char(self, current)!;
				continue;
			case 'H':
				self.flags.uppercase = true;
				nextcase;
			case 'h':
				total_len += formatter_out_hex_buffer(self, current)!;
				continue;
			case 's':
				total_len += formatter_out_str_pad(self, current)!;
				continue;
			case 'p':
				self.flags.zeropad = true;
				self.flags.hash = true;
				base = 16;
			default:
				self.first_err(INVALID_FORMAT);
				total_len += formatter_out_substr(self, "<BAD FORMAT>")!;
				continue;
		}
		if (base != 10)
		{
			self.flags.plus = false;
			self.flags.space = false;
		}
		// ignore '0' flag when precision is given
		if (self.flags.precision) self.flags.zeropad = false;

		bool is_neg;
		total_len += @wrap_bad(self, formatter_ntoa(self, int_from_any(current, &is_neg), is_neg, base))!;
	}

	if (self.first_fault) return self.first_fault~;
	return total_len;
}

<*
 Send a single character to the output function.

 If the output function fails, the first fault recorded by the formatter is returned.

 @param c : "The character to print"
 @return "Always 1"
*>
fn sz? Formatter.print_char(&self, char c)
{
	if (catch err = self.out_fn(self.data, c))
	{
		if (self.first_fault) return self.first_fault~;
		self.first_fault = err;
		return err~;
	}
	return 1;
}

<*
 Print a string as-is, without any formatting. If no output function is set, output is discarded.

 @param str : "The string to print"
 @return "The number of bytes printed"
*>
fn sz? Formatter.print(&self, String str)
{
	if (!self.out_fn)
	{
		// use null output function
		self.out_fn = &out_null_fn;
	}
	foreach (c : str) self.print_char(c)!;
	return str.len;
}
