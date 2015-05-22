#!/usr/bin/env rdmd

import std.algorithm;
import std.array;
import std.regex;
import std.stdio;
import std.typecons;

const USAGE = `Usage: %s [options] FILE
Process import dependencies as created by dmd with the --deps switch.
Options:
  --dot                 Print the dependency graph in the DOT language
  -f, --filter REGEX    Filter source files  matching the regular expression
  -h, --help            Display usage information, then exit
  -p, --packages        Generalize to package dependencies
  -t, --target FILE     Check against the PlantUML target dependencies`;

alias Dependency = Tuple!(string, "client", string, "supplier");

int main(string[] args)
{
    import std.getopt : getopt;

    bool dot = false;
    bool help = false;
    bool packages = false;
    string filter;
    string[] targets = null;

    try
    {
        getopt(args,
            "dot", &dot,
            "help|h", &help,
            "filter|f", &filter,
            "packages|p", &packages,
            "target|t", &targets);
    }
    catch (Exception exception)
    {
        stderr.writeln("error: ", exception.msg);
        return 1;
    }

    if (help)
    {
        import std.path : baseName;

        writefln(USAGE, args[0].baseName);
        return 0;
    }

    File file = (args.length > 1) ? File(args[1]) : stdin;
    auto pattern = regex(filter);
    Dependency[] actualDependencies = moduleDependencies(file, pattern);

    actualDependencies = actualDependencies.sort().uniq.array;
    if (!targets.empty)
    {
        uint count = 0;
        Dependency[] targetDependencies = null;

        foreach (target; targets)
            targetDependencies ~= plantUMLDependencies(File(target));

        targetDependencies.transitiveClosure;
        foreach (dependency; actualDependencies)
        {
            const client = dependency.client;
            const supplier = dependency.supplier;

            if (packages)
            {
                dependency = Dependency(client.packages, supplier.packages);
                if (dependency.client.empty || dependency.supplier.empty || dependency.client == dependency.supplier)
                    continue;
            }
            else
                dependency = Dependency(client, supplier);
            if (!targetDependencies.canFind(dependency))
            {
                stderr.writefln("error: unintended dependency %s -> %s", client, supplier);
                ++count;
            }
        }
        if (count > 0)
            return 1;
    }
    if (dot)
    {
        if (packages)
        {
            Dependency[] dependencies = null;

            foreach (dependency; actualDependencies)
            {
                const client = dependency.client.packages;
                const supplier = dependency.supplier.packages;

                if (!client.empty && !supplier.empty && client != supplier)
                    dependencies.add(Dependency(client, supplier));
            }
            write(dependencies);
        }
        else
            write(actualDependencies);
    }
    return 0;
}

Dependency[] moduleDependencies(RegEx)(File file, RegEx filter)
{
    Dependency[] dependencies = null;

    foreach (line; file.byLine)
    {
        dependencies ~= moduleDependencies(line, filter);
    }
    return dependencies;
}

Dependency[] moduleDependencies(RegEx)(in char[] line, RegEx filter)
{
    import std.conv : to;

    enum pattern = regex(`(?P<client>[\w.]+)\s*\((?P<clientPath>.*)\)`
        `\s*:[^:]*:\s*(?P<supplier>[\w.]+)\s*\((?P<supplierPath>.*)\)`);
    Dependency[] dependencies = null;
    auto captures = line.matchFirst(pattern);

    if (captures)
    {
        const clientPath = captures["clientPath"];
        const supplierPath = captures["supplierPath"];

        if (clientPath.matchFirst(filter) && supplierPath.matchFirst(filter))
        {
            const client = captures["client"].to!string;
            const supplier = captures["supplier"].to!string;

            dependencies ~= Dependency(client, supplier);
        }
    }
    return dependencies;
}

unittest
{
    const line = "depend (src/depend.d) : private : object (/usr/include/dmd/druntime/import/object.di)";

    assert(moduleDependencies(line, regex("")) == [Dependency("depend", "object")]);
    assert(moduleDependencies(line, regex("src")) == []);
}

Dependency[] plantUMLDependencies(File file)
{
    Dependency[] dependencies = null;

    foreach (line; file.byLine)
        dependencies ~= plantUMLDependencies(line);
    return dependencies;
}

Dependency[] plantUMLDependencies(in char[] line)
{
    import std.conv : to;

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

void write(in Dependency[] dependencies)
{
    writeln("digraph Dependencies {");
    writeln("node [shape=box];");
    foreach (element; dependencies.elements)
        writeln('"', element, '"');
    foreach (dependency; dependencies)
        writeln('"', dependency.client, '"', " -> ", '"', dependency.supplier, '"');
    writeln("}");
}

string packages(string fullyQualifiedName)
{
    string[] names = fullyQualifiedName.split('.');

    names.popBack;
    return names.join('.');
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

void add(Range, Element)(ref Range range, Element element)
{
    if (!range.canFind(element))
        range ~= element;
}
