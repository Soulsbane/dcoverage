import std.file;
import std.stdio : writeln;
import std.parallelism : parallel;
import std.string : startsWith, lineSplitter, endsWith;
import std.array : array;
import std.path : baseName;
import std.conv : to;
import std.utf : UTFException;
import std.exception : ifThrown;
import std.range : retro;
import std.regex : Regex, regex, matchFirst;
import std.process : pipeProcess, wait, tryWait;
import std.algorithm : filter;

import raijin.utils.process;

Regex!char _Pattern = regex(r"is\s+(?P<percent>\d+)%\s+covered");

auto getListOfCoverageFiles()
{
	return dirEntries("", SpanMode.depth).filter!(f => f.name.endsWith(".lst"));
}

/// Dub creates lots of hidden .lst files for dependencies and fails to remove them. So we do it here.
void removeCoverageFiles()
{
	auto fileList = getListOfCoverageFiles();

	foreach(e; parallel(fileList, 1))
	{
		remove(e.name);
	}
}

void scan()
{
	size_t count;
	size_t coveragePercentTotal;
	auto fileList = getListOfCoverageFiles();

	foreach(e; parallel(fileList, 1))
	{
		auto fileName = e.name.baseName;

		if(e.isFile && !fileName.startsWith("."))
		{
			immutable string text = readText(e.name).ifThrown!UTFException("");
			auto lines = text.lineSplitter();
			const line = lines.array.retro.front;
			auto re = matchFirst(line, _Pattern);

			if(!re.empty)
			{
				size_t percent = to!size_t(re["percent"]);

				writeln(fileName, " => ", percent, "%");
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

void createCoverageFiles()
{
	ProcessWait process;
	process.execute("dub", "test", "-b", "unittest-cov");
}

void main()
{
	removeCoverageFiles();
	createCoverageFiles();
	scan();
}
