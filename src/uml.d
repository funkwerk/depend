module uml;

import graph;
import std.algorithm;
import std.range;
import std.stdio;
version (unittest) import dshould;

Dependency[] read(R)(R input)
{
    import std.array : appender;

    auto output = appender!(Dependency[]);

    read(input, output);
    return output.data;
}

private void read(Input, Output)(Input input, auto ref Output output)
{
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

@("read Plant-UML dependencies")
unittest
{
    read(only("a .> b")).should.equal([Dependency("a", "b")]);
    read(only("a <. b")).should.equal([Dependency("b", "a")]);
    read(only("a <.> b")).should.equal([Dependency("a", "b"), Dependency("b", "a")]);
    read(only("a.[#red]>b")).should.equal([Dependency("a", "b")]);
    read(only("a.[#red]le>b")).should.equal([Dependency("a", "b")]);
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

@("place internal dependencies inside the package")
unittest
{
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

private struct Package
{
    string[] path;

    Package[string] subpackages;

    Dependency[] dependencies;

    void add(Dependency dependency)
    {
        const clientPath = dependency.client.split('.');
        const supplierPath = dependency.supplier.split('.');
        const path = commonPrefix(clientPath.dropBackOne, supplierPath.dropBackOne);

        addPackage(clientPath);
        addPackage(supplierPath);
        addDependency(path, dependency);
    }

    void addPackage(const string[] path, size_t index = 0)
    {
        if (path[index] !in subpackages)
            subpackages[path[index]] = Package(path[0 .. index + 1].dup);
        if (index + 1 < path.length)
            subpackages[path[index]].addPackage(path, index + 1);
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
            if (subpackage.path.length == 1)
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
        foreach (dependency; dependencies)
        {
            indent;
            output.formattedWrite!"%s ..> %s\n"(dependency.client, dependency.supplier);
        }
    }
}
