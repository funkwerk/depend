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

@("write dependency graph in the DOT language")
unittest
{
    import dshould : equal, should;
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

    output.data.should.equal(outdent(expected).stripLeft);
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

Dependency[] transitiveReduction(ref Dependency[] dependencies)
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

    return cyclicDependencies;
}

@("apply transitive reduction")
unittest
{
    import dshould : be, equal, should;

    auto dependencies = [Dependency("a", "b"), Dependency("b", "c"), Dependency("a", "c")];
    auto cyclicDependencies = transitiveReduction(dependencies);

    dependencies.should.equal([Dependency("a", "b"), Dependency("b", "c")]);
    cyclicDependencies.should.be.empty;
}

@("apply transitive reduction to cyclic dependencies")
unittest
{
    import dshould : equal, should;

    auto dependencies = [Dependency("a", "b"), Dependency("b", "c"), Dependency("c", "a")];
    auto cyclicDependencies = transitiveReduction(dependencies);

    dependencies.should.equal([Dependency("a", "b"), Dependency("b", "c"), Dependency("c", "a")]);
    cyclicDependencies.sort.should.equal(dependencies);
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
