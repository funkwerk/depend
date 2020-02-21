module graph;

import deps : Dependency, Element;
import std.algorithm;
import std.range;
import std.typecons;
version (unittest) import unit_threaded;

void write(Output)(auto ref Output output, const Dependency[] dependencies)
{
    import std.format : formattedWrite;

    output.put("digraph Dependencies {\n");
    output.put("node [shape=box];\n");
    foreach (element; dependencies.elements)
    {
        output.formattedWrite!(`"%s"`)(element.name);
        output.put('\n');
    }
    foreach (dependency; dependencies)
    {
        output.formattedWrite!`"%s" -> "%s"`(dependency.client, dependency.supplier);
        output.put('\n');
    }
    output.put("}\n");
}

@("write dependency graph in the DOT language")
unittest
{
    import std.array : appender;
    import std.string : outdent, stripLeft;

    auto output = appender!string;
    const dependencies = [Dependency(Element("a", No.recursive), Element("b", No.recursive))];

    output.write(dependencies);

    const expected = `
        digraph Dependencies {
        node [shape=box];
        "a"
        "b"
        "a" -> "b"
        }
        `;

    output.data.should.be == outdent(expected).stripLeft;
}

void transitiveClosure(ref Dependency[] dependencies)
{
    Element[] elements = dependencies.elements;

    foreach (element; elements)
        foreach (client; elements)
            if (dependencies.canFind(Dependency(client, element)))
                foreach (supplier; elements)
                    if (dependencies.canFind(Dependency(element, supplier)))
                        dependencies.add(Dependency(client, supplier));
}

Dependency[] transitiveReduction(ref Dependency[] dependencies)
{
    bool[Element] mark = null;
    Dependency[] cyclicDependencies = null;

    void traverse(Element node)
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
    auto dependencies = [dependency("a", "b"), dependency("b", "c"), dependency("a", "c")];
    auto cyclicDependencies = transitiveReduction(dependencies);

    dependencies.should.be == [dependency("a", "b"), dependency("b", "c")];
    cyclicDependencies.shouldBeEmpty;
}

@("apply transitive reduction to cyclic dependencies")
unittest
{
    auto dependencies = [dependency("a", "b"), dependency("b", "c"), dependency("c", "a")];
    auto cyclicDependencies = transitiveReduction(dependencies);

    dependencies.should.be == [dependency("a", "b"), dependency("b", "c"), dependency("c", "a")];
    cyclicDependencies.sort.should.be == dependencies;
}

private alias dependency = (client, supplier) =>
    Dependency(Element(client, No.recursive), Element(supplier, No.recursive));

Element[] elements(in Dependency[] dependencies)
{
    Element[] elements = null;

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
