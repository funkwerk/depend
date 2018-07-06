//          Copyright Mario Kröplin 2018.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          https://www.boost.org/LICENSE_1_0.txt)

import core.stdc.stdlib;
import deps;
import graph;
import std.algorithm;
import std.array;
import std.range;
import std.regex;
import std.stdio;
import std.typecons;
import uml;

void main(string[] args)
{
    const settings = read(args);

    with (settings)
    {
        Dependency[] readDependencies(File file)
        {
            if (pattern.empty)
            {
                bool matches(T)(T dependency)
                {
                    with (dependency)
                    {
                        return unrecognizedArgs.canFind(client.path)
                            && unrecognizedArgs.canFind(supplier.path);
                    }
                }

                return moduleDependencies!(dependency => matches(dependency))(file).array;
            }
            else
            {
                bool matches(T)(T dependency)
                {
                    with (dependency)
                    {
                        return client.path.matchFirst(pattern)
                            && supplier.path.matchFirst(pattern);
                    }
                }

                return moduleDependencies!(dependency => matches(dependency))(file).array;
            }
        }

        Dependency[] actualDependencies;

        if (depsFiles.empty)
        {
            import std.process : pipeProcess, Redirect, wait;

            const args_ = [compiler, "-deps", "-o-"] ~ unrecognizedArgs;
            auto pipes = pipeProcess(args_, Redirect.stdout);

            scope (exit)
            {
                auto status = wait(pipes.pid);

                if (status != 0)
                    exit(EXIT_FAILURE);
            }

            actualDependencies = readDependencies(pipes.stdout);
        }
        else
            actualDependencies = depsFiles
                .map!(depsFile => readDependencies(File(depsFile)))
                .join;
        actualDependencies = actualDependencies.sort.uniq.array;
        if (!targetFiles.empty)
        {
            import uml : read;

            uint count = 0;
            Dependency[] targetDependencies = null;

            foreach (targetFile; targetFiles)
                targetDependencies ~= read(File(targetFile).byLine);

            if (!transitive)
                targetDependencies.transitiveClosure;
            foreach (dependency; actualDependencies)
            {
                const client = dependency.client;
                const supplier = dependency.supplier;

                if (detail)
                    dependency = Dependency(client, supplier);
                else
                {
                    dependency = Dependency(client.packages, supplier.packages);
                    if (dependency.client.empty || dependency.supplier.empty || dependency.client == dependency.supplier)
                        continue;
                }
                if (!targetDependencies.canFind(dependency))
                {
                    stderr.writefln("error: unintended dependency %s -> %s", client, supplier);
                    ++count;
                }
            }
            if (count > 0)
                exit(EXIT_FAILURE);
        }
        if (dot || targetFiles.empty)
        {
            Dependency[] dependencies_ = null;

            if (detail)
                dependencies_ = actualDependencies;
            else
            {
                foreach (dependency; actualDependencies)
                {
                    const client = dependency.client.packages;
                    const supplier = dependency.supplier.packages;

                    if (!client.empty && !supplier.empty && client != supplier)
                        dependencies_.add(Dependency(client, supplier));
                }
            }
            if (!transitive)
            {
                auto cyclicDependencies = transitiveReduction(dependencies_);

                if (!cyclicDependencies.empty)
                {
                    stderr.writeln("warning: cyclic dependencies");
                    foreach (dependency; cyclicDependencies.sort)
                        stderr.writefln!"%s -> %s"(dependency.client, dependency.supplier);
                }
            }
            if (dot)
            {
                import graph : write;
                import std.stdio : stdout;

                stdout.lockingTextWriter.write(dependencies_);
            }
            else
            {
                import uml : write;
                import std.stdio : stdout;

                stdout.lockingTextWriter.write(dependencies_);
            }
        }
    }
}

struct Settings
{
    string[] depsFiles = null;
    string compiler = "dmd";
    string pattern = null;
    bool detail = false;
    bool transitive = false;
    bool dot = false;
    string[] targetFiles = null;
    string[] unrecognizedArgs;
}

Settings read(string[] args)
in
{
    assert(!args.empty);
}
do
{
    import std.getopt : config, defaultGetoptPrinter, getopt, GetoptResult;

    Settings settings;

    with (settings)
    {
        GetoptResult result;

        try
        {
            result = getopt(args,
                config.passThrough,
                "deps", "Read module dependencies from file", &depsFiles,
                "compiler|c", "Specify the compiler to use (default: dmd)", &compiler,
                "filter", "Filter source files  matching the regular expression", &pattern,
                "detail", "Inspect dependencies between modules instead of packages", &detail,
                "transitive|t", "Keep transitive dependencies", &transitive,
                "dot", "Write dependency graph in the DOT language", &dot,
                "check", "Check against the PlantUML target dependencies", &targetFiles,
            );
        }
        catch (Exception exception)
        {
            stderr.writeln("error: ", exception.msg);
            exit(EXIT_FAILURE);
        }
        if (result.helpWanted)
        {
            import std.path : baseName;

            writefln("Usage: %s [options] files", args.front.baseName);
            writeln("Process import dependencies as created by dmd with the --deps switch.");
            defaultGetoptPrinter("Options:", result.options);
            exit(EXIT_SUCCESS);
        }
        unrecognizedArgs = args.dropOne;
    }
    return settings;
}

/// reads settings
unittest
{
    const settings = read(["depend", "--deps", "dependencies", "--check", "target"]);

    with (settings)
    {
        assert(depsFiles == ["dependencies"]);
        assert(targetFiles == ["target"]);
    }
}

/// reads settings with unrecognized arguments
unittest
{
    const settings = read(["depend", "main.d", "--detail"]);

    with (settings)
    {
        assert(unrecognizedArgs == ["main.d"]);
        assert(detail);
    }
}

private string packages(string fullyQualifiedName)
{
    import std.range : dropBackOne;

    return fullyQualifiedName.split('.')
        .dropBackOne
        .join('.');
}

unittest
{
    assert(packages("bar.baz.foo") == "bar.baz");
    assert(packages("foo") == null);
}
