module model;

version (unittest) import unit_threaded;

struct Dependency
{
    FullyQualifiedName client;

    FullyQualifiedName supplier;

    this(string client, string supplier)
    {
        this(FullyQualifiedName(client), FullyQualifiedName(supplier));
    }

    this(FullyQualifiedName client, FullyQualifiedName supplier)
    {
        this.client = client;
        this.supplier = supplier;
    }

    int opCmp(ref const Dependency that) const
    {
        import std.algorithm : cmp;

        int result = cmp(this.client.names, that.client.names);

        if (result == 0)
        {
            result = cmp(this.supplier.names, that.supplier.names);
        }
        return result;
    }
}

struct FullyQualifiedName
{
    string[] names;

    this(string name)
    {
        import std.string : split;

        this(name.split('.'));
    }

    this(string[] names)
    {
        this.names = names.dup;
    }

    string toString() const
    {
        import std.string : join;

        return this.names.join('.');
    }
}

string packages(FullyQualifiedName fullyQualifiedName)
{
    import std.algorithm : splitter;
    import std.array : join;
    import std.range : dropBackOne;

    return fullyQualifiedName.names
        .dropBackOne
        .join('.');
}

@("split packages from a fully-qualified module name")
unittest
{
    packages(FullyQualifiedName("bar.baz.foo")).should.be == "bar.baz";
    packages(FullyQualifiedName("foo")).shouldBeEmpty;
}
