module check;

import model;
import std.typecons;
version (unittest) import unit_threaded;

struct Checker
{
    private Dependency[] explicitDependencies;

    private Dependency[]  implicitDependencies;

    this(Dependency[] targetDependencies, bool experimental)
    {
        import std.algorithm : partition;

        bool implict(Dependency dependency)
        {
            import std.algorithm : any, filter;

            return targetDependencies
                .filter!(targetDependency => targetDependency != dependency)
                .any!(targetDependency => targetDependency.implies(dependency));
        }

        auto dependencies = targetDependencies.dup;

        if (experimental)
        {
            this.explicitDependencies = dependencies.partition!implict;
            this.implicitDependencies = dependencies[0 .. $ - this.explicitDependencies.length];
            return;
        }
        this.implicitDependencies = dependencies;
}

    bool allows(Dependency actualDependency)
    {
        import std.algorithm : any;

        return this.explicitDependencies.any!(dependency => actualDependency.implies(dependency))
            || this.implicitDependencies.any!(dependency => actualDependency == dependency);
    }
}

@("check for allowed dependencies")
unittest
{
    auto dependencies = [
        Dependency("a", "b"),
        Dependency("a.x", "b.y"),
        Dependency("b", "c"),
        ];

    with (Checker(dependencies, Yes.experimental))
    {
        allows(Dependency("a", "b")).shouldBeTrue;
        allows(Dependency("a.x", "b.y")).shouldBeTrue;
        allows(Dependency("b", "c")).shouldBeTrue;
        allows(Dependency("b.x", "c")).shouldBeTrue;  // implies explicit dependency

        allows(Dependency("a.x", "b")).shouldBeFalse;  // implies implicit dependency
    }
}

bool implies(Dependency lhs, Dependency rhs)
{
    import std.algorithm : startsWith;

    return lhs.client.names.startsWith(rhs.client.names)
        && lhs.supplier.names.startsWith(rhs.supplier.names);
}

@("check for implied dependencies")
unittest
{
    Dependency("a", "b").implies(Dependency("a", "b")).shouldBeTrue;
    Dependency("a.x", "b.y").implies(Dependency("a", "b")).shouldBeTrue;

    Dependency("a.x", "b").implies(Dependency("a", "b.y")).shouldBeFalse;
    Dependency("aa", "bb").implies(Dependency("a", "b")).shouldBeFalse;
}
