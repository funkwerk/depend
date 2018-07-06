module uml;

import graph;
import std.range;
import std.stdio;

Dependency[] read(R)(R input)
{
    import std.array : appender;

    auto output = appender!(Dependency[]);

    read(input, output);
    return output.data;
}

private void read(Input, Output)(Input input, auto ref Output output)
{
    import std.algorithm : endsWith, startsWith;
    import std.conv : to;
    import std.regex : matchFirst, regex;

    enum arrow = `(?P<arrow><?\.+(left|right|up|down|le?|ri?|up?|do?|\[.*?\])*\.*>?)`;
    enum pattern = regex(`(?P<lhs>\w+(.\w+)*)\s*` ~ arrow ~ `\s*(?P<rhs>\w+(.\w+)*)`);

    foreach (line; input)
    {
        auto captures = line.matchFirst(pattern);

        if (captures)
        {
            const lhs = captures["lhs"].to!string;
            const rhs = captures["rhs"].to!string;

            if (captures["arrow"].endsWith(">"))
                output.put(Dependency(lhs, rhs));
            if (captures["arrow"].startsWith("<"))
                output.put(Dependency(rhs, lhs));
        }
    }
}

/// reads Plant-UML dependencies
unittest
{
    assert(read(only("a .> b")) == [Dependency("a", "b")]);
    assert(read(only("a <. b")) == [Dependency("b", "a")]);
    assert(read(only("a <.> b")) == [Dependency("a", "b"), Dependency("b", "a")]);
    assert(read(only("a.[#red]>b")) == [Dependency("a", "b")]);
    assert(read(only("a.[#red]le>b")) == [Dependency("a", "b")]);
}

void write(Output)(auto ref Output output, const Dependency[] dependencies)
{
    import std.algorithm : sort;

    auto writer = writer(formatter(output));

    output.put("@startuml\n");
    foreach (element; dependencies.elements.sort)
        writer.put(element.split('.'));
    writer.close;
    output.put('\n');
    foreach (dependency; dependencies)
    {
        output.put(dependency.client);
        output.put(" ..> ");
        output.put(dependency.supplier);
        output.put('\n');
    }
    output.put("@enduml\n");
}

/// writes Plant-UML package diagram
unittest
{
    import std.array : appender;
    import std.string : outdent, stripLeft;

    auto output = appender!string;
    const dependencies = [Dependency("a", "b")];

    output.write(dependencies);

    const expected = `
        @startuml
        package a {}
        package b {}

        a ..> b
        @enduml
        `;

    assert(output.data == outdent(expected).stripLeft, output.data);
}

auto writer(Formatter)(Formatter formatter)
{
    return Writer!Formatter(formatter);
}

struct Writer(Formatter)
{
    Formatter formatter;

    string[] prev = null;

    void put(string[] path)
    in
    {
        assert(!path.empty);
    }
    do
    {
        import std.algorithm : commonPrefix;

        auto prefix = commonPrefix(this.prev, path);

        close(this.prev.length - prefix.length);
        this.prev = path.dup;
        path.popFrontN(prefix.length);
        put(prefix, path);
    }

    void put(string[] prefix, string[] path)
    in
    {
        assert(!path.empty);
    }
    do
    {
        import std.format : format;
        import std.string : join;

        const name = path.front;

        prefix ~= name;
        path.popFront;
        if (prefix.length == 1)
            this.formatter.open(format!"package %s {"(name));
        else
            this.formatter.open(format!"package %s as %s {"(name, prefix.join('.')));
        if (!path.empty)
            put(prefix, path);
    }

    void close()
    {
        close(this.prev.length);
        this.prev = null;
    }

    void close(size_t n)
    {
        foreach (_; 0 .. n)
            this.formatter.close("}");
    }

}

auto formatter(Output)(auto ref Output output)
{
    return Formatter!Output(output);
}

struct Formatter(Output)
{
    Output output;

    size_t indent = 0;

    bool pending = false;

    void open(string s)
    {
        if (this.pending)
            this.output.put("\n");
        indentation;
        this.output.put(s);
        ++this.indent;
        this.pending = true;
    }

    void close(string s)
    {
        --this.indent;
        if (!this.pending)
            indentation;
        this.output.put(s);
        this.output.put("\n");
        this.pending = false;
    }

    void indentation()
    {
        foreach (_; 0 .. this.indent)
            this.output.put("    ");
    }
}

/// writes nested packages
unittest
{
    import std.array : appender;
    import std.string : outdent, stripLeft;

    auto output = appender!string;
    auto writer = writer(formatter(output));

    writer.put(["a", "b", "x"]);
    writer.put(["a", "b", "y"]);
    writer.put(["a", "z"]);
    writer.close;

    const expected = `
        package a {
            package b as a.b {
                package x as a.b.x {}
                package y as a.b.y {}
            }
            package z as a.z {}
        }
        `;

    assert(output.data == outdent(expected).stripLeft);
}
