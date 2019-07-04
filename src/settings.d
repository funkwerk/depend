module settings;

import core.stdc.stdlib;
import std.range;
import std.stdio;

struct Settings
{
    string[] depsFiles = null;
    string compiler = "dmd";
    string pattern = null;
    bool detail = false;
    bool transitive = false;
    bool dot = false;
    string[] targetFiles = null;
    string[] unrecognizedArgs;
}

Settings read(string[] args)
in
{
    assert(!args.empty);
}
do
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
                "detail", "Inspect dependencies between modules instead of packages", &detail,
                "transitive|t", "Keep transitive dependencies", &transitive,
                "dot", "Write dependency graph in the DOT language", &dot,
                "check", "Check against the PlantUML target dependencies", &targetFiles,
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

/// reads settings
unittest
{
    import dshould : equal, should;

    const settings = read(["depend", "--deps", "dependencies", "--check", "target"]);

    with (settings)
    {
        depsFiles.should.equal(["dependencies"]);
        targetFiles.should.equal(["target"]);
    }
}

/// reads settings with unrecognized arguments
unittest
{
    import dshould : be, equal, should;

    const settings = read(["depend", "main.d", "--detail"]);

    with (settings)
    {
        unrecognizedArgs.should.equal(["main.d"]);
        detail.should.be(true);
    }
}

private string packages(string fullyQualifiedName)
{
    import std.range : dropBackOne;

    return fullyQualifiedName.split('.')
        .dropBackOne
        .join('.');
}

unittest
{
    import dshould : be, equal, should;

    packages("bar.baz.foo").should.equal("bar.baz");
    packages("foo").should.be.empty;
}
