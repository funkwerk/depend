module graph;

import std.algorithm;
import std.range;
import std.typecons;

// TODO how to use graph terminology instead?
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

void transitiveReduction(ref Dependency[] dependencies)
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
    // TODO don't write warnings in transitive-reduction function
    if (!cyclicDependencies.empty)
    {
        import std.stdio : stderr;

        stderr.writeln("warning: cyclic dependencies");
        foreach (dependency; cyclicDependencies.sort)
            stderr.writeln(dependency.client, " -> ", dependency.supplier);
    }
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