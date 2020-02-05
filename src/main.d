//          Copyright Mario Kröplin 2018.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          https://www.boost.org/LICENSE_1_0.txt)

import core.stdc.stdlib;
import deps;
import graph;
import settings : readSettings = read;
import std.algorithm;
import std.array;
import std.regex;
import std.stdio;
import std.typecons;
import uml;
import util : crossedPackageBoundaries, fqnStartsWith, packages;

void main(string[] args)
{
    const settings = readSettings(args);

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
            import std.range : repeat;
            import uml : read;

            bool errored = false;
            Dependency[] targetDependencies = null;

            foreach (targetFile; targetFiles)
                targetDependencies ~= read(File(targetFile).byLine);

            if (!transitive)
                targetDependencies.transitiveClosure;

            // Packages in this list, when used in a dependency, implicitly include subpackages.
            // Set to false if there's a dependency from a package inside <package> to a package outside <package>.
            const transitivePackage =
                targetDependencies.map!(dependency => crossedPackageBoundaries(dependency.client, dependency.supplier))
                .joiner.assocArray(false.repeat); // crossed package boundaries are not transitive packages

            bool canDepend(const string client, const string supplier)
            {
                bool dependencyMatches(const Dependency dependency)
                {
                    // A -> A.X never allows subpackages of A!
                    // because A -> A.X does not break A's transitivity, there would otherwise
                    // be no way to refer to "submodules of A".
                    const dependencyIsInternal = dependency.supplier.fqnStartsWith(dependency.client);

                    bool moduleMatches(const string first, const string second)
                    {
                        const packageIsTransitive = transitivePackage.get(first, true);

                        if (packageIsTransitive && !dependencyIsInternal)
                        {
                            return first.fqnStartsWith(second);
                        }
                        return first == second;
                    }
                    return moduleMatches(client, dependency.client) && moduleMatches(supplier, dependency.supplier);
                }

                return targetDependencies.canFind!dependencyMatches;
            }

            foreach (dependency; actualDependencies)
            {
                with (dependency)
                {
                    if (!detail)
                    {
                        dependency = Dependency(client.packages, supplier.packages);
                        if (client.empty ||
                            supplier.empty ||
                            client == supplier)
                            continue;
                    }
                    if (!canDepend(client, supplier))
                    {
                        stderr.writefln("error: unintended dependency %s -> %s", client, supplier);
                        errored = true;
                    }
                }
            }
            if (errored)
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
