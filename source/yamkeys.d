// yamkeys - a runtime configuration management utility.
// Copyright © 2013 Nathan M. Swan
// Available under the MIT Expat License, see LICENSE file.
// Written in the D Programming Language

/++
 + Simple configuration management based on YAML.
 +
 + Authors: Nathan M. Swan, nathanmswan@gmail.com
 + License: MIT (Expat) License
 + Copyright: Copyright © 2013 Nathan M. Swan
 +/
 
module yamkeys;

private:
import std.algorithm;
import std.array;
import std.file;
import std.getopt;
import std.string;
import std.traits;
import std.path;

import dyaml.all;

public:
/// The global configuration variable.
__gshared Configuration config;

shared static this() {
    config = new Configuration();
}

/// Creates code which declares a variable of type T which is loaded with
/// configurations by calling config.load,
/// as well as a function of the given name which, given config, returns the
/// variable.
string configure(T, string name = defaultName!T)() {
    import std.array;
    import std.string;

    string code = 
        `private __gshared TYPE _vcyam_NAME; `~
        `shared static this() { config.load(_vcyam_NAME, "NAME"); } `~
        `public @property TYPE NAME(yamkeys.Configuration c) { `~
            `return _vcyam_NAME; }`;

    code = replace(code, `TYPE`, T.stringof);
    code = replace(code, `NAME`, name);
    
    return code;
}

/// The default key name for a type: its lowercased local name.
template defaultName(T) {
    enum defaultName = splitter(T.stringof.toLower(), '.').back;
}

/// Holds the state for the configuration files.
final class Configuration {
  public:
    /// Attempts to place the YAML data at the key label into obj.
    /// This is usually already done by the configure template.
    void load(T)(ref T obj, string label = defaultName!T) {
        static if (__traits(compiles, new T()) && is(T == class)) {
            if (obj is null) {
                obj = new T();
            }
        }

        foreach(Node cfg; evaluate(label)) {
            load!T(obj, cfg);
        }
    }

  private:
    bool configFolderExists;
    Node yConfig;
    Node yLocal;

    Node emptyYamlMap;

    string scName = null; Node* scInL=null, scInC=null;
    string dcName = null; Node* dcInL=null, dcInC=null;


    this() {
        import core.runtime;
        import std.stdio;

        string[string] mp;
        emptyYamlMap = Node(mp);

        bool configFolderExists = "config".exists && "config".isDir;
        yConfig = getFromYamlFile("config", configFolderExists, "default");
        yLocal = getFromYamlFile("local", configFolderExists);

        string[] args = Runtime.args().dup;
        getopt(args, "config", &scName);
        if (scName is null) {
            if (auto cp = "config" in yLocal) {
                scName = cp.as!string;
            } 
        }

        if (auto cp = "default" in yLocal) {
            dcName = cp.as!string;
        } else if (auto cp = "default" in yConfig) {
            dcName = cp.as!string;
        } else {
            if (scName is null) {
                throw new YamkeysException("No default configuration is specified.");
            }
        }

        if (yLocal == emptyYamlMap && scName !is null) {
            yLocal["config"] = scName;
            Dumper(configFolderExists ? "config/local.yml" : "local.yml")
                .dump(yLocal);
        }

        if (scName !is null) {
            scInL = scName in yLocal;
            scInC = scName in yConfig;
        }
        dcInL = dcName in yLocal;
        dcInC = dcName in yConfig;
    }

    Node getFromYamlFile(string name, bool configFolderExists, string folderName=null) {
        auto namesToCheck = [name ~ ".yml", name ~ ".yaml"];
        if (configFolderExists) {
            alias ds = dirSeparator;
            if (folderName is null) folderName = name;
            namesToCheck ~= ["config" ~ ds ~ folderName ~ ".yml",
                             "config" ~ ds ~ folderName ~ ".yaml"];
        }
        foreach(fname; namesToCheck) {
            if (fname.exists) {
                return Loader(fname).load();
            }
        }
        return emptyYamlMap;
    }

    Node[] evaluate(string key) {
        Node[] configs;

        if (dcInC)
            if (auto val = key in *dcInC)
                configs ~= *val;
        if (dcInL)
            if (auto val = key in *dcInL)
                configs ~= *val;
        if (scInC)
            if (auto val = key in *scInC)
                configs ~= *val;
        if (scInL)
            if (auto val = key in *scInL)
                configs ~= *val;
        
        return configs;
    }
	
	void load(T)(ref T obj, Node node) 
    {
		static if (isBasicType!T && !is(T == enum) || isSomeString!T) {
			obj = node.get!T;
		}
		else static if (isDynamicArray!T) {
            obj = [];
            obj.reserve(node.length);
			foreach(ref Node e; node) {
                typeof(obj[0]) obje;
				load!(typeof(obje))(obje, e);
                obj ~= obje;
			}
		}
		else static if (isAssociativeArray!T) {
            T map;
            obj = map;
			foreach(ref Node k, ref Node v; node) {
                KeyType!T objk;
				load!(KeyType!T)(objk, k);
				
                ValueType!T objv;
				load!(ValueType!T)(objv, v);
				
				obj[objk] = objv;
			}
		}
		else static if (isAggregateType!T) {
            static if (__traits(compiles, new T()) && is(T == class)) {
                if (obj is null) {
                    obj = new T();
                }
            }

			alias FT = FieldTypeTuple!T;
			
            enum src = ({
                string res;
                foreach(mb; [__traits(allMembers, T)]) {
                    res ~= `if (auto mbPtr = "`~mb~`" in node) {`;
                    string loadStmt =
                        `load!(typeof(obj.`~mb~`))(obj.`~mb~`, node["`~mb~`"]);`;
                    res ~= "
static if (__traits(compiles, obj."~mb~"=typeof(obj."~mb~").init)) { 
mixin(`"~loadStmt~"`); }
}";
                }
                return res;
            })();

            mixin(src);
		}
	}
}

class YamkeysException : Exception {
	this(string msg, string file=__FILE__, int line=__LINE__, Throwable t=null) {
		super(msg, file, line, t);
	}
}
