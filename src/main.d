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
        void process(File file)
        {
            auto pattern = regex(filter);
            Dependency[] actualDependencies = moduleDependencies(file, pattern);

            actualDependencies = actualDependencies.sort.uniq.array;
            if (!targets.empty)
            {
                uint count = 0;
                Dependency[] targetDependencies = null;

                foreach (target; targets)
                    targetDependencies ~= plantUMLDependencies(File(target));

                if (simplify)
                    targetDependencies.transitiveClosure;
                foreach (dependency; actualDependencies)
                {
                    const client = dependency.client;
                    const supplier = dependency.supplier;

                    if (level == Level.modules)
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
            if (dot || uml)
            {
                Dependency[] dependencies_ = null;

                if (level == Level.modules)
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
                if (simplify)
                    dependencies_.transitiveReduction;
                if (dot)
                {
                    import graph : write;
                    import std.stdio : stdout;

                    stdout.lockingTextWriter.write(dependencies_);
                }
                if (uml)
                {
                    import uml : write;
                    import std.stdio : stdout;

                    // TODO write to file instead?
                    stdout.lockingTextWriter.write(dependencies_);
                }
            }
        }

        if (dependencies.empty)
        {
            import std.process : pipeProcess, Redirect, wait;

            const args_ = [compiler, "-deps", "-o-"] ~ unrecognizedArgs;
            auto pipes = pipeProcess(args_, Redirect.stdout);

            scope (exit)
            {
                auto status = wait(pipes.pid);

                exit((status == 0) ? EXIT_SUCCESS : EXIT_FAILURE);
            }

            process(pipes.stdout);
        }
        else
        {
            process(File(dependencies));
        }
    }
}

struct Settings
{
    string dependencies;
    string compiler = "dmd";
    string filter;
    Level level = Level.packages;
    auto simplify = Yes.simplify;
    bool dot = false;
    bool uml = false;
    string[] targets;
    string[] unrecognizedArgs;
}

enum Level {
    modules,
    packages,
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
                "deps", "Read module dependencies from file", &dependencies,
                "compiler", "Specify the compiler to use (default: dmd)", &compiler,
                "filter|f", "Filter source files  matching the regular expression", &filter,
                "level", "Inspect dependencies between modules or packages (default: packages)", &level,
                "simplify", "Remove transitive dependencies (default: yes)", &simplify,
                "dot", "Write dependency graph in the DOT language", &dot,
                "uml", "Write package diagram in the PlantUML language", &uml,
                "target|t", "Check against the PlantUML target dependencies", &targets,
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

            writefln("Usage: %s [options] FILE", args.front.baseName);
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
    const settings = read(["depend", "--deps", "dependencies", "--uml"]);

    with (settings)
    {
        assert(dependencies == "dependencies");
        assert(uml);
    }
}

/// reads settings with unrecognized arguments
unittest
{
    const settings = read(["depend", "main.d", "--target", "model.uml"]);

    with (settings)
    {
        assert(unrecognizedArgs == ["main.d"]);
        assert(targets == ["model.uml"]);
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
