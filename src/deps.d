module deps;

import std.regex;
import std.stdio;
import std.typecons;

alias Dependency = Tuple!(string, "client", string, "supplier");

// TODO use input range instead?
// TODO filter by source files instead?
Dependency[] moduleDependencies(RegEx)(File file, RegEx filter)
{
    Dependency[] dependencies = null;

    foreach (line; file.byLine)
    {
        dependencies ~= moduleDependencies(line, filter);
    }
    return dependencies;
}

private Dependency[] moduleDependencies(RegEx)(const char[] line, RegEx filter)
{
    import std.conv : to;

    enum pattern = regex(`(?P<client>[\w.]+)\s*\((?P<clientPath>.*)\)`
        ~ `\s*:[^:]*:\s*(?P<supplier>[\w.]+)\s*\((?P<supplierPath>.*)\)`);
    Dependency[] dependencies = null;
    auto captures = line.matchFirst(pattern);

    if (captures)
    {
        const clientPath = captures["clientPath"];
        const supplierPath = captures["supplierPath"];

        if (clientPath.matchFirst(filter) && supplierPath.matchFirst(filter))
        {
            const client = captures["client"].to!string;
            const supplier = captures["supplier"].to!string;

            dependencies ~= Dependency(client, supplier);
        }
    }
    return dependencies;
}

unittest
{
    const line = "depend (src/depend.d) : private : object (/usr/include/dmd/druntime/import/object.di)";

    assert(moduleDependencies(line, regex("")) == [Dependency("depend", "object")]);
    assert(moduleDependencies(line, regex("src")) == []);
}
