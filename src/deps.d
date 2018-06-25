module deps;

import std.range;
import std.regex;
import std.stdio;
import std.typecons;

alias Dependency = Tuple!(string, "client", string, "supplier");

// TODO avoid redundancy
Dependency[] moduleDependencies(RegEx)(File file, RegEx pattern)
if (isRegexFor!(RegEx, string))
{
    import std.algorithm : filter, map;

    bool matches(T)(T dependency)
    {
        with (dependency)
        {
            return client.path.matchFirst(pattern) && supplier.path.matchFirst(pattern);
        }
    }

    return reader(file.byLine)
        .filter!(dependency => matches(dependency))
        .map!(dependency => Dependency(dependency.client.name, dependency.supplier.name))
        .array;
}

Dependency[] moduleDependencies(File file, const string[] fileNames)
{
    import std.algorithm : canFind, filter, map;

    bool matches(T)(T dependency)
    {
        with (dependency)
        {
            return fileNames.canFind(client.path) && fileNames.canFind(supplier.path);
        }
    }

    return reader(file.byLine)
        .filter!(dependency => matches(dependency))
        .map!(dependency => Dependency(dependency.client.name, dependency.supplier.name))
        .array;
}

auto reader(R)(R input)
{
    return Reader!R(input);
}

struct Reader(R)
if (isInputRange!R)
{
    alias Module = Tuple!(string, "name", string, "path");
    alias Dependency = Tuple!(Module, "client", Module, "supplier");

    private R input;

    public bool empty = false;

    public Dependency front;

    private this(R input)
    {
        this.input = input;
        popFront;
    }

    public void popFront()
    {
        import std.conv : to;
        import std.regex : matchFirst, regex;

        enum pattern = regex(`^(depsImport\s)?`
            ~ `(?P<clientName>[\w.]+)\s\((?P<clientPath>.*)\)`
            ~ `\s:[^:]*:\s`
            ~ `(?P<supplierName>[\w.]+)\s\((?P<supplierPath>.*)\)`);

        while (!this.input.empty)
        {
            auto captures = this.input.front.matchFirst(pattern);

            scope (exit)
                this.input.popFront;

            if (captures)
            {
                with (this.front.client)
                {
                    name = captures["clientName"].to!string;
                    path = captures["clientPath"].to!string;
                }
                with (this.front.supplier)
                {
                    name = captures["supplierName"].to!string;
                    path = captures["supplierPath"].to!string;
                }
                return;
            }
        }
        this.empty = true;
    }
}

/// reads module dependencies
unittest
{
    import std.algorithm : equal;

    const line = "depend (src/depend.d) : private : object (/usr/include/dmd/druntime/import/object.di)";
    const client = tuple("depend", "src/depend.d");
    const supplier = tuple("object", "/usr/include/dmd/druntime/import/object.di");

    assert(reader(only(line)).equal(only(tuple(client, supplier))));
}
