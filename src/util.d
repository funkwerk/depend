module util;

import std.string;

bool fqnStartsWith(string haystack, string needle)
{
    import std.algorithm : splitter;

    return haystack.splitter(".").startsWith(needle.splitter("."));
}
