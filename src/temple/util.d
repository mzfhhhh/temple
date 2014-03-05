/**
 * Temple (C) Dylan Knutson, 2013, distributed under the:
 * Boost Software License - Version 1.0 - August 17th, 2003
 *
 * Permission is hereby granted, free of charge, to any person or organization
 * obtaining a copy of the software and accompanying documentation covered by
 * this license (the "Software") to use, reproduce, display, distribute,
 * execute, and transmit the Software, and to prepare derivative works of the
 * Software, and to permit third-parties to whom the Software is furnished to
 * do so, all subject to the following:
 *
 * The copyright notices in the Software and this entire statement, including
 * the above license grant, this restriction and the following disclaimer,
 * must be included in all copies of the Software, in whole or in part, and
 * all derivative works of the Software, unless such copies or derivative
 * works are solely in the form of machine-executable object code generated by
 * a source language processor.
 */

module temple.util;

private import
  std.algorithm,
  std.typecons,
  std.array,
  std.uni;

private import temple.delims;

package:

bool validBeforeShort(string str) {
	// Check that the tail of str is whitespace
	// before a newline, or nothing.
	foreach_reverse(dchar chr; str) {
		if(chr == '\n') { return true; }
		if(!chr.isWhite()) { return false; }
	}
	return true;
}

unittest
{
	static assert("   ".validBeforeShort() == true);
	static assert(" \t".validBeforeShort() == true);
	static assert("foo\n".validBeforeShort() == true);
	static assert("foo\n  ".validBeforeShort() == true);
	static assert("foo\n  \t".validBeforeShort() == true);

	static assert("foo  \t".validBeforeShort() == false);
	static assert("foo".validBeforeShort() == false);
	static assert("\nfoo".validBeforeShort() == false);
}

void munchHeadOf(ref string a, ref string b, size_t amt) {
	// Transfers amt of b's head onto a's tail
	a = a ~ b[0..amt];
	b = b[amt..$];
}

unittest
{
	auto a = "123";
	auto b = "abc";
	a.munchHeadOf(b, 1);
	assert(a == "123a");
	assert(b == "bc");
}
unittest
{
	auto a = "123";
	auto b = "abc";
	a.munchHeadOf(b, b.length);
	assert(a == "123abc");
	assert(b == "");
}

/// Returns the next matching delimeter in 'delims' found in the haystack,
/// or null
DelimPos!(D)* nextDelim(D)(string haystack, const(D)[] delims)
if(is(D : Delim))
{

	alias Tuple!(Delim, "delim", string, "str") DelimStrPair;

	/// The foreach is there to get around some DMD bugs
	/// Preferrably, one of the next two lines would be used instead
	//auto delims_strs =      delims.map!(a => new DelimStrPair(a, a.toString()) )().array();
	//auto delim_strs  = delims_strs.map!(a => a.str)().array();
	DelimStrPair[] delims_strs;
	foreach(delim; delims)
	{
		delims_strs ~= DelimStrPair(delim, toString(delim));
	}

	// Map delims into their string representations
	// e.g. OpenDelim.OpenStr => `<%=`
	string[] delim_strs;
	foreach(delim; delims)
	{
		// Would use ~= here, but CTFE in 2.063 can't handle it
		delim_strs = delim_strs ~ toString(delim);
	}

	// Find the first occurance of any of the delimers in the haystack
	immutable atPos = countUntilAny(haystack, delim_strs);
	if(atPos == -1)
	{
		return null;
	}

	// Jump to where the delim is on haystack
	haystack = haystack[atPos .. $];

	// Make sure that we match the longest of the delimers first,
	// e.g. `<%=` is matched before `<%`
	// Think of this as laxy lexing for maximal munch.
	auto sorted = delims_strs.sort!("a.str.length > b.str.length")();
	foreach(s; sorted)
	{
		if(startsWith(haystack, s.str))
		{
			return new DelimPos!D(atPos, cast(D) s.delim);
		}
	}

	// invariant
	assert(false, "Internal bug");
}

unittest
{
	const haystack = Delim.Open.toString();
	static assert(*(haystack.nextDelim([Delim.Open])) == DelimPos!Delim(0, Delim.Open));
}
unittest
{
	const haystack = "foo";
	static assert(haystack.nextDelim([Delim.Open]) is null);
}

/// Returns the location of the first occurance of any of 'subs' found in
/// haystack, or -1 if none are found
ptrdiff_t countUntilAny(string haystack, string[] subs) {
	// First, calculate first occurance for all subs
	auto indexes_of = subs.map!( sub => haystack.countUntil(sub) );
	ptrdiff_t min_index = -1;

	// Then find smallest index that isn't -1
	foreach(index_of; indexes_of)
	{
		if(index_of != -1)
		{
			if(min_index == -1)
			{
				min_index = index_of;
			}
			else
			{
				min_index = min(min_index, index_of);
			}
		}
	}

	return min_index;
}
unittest
{
	enum a = "1, 2, 3, 4";
	static assert(a.countUntilAny(["1", "2"]) == 0);
	static assert(a.countUntilAny(["2", "1"]) == 0);
	static assert(a.countUntilAny(["4", "2"]) == 3);
}
unittest
{
	enum a = "1, 2, 3, 4";
	static assert(a.countUntilAny(["5", "1"]) == 0);
	static assert(a.countUntilAny(["5", "6"]) == -1);
}
unittest
{
	enum a = "%>";
	static assert(a.countUntilAny(["<%", "<%="]) == -1);
}

string escapeQuotes(string unclean)
{
	unclean = unclean.replace(`"`, `\"`);
	unclean = unclean.replace(`'`, `\'`);
	return unclean;
}
unittest
{
	static assert(escapeQuotes(`"`) == `\"`);
	static assert(escapeQuotes(`'`) == `\'`);
}

// Internal, inefficiant function for removing the whitespace from
// a string (for comparing that templates generate the same output,
// ignoring whitespace exactnes)
string stripWs(string unclean) {
	return unclean
	.filter!(a => !isWhite(a) )
	.map!( a => cast(char) a )
	.array
	.idup;
}
unittest
{
	static assert(stripWs("") == "");
	static assert(stripWs("    \t") == "");
	static assert(stripWs(" a s d f ") == "asdf");
	static assert(stripWs(" a\ns\rd f ") == "asdf");
}

// Checks if haystack ends with needle, ignoring the whitespace in either
// of them
bool endsWithIgnoreWhitespace(string haystack, string needle)
{
	haystack = haystack.stripWs;
	needle   = needle.stripWs;

	return haystack.endsWith(needle);
}

unittest
{
	static assert(endsWithIgnoreWhitespace(")   {  ", "){"));
	static assert(!endsWithIgnoreWhitespace(")   {}", "){"));
}

bool startsWithBlockClose(string haystack)
{
	haystack = haystack.stripWs;

	// something that looks like }<something>); passes this
	if(haystack.startsWith("}") && haystack.canFind(");")) return true;
	return false;
}

unittest
{
	static assert(startsWithBlockClose(`}, 10);`));
	static assert(startsWithBlockClose(`});`));
	static assert(startsWithBlockClose(`}, "foo");`));
	static assert(startsWithBlockClose(`}); auto a = "foo";`));

	static assert(!startsWithBlockClose(`if() {}`));
	static assert(!startsWithBlockClose(`};`));
}

bool isBlockStart(string haystack)
{
	return haystack.endsWithIgnoreWhitespace("){");
}

bool isBlockEnd(string haystack)
{
	return haystack.startsWithBlockClose();
}
