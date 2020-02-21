module deps;

import std.range;
import std.regex;
import std.stdio;
import std.typecons;
version (unittest) import unit_threaded;

struct Element
{
    string name;

    Flag!"recursive" recursive;

    int opCmp(const ref Element other) const
    {
        return tuple(this.name, this.recursive).opCmp(tuple(other.name, other.recursive));
    }

    string toLabel() const
    {
        return this.recursive ? (this.name ~ ".*") : this.name;
    }

    string toPackage() const
    {
        return this.recursive ? (this.name ~ ".all") : this.name;
    }

    string toString() const
    {
        return toPackage;
    }
}

alias Dependency = Tuple!(Element, "client", Element, "supplier");

auto moduleDependencies(alias predicate)(File file)
{
    import std.algorithm : filter, map;

    return reader(file.byLine)
        .filter!predicate
        .map!(dependency => Dependency(
            Element(dependency.client.name, No.recursive),
            Element(dependency.supplier.name, No.recursive)));
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

    reader(only(line)).should.be == only(tuple(client, supplier));
}
