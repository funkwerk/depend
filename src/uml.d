module uml;

import deps : Dependency, Element;
import graph;
import std.algorithm;
import std.range;
import std.stdio;
version (unittest) import unit_threaded;

Dependency[] read(R)(R input)
{
    import std.array : appender;

    auto output = appender!(Dependency[]);

    read(input, output);
    return output.data;
}

private void read(Input, Output)(Input input, auto ref Output output)
{
    import std.regex : matchFirst, regex;

    enum arrow = `(?P<arrow><?\.+(left|right|up|down|le?|ri?|up?|do?|\[.*?\])*\.*>?)`;
    enum pattern = regex(`(?P<lhs>\w+(\.\w+)*(\.\*)?)\s*` ~ arrow ~ `\s*(?P<rhs>\w+(\.\w+)*(\.\*)?)`);

    foreach (line; input)
    {
        auto captures = line.matchFirst(pattern);

        if (captures)
        {
            enum recursiveMarker = ".all";

            const string lhs = captures["lhs"].idup;
            const lhsRecursive = lhs.endsWith(recursiveMarker) ? Yes.recursive : No.recursive;
            const lhsElement = Element(lhsRecursive ? lhs.dropBack(recursiveMarker.length) : lhs, lhsRecursive);

            const string rhs = captures["rhs"].idup;
            const rhsRecursive = rhs.endsWith(recursiveMarker) ? Yes.recursive : No.recursive;
            const rhsElement = Element(rhsRecursive ? rhs.dropBack(recursiveMarker.length) : rhs, rhsRecursive);

            if (captures["arrow"].endsWith(">"))
                output.put(Dependency(lhsElement, rhsElement));
            if (captures["arrow"].startsWith("<"))
                output.put(Dependency(rhsElement, lhsElement));
        }
    }
}

@("read Plant-UML dependencies")
unittest
{
    read(only("a .> b")).should.be == [dependency("a", "b")];
    read(only("a <. b")).should.be == [dependency("b", "a")];
    read(only("a <.> b")).should.be == [dependency("a", "b"), dependency("b", "a")];
    read(only("a.all .> b.all")).should.be == [Dependency(Element("a", Yes.recursive), Element("b", Yes.recursive))];
    read(only("a.[#red]>b")).should.be == [dependency("a", "b")];
    read(only("a.[#red]le>b")).should.be == [dependency("a", "b")];
}

void write(Output)(auto ref Output output, const Dependency[] dependencies)
{
    Package hierarchy;

    dependencies.each!(dependency => hierarchy.add(dependency));

    output.put("@startuml\n");
    hierarchy.write(output);
    output.put("@enduml\n");
}

@("write PlantUML package diagram")
unittest
{
    import std.array : appender;
    import std.string : outdent, stripLeft;

    auto output = appender!string;
    const dependencies = [dependency("a", "b")];

    output.write(dependencies);

    const expected = `
        @startuml
        package a {}
        package b {}

        a ..> b
        @enduml
        `;

    output.data.should.be == outdent(expected).stripLeft;
}

@("place internal dependencies inside the package")
unittest
{
    import std.array : appender;
    import std.string : outdent, stripLeft;

    auto output = appender!string;
    const dependencies = [dependency("a", "a.b"), dependency("a.b", "a.c")];

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

    output.data.should.be == outdent(expected).stripLeft;
}

@("use appropriate wildcard descriptions")
unittest
{
    import std.array : appender;
    import std.string : outdent, stripLeft;

    auto output = appender!string;
    const dependencies = [Dependency(Element("a", Yes.recursive), Element("b", Yes.recursive))];

    output.write(dependencies);

    const expected = `
        @startuml
        package a.* as a.all {}
        package b.* as b.all {}

        a.all ..> b.all
        @enduml
        `;

    output.data.should.be == outdent(expected).stripLeft;
}

private alias dependency = (client, supplier) =>
    Dependency(Element(client, No.recursive), Element(supplier, No.recursive));

private struct Package
{
    string[] path;

    Flag!"recursive" recursive;

    Package[string] subpackages;

    Dependency[] dependencies;

    void add(Dependency dependency)
    {
        const clientPath = dependency.client.name.split('.');
        const supplierPath = dependency.supplier.name.split('.');
        const path = commonPrefix(clientPath.dropBackOne, supplierPath.dropBackOne);

        addPackage(clientPath, dependency.client.recursive);
        addPackage(supplierPath, dependency.client.recursive);
        addDependency(path, dependency);
    }

    void addPackage(const string[] path, Flag!"recursive" recursive, size_t index = 0)
    {
        if (path[index] !in subpackages)
            subpackages[path[index]] = Package(path[0 .. index + 1].dup, recursive);
        if (index + 1 < path.length)
            subpackages[path[index]].addPackage(path, recursive, index + 1);
    }

    void addDependency(const string[] path, Dependency dependency)
    {
        if (path.empty)
            dependencies ~= dependency;
        else
            subpackages[path.front].addDependency(path.dropOne, dependency);
    }

    void write(Output)(auto ref Output output, size_t level = 0)
    {
        import std.format : formattedWrite;

        void indent()
        {
            foreach (_; 0 .. level)
                output.put("    ");
        }

        foreach (subpackage; subpackages.keys.sort.map!(key => subpackages[key]))
        {
            indent;
            if (subpackage.recursive)
            {
                assert(subpackage.subpackages.empty && subpackage.dependencies.empty,
                    "recursive package must not contain subpackages");
                output.formattedWrite!"package %s.* as %s.all {"(subpackage.path.back, subpackage.path.join('.'));
            }
            else if (subpackage.path.length == 1)
                output.formattedWrite!"package %s {"(subpackage.path.join('.'));
            else
                output.formattedWrite!"package %s as %s {"(subpackage.path.back, subpackage.path.join('.'));

            if (!subpackage.subpackages.empty || !subpackage.dependencies.empty)
            {
                output.put('\n');
                subpackage.write(output, level + 1);
                indent;
            }
            output.put("}\n");
        }
        if (!dependencies.empty)
            output.put('\n');
        foreach (dependency; dependencies.sort)
        {
            indent;
            output.formattedWrite!"%s ..> %s\n"(dependency.client.toPackage, dependency.supplier.toPackage);
        }
    }
}
