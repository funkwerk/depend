module settings;

import core.stdc.stdlib;
import model;
import std.range;
import std.regex;
import std.stdio;
version (unittest) import unit_threaded;

struct Settings
{
    string compiler;
    string[] depsFiles;
    bool scan;
    string[] umlFiles;
    Regex!char pattern;
    bool detail;
    bool transitive;
    bool dot;
    string[] targetFiles;
    bool simplify;
    string[] unrecognizedArgs;
}

Settings read(string[] args)
in (!args.empty)
{
    import std.exception : enforce;
    import std.getopt : config, defaultGetoptPrinter, getopt, GetoptResult;

    Settings settings;

    with (settings)
    {
        string filter;
        GetoptResult result;

        try
        {
            result = getopt(args,
                config.passThrough,
                "compiler|c", "Specify the compiler to use", &compiler,
                "deps", "Read module dependencies from file", &depsFiles,
                "uml", "Read dependencies from PlantUML file", &umlFiles,
                "filter", "Filter source files  matching the regular expression", &filter,
                "detail", "Inspect dependencies between modules instead of packages", &detail,
                "transitive|t", "Keep transitive dependencies", &transitive,
                "dot", "Write dependency graph in the DOT language", &dot,
                "check", "Check against the PlantUML target dependencies", &targetFiles,
                "simplify", "Use simplifying assumptions for the check (experimental)", &simplify,
            );
            if (!filter.empty)
            {
                enforce(!compiler.empty || !depsFiles.empty,
                        "filter can only be applied to dependencies collected by a compiler");

                pattern = regex(filter);
            }
        }
        catch (Exception exception)
        {
            stderr.writeln("error: ", exception.msg);
            exit(EXIT_FAILURE);
        }
        if (result.helpWanted)
        {
            import std.path : baseName;

            writefln("Usage: %s [options] files", args.front.baseName);
            writeln("Process import dependencies as created by dmd with the --deps switch.");
            writeln("If no compiler is specified, source files are scanned for (simple) import declarations.");
            defaultGetoptPrinter("Options:", result.options);
            exit(EXIT_SUCCESS);
        }
        unrecognizedArgs = args.dropOne;
    }
    return settings;
}

@("read settings")
unittest
{
    const settings = read(["depend", "--deps", "dependencies", "--check", "target"]);

    with (settings)
    {
        depsFiles.should.be == ["dependencies"];
        targetFiles.should.be == ["target"];
    }
}

@("read settings with unrecognized arguments")
unittest
{
    const settings = read(["depend", "main.d", "--detail"]);

    with (settings)
    {
        unrecognizedArgs.should.be == ["main.d"];
        detail.should.be == true;
    }
}
