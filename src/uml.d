module uml;

import graph;
import std.range;
import std.stdio;

Dependency[] plantUMLDependencies(File file)
{
    Dependency[] dependencies = null;

    foreach (line; file.byLine)
        dependencies ~= plantUMLDependencies(line);
    return dependencies;
}

private Dependency[] plantUMLDependencies(const char[] line)
{
    import std.algorithm : endsWith, startsWith;
    import std.conv : to;
    import std.regex : matchFirst, regex;

    const ARROW = `(?P<arrow><?\.+(left|right|up|down|le?|ri?|up?|do?|\[.*?\])*\.*>?)`;
    enum pattern = regex(`(?P<lhs>\w+(.\w+)*)\s*` ~ ARROW ~ `\s*(?P<rhs>\w+(.\w+)*)`);
    Dependency[] dependencies = null;
    auto captures = line.matchFirst(pattern);

    if (captures)
    {
        const lhs = captures["lhs"].to!string;
        const rhs = captures["rhs"].to!string;

        if (captures["arrow"].endsWith(">"))
            dependencies ~= Dependency(lhs, rhs);
        if (captures["arrow"].startsWith("<"))
            dependencies ~= Dependency(rhs, lhs);
    }
    return dependencies;
}

unittest
{
    assert(plantUMLDependencies("A.>B") == [Dependency("A", "B")]);
    assert(plantUMLDependencies("A<.B") == [Dependency("B", "A")]);
    assert(plantUMLDependencies("A<.>B") == [Dependency("A", "B"), Dependency("B", "A")]);
    assert(plantUMLDependencies("A.left>B") == [Dependency("A", "B")]);
    assert(plantUMLDependencies("A.[#red]>B") == [Dependency("A", "B")]);
    assert(plantUMLDependencies("A.[#red]le>B") == [Dependency("A", "B")]);
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
