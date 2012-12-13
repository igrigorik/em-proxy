0.1.8 (December 12, 2012)
--------------------

* [#28](https://github.com/igrigorik/em-proxy/pull/28) - Fix: bin script - close connections only on relay response - [@bo-chen](https://github.com/bo-chen).
* [#31](https://github.com/igrigorik/em-proxy/pull/31) - Added support for proxying to a unix domain socket - [@dblock](https://github.com/dblock).
* [#34](https://github.com/igrigorik/em-proxy/pull/34) - Fix: duplex TCP traffic to two backends spec race condition - [@dblock](https://github.com/dblock).

0.1.7 (October 13, 2012)
------------------------

* Allow force-close on upstream connections - [@igrigoric](https://github.com/igrigorik).
* [#25](https://github.com/igrigorik/em-proxy/pull/25): Added `bind` support - [@kostya](https://github.com/kostya).
* [#27](https://github.com/igrigorik/em-proxy/pull/27): Alias `sock` for `get_sockname` - [@kostya](https://github.com/kostya).

0.1.6 (December 27, 2011)
-------------------------

* Added HTTP proxy example - [@igrigoric](https://github.com/igrigorik).
* [#11](https://github.com/igrigorik/em-proxy/issues/11) - Fix: closing the client connection immediately after servers connection are closed - [@igrigoric](https://github.com/igrigorik).
* [#13](https://github.com/igrigorik/em-proxy/pull/13): Removed duplicate `unbind_backend` - [@outself](https://github.com/outself).
* [#20](https://github.com/igrigorik/em-proxy/issues/20): Fix: don't buffer data in back-end - [@igrigoric](https://github.com/igrigorik).

0.1.5 (January 16, 2011)
------------------------

* Added `em-proxy` bin script for easy proxy debugging & relay use cases - [@igrigoric](https://github.com/igrigorik).
* Replaced Jeweler with Bundler - [@igrigoric](https://github.com/igrigorik).
* Added example of a simple load-balancing proxy - [@karmi](https://github.com/karmi).

0.1.4 (October 3, 2010)
-----------------------

* Fix: use `instance_eval` to allow unbind - [@igrigoric](https://github.com/igrigorik).

0.1.3 (May 29, 2010)
--------------------

* Fix: `on_connect` should fire after connection is established to each backend - [@igrigoric](https://github.com/igrigorik).
* Fix: `get_peername` can return nil - [@mdkent](https://github.com/mdkent).

0.1.2 (March 26, 2010)
----------------------

* Fix: wait until finishing writing on the frontend - [@eudoxa](https://github.com/eudoxa).
* Removed `:done` callback in `on_finish` - [@igrigoric](https://github.com/igrigorik).
* Ruby 1.9 compatibility - [@dsander](https://github.com/dsander).
* Use EM's `proxy_incomming_to` to do low-level data relaying - [@dsander](https://github.com/dsander).
* Use `Proc#call` instead of `Object#instance_exec` - [@dsander](https://github.com/dsander).
* Added `on_connect` callback, peer helper method - [@dsander](https://github.com/dsander).
* Added schema-free mysql example - [@igrigoric](https://github.com/igrigorik).
* Added support for async processing within the `on_data` callback - [@igrigoric](https://github.com/igrigorik).

0.1.1 (October 25, 2009)
------------------------

* Initial public release - [@igrigoric](https://github.com/igrigorik).
* Simple port forwarder - [@igrigoric](https://github.com/igrigorik).
* Duplex, interceptor, smtp whitelist, beanstalkd interceptor, smtp spam filter and selective forward examples - [@igrigoric](https://github.com/igrigorik).
* Control debug output - [@imbriaco](https://github.com/imbriaco).
