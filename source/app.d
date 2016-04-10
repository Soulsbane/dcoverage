import std.file;
import std.stdio : writeln;
import std.parallelism : parallel;
import std.string : startsWith, lineSplitter;
import std.array : array;
import std.path : baseName;
import std.conv : to;
import std.utf : UTFException;
import std.exception : ifThrown;
import std.range : retro;
import std.regex : Regex, regex, matchFirst;

Regex!char _Pattern = regex(r"is\s+(?P<percent>\d+)%\s+covered");

void scan()
{
	size_t count;
	size_t coveragePercentTotal;

	foreach(DirEntry e; parallel(dirEntries(".", "*.lst", SpanMode.breadth)))
	{
		auto name = e.name.baseName;

		if(e.isFile && !name.startsWith("."))
		{
			immutable string text = readText(e.name).ifThrown!UTFException("");
			auto lines = text.lineSplitter();
			const line = lines.array.retro.front;
			auto re = matchFirst(line, _Pattern);

			if(!re.empty)
			{
				size_t percent = to!size_t(re["percent"]);

				writeln(name, " => ", percent);
				++count;
				coveragePercentTotal += percent;
			}
		}
	}

	if(count != 0)
	{
		writeln;
		writeln("Coverage over ", count, " files: ", coveragePercentTotal / count, "%");
	}
	else
	{
		writeln("No coverage files found!");
	}
}

void main()
{
	scan();
}
