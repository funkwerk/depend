module check;

import std.typecons;
version (unittest) import unit_threaded;

alias Dependency = Tuple!(string, "client", string, "supplier");

struct Checker
{
    private Dependency[] explicitDependencies;

    private Dependency[]  implicitDependencies;

    this(const Dependency[] targetDependencies, bool strict)
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

        if (strict)
        {
            this.implicitDependencies = dependencies;
            return;
        }
        this.explicitDependencies = dependencies.partition!implict;
        this.implicitDependencies = dependencies[0 .. $ - this.explicitDependencies.length];
}

    bool allows(Dependency actualDependency) const
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

    with (Checker(dependencies, No.strict))
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
    import std.algorithm : splitter, startsWith;

    return lhs.client.splitter('.').startsWith(rhs.client.splitter('.'))
        && lhs.supplier.splitter('.').startsWith(rhs.supplier.splitter('.'));
}

@("check for implied dependencies")
unittest
{
    Dependency("a", "b").implies(Dependency("a", "b")).shouldBeTrue;
    Dependency("a.x", "b.y").implies(Dependency("a", "b")).shouldBeTrue;

    Dependency("a.x", "b").implies(Dependency("a", "b.y")).shouldBeFalse;
    Dependency("aa", "bb").implies(Dependency("a", "b")).shouldBeFalse;
}
