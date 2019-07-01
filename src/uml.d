module uml;

import graph;
import std.algorithm;
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
    import dshould : equal, should;

    read(only("a .> b")).should.equal([Dependency("a", "b")]);
    read(only("a <. b")).should.equal([Dependency("b", "a")]);
    read(only("a <.> b")).should.equal([Dependency("a", "b"), Dependency("b", "a")]);
    read(only("a.[#red]>b")).should.equal([Dependency("a", "b")]);
    read(only("a.[#red]le>b")).should.equal([Dependency("a", "b")]);
}

void write(Output)(auto ref Output output, const Dependency[] dependencies)
{
    import std.algorithm : sort;

    bool[] written = new bool[dependencies.length];

    struct Node
    {
        string[] path;

        Node[string] children;

        void add(string[] path, size_t offset = 0)
        {
            if (offset == path.length)
            {
                return;
            }

            if (path[offset] !in children)
            {
                children[path[offset]] = Node(path[0 .. offset + 1], null);
            }

            children[path[offset]].add(path, offset + 1);
        }
    }

    Node tree;

    dependencies.elements
        .sort
        .map!(a => a.split('.'))
        .each!(path => tree.add(path));

    bool recurse(Node node, size_t indent)
    {
        import std.format : formattedWrite;

        void writeIndent()
        {
            output.formattedWrite!"%s"("    ".repeat.take(indent).join);
        }

        bool wroteNewline = false;

        void writeNewline()
        {
            output.put("\n");
            wroteNewline = true;
        }

        bool childWroteNewline = false;

        node.children.keys.sort
            .map!(key => node.children[key])
            .each!((Node node)
            {
                if (!childWroteNewline)
                {
                    writeNewline;
                    childWroteNewline = true;
                }

                writeIndent;
                if (node.path.length == 1)
                {
                    output.formattedWrite!"package %s {"(node.path.join('.'));
                }
                else
                {
                    output.formattedWrite!"package %s as %s {"(node.path.back, node.path.join('.'));
                }

                bool childWroteNewline = recurse(node, indent + 1);

                if (childWroteNewline)
                {
                    writeIndent;
                }

                output.put("}\n");
            });

        bool dependencyWroteNewline = false;

        foreach (i, dependency; dependencies)
        {
            if (!written[i] &&
                dependency.client.split('.').startsWithAndLonger(node.path) &&
                dependency.supplier.split('.').startsWithAndLonger(node.path))
            {
                if (!dependencyWroteNewline)
                {
                    writeNewline;
                    dependencyWroteNewline = true;
                }

                writeIndent;
                writeDependency(output, dependency);
                written[i] = true;
            }
        }

        return wroteNewline;
    }

    output.put("@startuml\n");

    assert(tree.path.empty);

    recurse(tree, 0);

    output.put("\n");
    output.put("@enduml\n");
}

/// writes Plant-UML package diagram
unittest
{
    import dshould : equal, should;
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

    output.data.should.equal(outdent(expected).stripLeft);
}

/// Puts purely internal dependencies inside the package
unittest
{
    import dshould : equal, should;
    import std.array : appender;
    import std.string : outdent, stripLeft;

    auto output = appender!string;
    const dependencies = [Dependency("a", "a.b"), Dependency("a.b", "a.c")];

    output.write(dependencies);

    const expected = `
        @startuml

        package a {
            package b as a.b {}
            package c as a.c {}

            a.b ..> a.c
        }

        a ..> a.b

        @enduml
        `;

    output.data.should.equal(outdent(expected).stripLeft);
}

private alias startsWithAndLonger = (haystack, needle) =>
    haystack.startsWith(needle) && !haystack.drop(needle.count).empty;

private void writeDependency(Output)(auto ref Output output, const Dependency dependency)
{
    output.put(dependency.client);
    output.put(" ..> ");
    output.put(dependency.supplier);
    output.put("\n");
}
