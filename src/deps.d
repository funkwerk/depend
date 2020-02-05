module deps;

import std.algorithm;
import std.range;
import std.regex;
import std.stdio;
import std.typecons;
version (unittest) import dshould;

alias Dependency = Tuple!(string, "client", string, "supplier");

auto moduleDependencies(alias predicate)(File file)
{
    import std.algorithm : filter, map;

    return reader(file.byLine)
        .filter!predicate
        .map!(dependency => Dependency(dependency.client.name, dependency.supplier.name));
}

auto reader(R)(R input)
{
    return Reader!R(input);
}

struct Reader(R)
if (isInputRange!R)
{
    alias Module = Tuple!(string, "name", string, "path");
    alias Dependency = Tuple!(Module, "client", Module, "supplier");

    private R input;

    public bool empty = false;

    public Dependency front;

    private this(R input)
    {
        this.input = input;
        popFront;
    }

    public void popFront()
    {
        import std.conv : to;
        import std.regex : matchFirst, regex;

        enum pattern = regex(`^(depsImport\s)?`
            ~ `(?P<clientName>[\w.]+)\s\((?P<clientPath>.*)\)`
            ~ `\s:[^:]*:\s`
            ~ `(?P<supplierName>[\w.]+)\s\((?P<supplierPath>.*)\)`);

        while (!this.input.empty)
        {
            auto captures = this.input.front.matchFirst(pattern);

            scope (exit)
                this.input.popFront;

            if (captures)
            {
                with (this.front.client)
                {
                    name = captures["clientName"].to!string;
                    path = captures["clientPath"].to!string;
                }
                with (this.front.supplier)
                {
                    name = captures["supplierName"].to!string;
                    path = captures["supplierPath"].to!string;
                }
                return;
            }
        }
        this.empty = true;
    }
}

@("read module dependencies")
unittest
{
    const line = "depend (src/depend.d) : private : object (/usr/include/dmd/druntime/import/object.di)";
    const client = tuple("depend", "src/depend.d");
    const supplier = tuple("object", "/usr/include/dmd/druntime/import/object.di");

    reader(only(line)).should.equal(only(tuple(client, supplier)));
}

class DependencyChecker
{
    private Dependency[] targetDependencies;

    // Packages in this list, when used in a dependency, implicitly include subpackages.
    // Set to false if there's a dependency from a package inside <package> to a package outside <package>.
    private bool[const string] transitivePackages;

    this(Dependency[] targetDependencies)
    {
        import util : crossedPackageBoundaries;

        this.targetDependencies = targetDependencies;
        this.transitivePackages = targetDependencies.map!(
            dependency => crossedPackageBoundaries(dependency.client, dependency.supplier))
            .joiner.assocArray(false.repeat); // crossed package boundaries are not transitive packages
    }

    bool canDepend(const string client, const string supplier)
    {
        import util : fqnStartsWith;

        bool dependencyMatches(const Dependency dependency)
        {
            // A -> A.X never allows subpackages of A!
            // because A -> A.X does not break A's transitivity, there would otherwise
            // be no way to refer to "submodules of A".
            const dependencyIsInternal = dependency.supplier.fqnStartsWith(dependency.client);

            bool moduleMatches(const string module_, const string dependencyModule)
            {
                const packageIsTransitive = this.transitivePackages.get(dependencyModule, true);

                if (packageIsTransitive && !dependencyIsInternal)
                {
                    return module_.fqnStartsWith(dependencyModule);
                }
                return module_ == dependencyModule;
            }
            return moduleMatches(client, dependency.client) && moduleMatches(supplier, dependency.supplier);
        }

        return this.targetDependencies.canFind!dependencyMatches;
    }
}

@("dependency inside transitive package")
unittest
{
    with (new DependencyChecker([Dependency("X", "Y")]))
    {
        canDepend("X.A", "Y.B").should.be(true);
    }
}

@("dependency inside non-transitive package")
unittest
{
    // X.A -> Y breaks the transitivity of X because it crosses the X boundary
    with (new DependencyChecker([
        Dependency("X", "Y"),
        Dependency("X.Q", "Y")]))
    {
        canDepend("X.A", "Y.B").should.be(false);
    }
}

@("cross-dependency inside package where client is transitive and has interior dependency")
unittest
{
    with (new DependencyChecker([
        Dependency("X", "X.A"),
        Dependency("X", "X.B")]))
    {
        canDepend("X.A", "X.B").should.be(false);
    }
}
