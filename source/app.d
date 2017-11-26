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

import colored;
import processwait.wait;

Regex!char _Pattern = regex(r"is\s+(?P<percent>\d+)%\s+covered");

auto getListOfCoverageFiles()
{
	return dirEntries("", SpanMode.depth).filter!(f => f.name.endsWith(".lst") && !f.name.startsWith("-tmp-dub_test"));
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

// FIXME: Ignore files that dub creates in the format of -tmp-dub_test_root-c4be77be-a1a1-4af2-b08d-faf29dff42bf.lst
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
				immutable size_t percent = to!size_t(re["percent"]);

				if(percent == 0)
				{
					writeln(fileName, " No Coverage!".red);
				}
				else
				{
					writeln(fileName, " => ", percent.to!string.yellow, "%".yellow);
				}

				++count;
				coveragePercentTotal += percent;
			}
		}
	}

	if(count == 0 && coveragePercentTotal == 0)
	{
		if(coveragePercentTotal == 0)
		{
			writeln("Coverage over ", count, " files");
		}
		else
		{
			writeln("No coverage files found!");
		}
	}
	else
	{
		writeln;
		writeln("Coverage over ", count, " files: ", coveragePercentTotal / count, "%");
	}
}

auto createCoverageFiles()
{
	return waitForApplication("dub", "test", "-b", "unittest-cov", "--skip-registry=standard");
}

void main(string[] args)
{
	const string[] commands = args[1..$];

	if(commands.length == 1 && commands[0] == "--cleanup")
	{
		writeln("Removing previously generated coverage files only.");
		removeCoverageFiles();
	}
	else
	{
		removeCoverageFiles();
		immutable auto exitStatus = createCoverageFiles();

		if(exitStatus == 0)
		{
			scan();
		}
		else
		{
			writeln("Failed to create coverage files!");
		}
	}
}
