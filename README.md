
## yamkeys

**yamkeys** is a simple runtime configuration file format, built with vibe.d in mind.

### Tutorial

To start, write a configuration file in `config.yaml` or `config/config.yaml`.

The first line should specify what the default configuration is:

	default: dev

Next, you specify various configurations (e.g. `dev`, `test`, `prod`, etc).
Each configuration has a mapping of *key*s which correspond to parts of the program
that need configuration:


	dev:
	 http_server:
	     port: 3000
	     accessLogFile: dev.log
	 access_key: admin
	     
	prod:
	 http_server:
	     port: 80
	     accessLogFile: logs/prod.log


For settings which don't belong in the repository (e.g. passwords), use `local.yaml`:


	# don't commit me, I belong only on production server

	# which config in config.yaml to use
	config: prod

	prod:
	    access_key: pzkdgC2YlDXu2zIhTPwnh9sCy20HnX87YsuMcldM



To incorporate it into your program, use the `configure` template:


	import yamkeys;

	mixin(configure!(HTTPServerSettings, "http_server"));
	mixin(configure!(string, "access_key"));


To read it, use the key as a function of `config`:


	listenHTTP(config.http_server, router);

	bool verify(string accessKey) {
		return accessKey == config.access_key;
	}


Now, building your app, you can run:


	$ myapp [--config=[name]]


It will read all the configurations at the start of the application (you must restart
it to change settings).

You can specify the `config` at the command line, or as the `config` in `local.yaml`,
otherwise the `default` will be used.

#### Notes
  * for `vibe.d` users: if you use an argument vibe.d doesn't recognize, usage will
    be printed, but it will still work.
  * both `.yaml` and `.yml` are recognized.
  * this is an alpha version, contact me if you have any questions.
  
## Building
Just use the `dub` repository `yamkeys`, or include `source/yamkeys.d` wherever.

[dyaml](https://github.com/kiith-sa/D-YAML) is a dependency.

## Full public API
There isn't much more than what's in the tutorial, but it's available at 
`docs/yamkeys.html`.


