// app - the empty program to be run for unittests.
// Copyright © 2013 Nathan M. Swan
// Available under the MIT Expat License, see LICENSE file.
// Written in the D Programming Language

import yamkeys;

version(yamkeys_main) {

    struct Abcd {
        bool flag = true;
        int num = 30;
        string str = "foobarbaz";
        string[] list = ["hobbes", "locke"];
        string[string] map;
    }

    mixin (configure!Abcd);

    void main() {
        import std.stdio;

        Abcd test = config.abcd;
        writeln(test);
    }

}