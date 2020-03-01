module settings;

import core.stdc.stdlib;
import model;
import std.range;
import std.stdio;
version (unittest) import unit_threaded;

struct Settings
{
    string[] depsFiles = null;
    string compiler = "dmd";
    string pattern = null;
    string[] umlFiles = null;
    bool detail = false;
    bool transitive = false;
    bool dot = false;
    string[] targetFiles = null;
    bool strict = false;
    string[] unrecognizedArgs;
}

Settings read(string[] args)
in (!args.empty)
{
    import std.getopt : config, defaultGetoptPrinter, getopt, GetoptResult;

    Settings settings;

    with (settings)
    {
        GetoptResult result;

        try
        {
            result = getopt(args,
                config.passThrough,
                "deps", "Read module dependencies from file", &depsFiles,
                "compiler|c", "Specify the compiler to use (default: dmd)", &compiler,
                "filter", "Filter source files  matching the regular expression", &pattern,
                "uml", "Read dependencies from PlantUML file", &umlFiles,
                "detail", "Inspect dependencies between modules instead of packages", &detail,
                "transitive|t", "Keep transitive dependencies", &transitive,
                "dot", "Write dependency graph in the DOT language", &dot,
                "check", "Check against the PlantUML target dependencies", &targetFiles,
                "strict", "Do not use simplifying assumptions for the check", &strict,
            );
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
