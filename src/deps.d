module deps;

import std.range;
import std.regex;
import std.stdio;
import std.typecons;
version (unittest) import dshould;

alias Dependency = Tuple!(string, "client", string, "supplier");

auto moduleDependencies(alias predicate)(File file)
{
    import std.algorithm : filter, map;

    return reader(file.byLine)
        .filter!predicate
        .map!(dependency => Dependency(dependency.client.name, dependency.supplier.name));
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

@("read module dependencies")
unittest
{
    const line = "depend (src/depend.d) : private : object (/usr/include/dmd/druntime/import/object.di)";
    const client = tuple("depend", "src/depend.d");
    const supplier = tuple("object", "/usr/include/dmd/druntime/import/object.di");

    reader(only(line)).should.equal(only(tuple(client, supplier)));
}

bool crossesPrefix(const Dependency dependency, const string prefix)
{
    import util : fqnPrefixed, fqnStartsWith;

    return dependency.client.fqnPrefixed(prefix) && !dependency.supplier.fqnStartsWith(prefix)
        || dependency.supplier.fqnPrefixed(prefix) && !dependency.client.fqnStartsWith(prefix);
}

@("dependencies crossing a prefix path")
unittest
{
    assert(Dependency("a.x", "b.y").crossesPrefix("a"));
    assert(Dependency("a.x", "b.y").crossesPrefix("b"));
    assert(Dependency("a.x", "b").crossesPrefix("a"));
    assert(!Dependency("a", "a.y").crossesPrefix("a"));
    assert(!Dependency("a.x", "a").crossesPrefix("a"));
    assert(!Dependency("a.x", "a.y").crossesPrefix("a"));
    assert(!Dependency("a", "a.b.y").crossesPrefix("a"));
    assert(Dependency("a", "a.b.y").crossesPrefix("a.b"));
}
