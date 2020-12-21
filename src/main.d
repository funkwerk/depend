//          Copyright Mario Kröplin 2020.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          https://www.boost.org/LICENSE_1_0.txt)
module main;

import core.stdc.stdlib;
import deps;
import direct;
import graph;
import model;
import settings : readSettings = read;
import std.algorithm;
import std.array;
import std.exception;
import std.range;
import std.regex;
import std.stdio;
import std.typecons;
import uml;

void main(string[] args)
{
    const settings = readSettings(args);

    with (settings)
    {
        bool matches(T)(T dependency)
        {
            with (dependency)
            {
                if (pattern.empty)
                {
                    return unrecognizedArgs.canFind(client.path)
                        && unrecognizedArgs.canFind(supplier.path);
                }
                else
                {
                    return client.path.matchFirst(pattern)
                        && supplier.path.matchFirst(pattern);
                }
            }
        }

        Dependency[] readDependencies(File file)
        {
            return moduleDependencies!(dependency => matches(dependency))(file).array;
        }

        Dependency[] actualDependencies;

        if (readDirectly)
        {
            import std.string : strip;

            enforce(depsFiles.empty, "Can't combine --deps and --direct");
            enforce(umlFiles.empty, "Can't combine --uml and --direct");

            const sources = unrecognizedArgs.filter!(a => a.endsWith(".d")).array;
            const includes = unrecognizedArgs.filter!(a => a.startsWith("-I")).map!(a => a.drop(2).strip).array;

            actualDependencies = sources
                    .map!(a => extractImports(a, sources, includes))
                    .joiner
                    .filter!(dependency => matches(dependency))
                    .map!(dependency => Dependency(dependency.client.name, dependency.supplier.name))
                    .array;
        }
        else if (depsFiles.empty && umlFiles.empty)
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
        {
            actualDependencies ~= depsFiles
                .map!(depsFile => readDependencies(File(depsFile)))
                .join;
            actualDependencies ~= umlFiles
                .map!(umlFile => read(File(umlFile).byLine))
                .join;
        }
        actualDependencies = actualDependencies.sort.uniq.array;
        if (!targetFiles.empty)
        {
            import check : Checker;
            import uml : read;

            bool success = true;
            Dependency[] targetDependencies = null;

            foreach (targetFile; targetFiles)
                targetDependencies ~= read(File(targetFile).byLine);

            if (!transitive)
                targetDependencies.transitiveClosure;

            auto checker = Checker(targetDependencies, experimental);

            foreach (dependency; actualDependencies)
            {
                auto client = dependency.client;
                auto supplier = dependency.supplier;

                if (detail)
                    dependency = Dependency(client, supplier);
                else
                {
                    dependency = Dependency(client.packages, supplier.packages);
                    if (dependency.client.names.empty || dependency.supplier.names.empty
                        || dependency.client == dependency.supplier)
                        continue;
                }
                if (!checker.allows(dependency))
                {
                    stderr.writefln("error: unintended dependency %s -> %s", client, supplier);
                    success = false;
                }
            }
            if (!success)
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
