module graph;

import std.algorithm;
import std.range;
import std.typecons;

alias Dependency = Tuple!(string, "client", string, "supplier");

void write(Output)(auto ref Output output, const Dependency[] dependencies)
{
    import std.format : formattedWrite;

    output.put("digraph Dependencies {\n");
    output.put("node [shape=box];\n");
    foreach (element; dependencies.elements)
    {
        output.formattedWrite!(`"%s"`)(element);
        output.put('\n');
    }
    foreach (dependency; dependencies)
    {
        output.formattedWrite!(`"%s" -> "%s"`)(dependency.client, dependency.supplier);
        output.put('\n');
    }
    output.put("}\n");
}

unittest
{
    import std.array : appender;
    import std.string : outdent, stripLeft;

    auto output = appender!string;
    const dependencies = [Dependency("a", "b")];

    output.write(dependencies);

    const expected = `
        digraph Dependencies {
        node [shape=box];
        "a"
        "b"
        "a" -> "b"
        }
        `;

    assert(output.data == outdent(expected).stripLeft);
}

void transitiveClosure(ref Dependency[] dependencies)
{
    string[] elements = dependencies.elements;

    foreach (element; elements)
        foreach (client; elements)
            if (dependencies.canFind(Dependency(client, element)))
                foreach (supplier; elements)
                    if (dependencies.canFind(Dependency(element, supplier)))
                        dependencies.add(Dependency(client, supplier));
}

void transitiveReduction(Output)(auto ref Output output, ref Dependency[] dependencies)
{
    bool[string] mark = null;
    Dependency[] cyclicDependencies = null;

    void traverse(string node)
    {
        import std.array : array;

        mark[node] = true;
        foreach (outEdge; dependencies.filter!(a => a.client == node).array)
        {
            if (!dependencies.canFind(outEdge))
                continue;
            if (mark.get(outEdge.supplier, false))
            {
                cyclicDependencies.add(outEdge);
                continue;
            }
            foreach (inEdge; dependencies.filter!(a => a.supplier == outEdge.supplier).array)
            {
                if (inEdge == outEdge)
                    continue;
                if (mark.get(inEdge.client, false))
                    dependencies = dependencies.remove!(a => a == inEdge);
            }
            traverse(outEdge.supplier);
        }
        mark[node] = false;
    }

    foreach (element; dependencies.elements)
        traverse(element);

    if (!cyclicDependencies.empty)
    {
        import std.format : formattedWrite;

        output.put("warning: cyclic dependencies\n");
        foreach (dependency; cyclicDependencies.sort)
            output.formattedWrite!"%s -> %s\n"(dependency.client, dependency.supplier);
    }
}

// transitive reduction
unittest
{
    import std.array : appender;

    auto dependencies = [Dependency("a", "b"), Dependency("b", "c"), Dependency("a", "c")];
    auto output = appender!string;

    transitiveReduction(output, dependencies);

    assert(dependencies == [Dependency("a", "b"), Dependency("b", "c")]);
    assert(output.data.empty);
}

// transitive reduction with cyclic dependencies
unittest
{
    import std.array : appender;
    import std.string : outdent, stripLeft;

    auto dependencies = [Dependency("a", "b"), Dependency("b", "c"), Dependency("c", "a")];
    auto output = appender!string;

    transitiveReduction(output, dependencies);

    assert(dependencies == [Dependency("a", "b"), Dependency("b", "c"), Dependency("c", "a")]);

    const expected = `
        warning: cyclic dependencies
        a -> b
        b -> c
        c -> a
        `;

    assert(output.data == outdent(expected).stripLeft);
}

string[] elements(in Dependency[] dependencies)
{
    string[] elements = null;

    foreach (dependency; dependencies)
    {
        elements.add(dependency.client);
        elements.add(dependency.supplier);
    }
    return elements;
}

void add(Element)(ref Element[] elements, Element element)
{
    if (!elements.canFind(element))
        elements ~= element;
}
